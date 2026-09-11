import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/pos_database.dart';
import '../../domain/models/stock_in.dart';
import '../../domain/repositories/stock_repository.dart';

class StockRepositoryImpl implements StockRepository {
  final PosDatabase _db;
  final _uuid = const Uuid();
  bool _hasBackfilled = false;

  StockRepositoryImpl(this._db);

  Future<void> _backfillHistoricalTransactions(DatabaseExecutor db) async {
    try {
      final List<Map<String, dynamic>> txRows = await db.rawQuery('''
        SELECT t.id, t.nomor_transaksi, t.customer_name, t.created_at 
        FROM transactions t
        WHERE t.status = 'completed'
      ''');

      for (final tx in txRows) {
        final txNo = tx['nomor_transaksi'] as String;
        final txDate = tx['created_at'] as String;
        final todayStr = txDate.split('T')[0];
        final custName = tx['customer_name'] as String?;
        final note = 'Penjualan #$txNo${custName != null && custName.isNotEmpty ? ' ($custName)' : ''}';

        // Check if this transaction already has stock mutation entries
        final existing = await db.rawQuery('''
          SELECT id FROM stock_in 
          WHERE catatan LIKE ?
          LIMIT 1
        ''', ['%$txNo%']);

        if (existing.isNotEmpty) continue;

        final items = await db.query(
          'transaction_items',
          where: 'transaction_id = ?',
          whereArgs: [tx['id']],
        );

        for (final item in items) {
          final produkId = item['produk_id'] as String;
          final qty = (item['qty'] as num).toInt();
          if (produkId.startsWith('manual_')) continue;

          final prodRows = await db.query(
            'products',
            columns: ['is_package', 'stok'],
            where: 'id = ?',
            whereArgs: [produkId],
            limit: 1,
          );
          if (prodRows.isEmpty) continue;
          final isPackage = (prodRows.first['is_package'] as int? ?? 0) == 1;

          if (isPackage) {
            final compRows = await db.rawQuery('''
              SELECT pi.product_id, pi.qty as comp_qty, p.stok as comp_stok
              FROM package_items pi
              JOIN products p ON pi.product_id = p.id
              WHERE pi.package_id = ?
            ''', [produkId]);
            for (final comp in compRows) {
              final compStock = comp['comp_stok'] as int? ?? 0;
              if (compStock == -1) continue;
              final compQty = (comp['comp_qty'] as num).toInt() * qty;
              await db.insert('stock_in', {
                'id': _uuid.v4(),
                'produk_id': comp['product_id'],
                'type': 'out',
                'qty': compQty,
                'tanggal': todayStr,
                'catatan': note,
                'created_at': txDate,
              });
            }
          } else {
            final currentStock = prodRows.first['stok'] as int? ?? 0;
            if (currentStock == -1) continue;
            await db.insert('stock_in', {
              'id': _uuid.v4(),
              'produk_id': produkId,
              'type': 'out',
              'qty': qty,
              'tanggal': todayStr,
              'catatan': note,
              'created_at': txDate,
            });
          }
        }
      }
    } catch (_) {
      // Gracefully ignore any backfill exceptions
    }
  }

  @override
  Future<List<StockIn>> getAllStockIn() async {
    final db = await _db.database;
    if (!_hasBackfilled) {
      _hasBackfilled = true;
      await _backfillHistoricalTransactions(db);
    }
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT s.*, p.nama as produk_nama 
      FROM stock_in s
      LEFT JOIN products p ON s.produk_id = p.id
      ORDER BY s.tanggal DESC, s.created_at DESC
    ''');
    return List.generate(maps.length, (i) => StockIn.fromMap(maps[i]));
  }

  @override
  Future<void> insertStockIn(StockIn stockIn) async {
    final db = await _db.database;
    
    await db.transaction((txn) async {
      // 1. Insert stock_in record
      await txn.insert(
        'stock_in',
        stockIn.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );

      // 2. Query current product stock
      final List<Map<String, dynamic>> products = await txn.query(
        'products',
        columns: ['stok'],
        where: 'id = ?',
        whereArgs: [stockIn.produkId],
        limit: 1,
      );

      if (products.isEmpty) {
        throw Exception('Produk dengan ID ${stockIn.produkId} tidak ditemukan');
      }

      final currentStock = products.first['stok'] as int;
      if (currentStock != -1) {
        final changeQty = stockIn.isOut ? -stockIn.qty.abs() : stockIn.qty.abs();
        final newStock = currentStock + changeQty;
        if (newStock < 0) {
          throw Exception('Gagal menyimpan transaksi stok: Stok produk tidak mencukupi. Sisa stok saat ini: $currentStock');
        }

        // 3. Update product stock
        await txn.update(
          'products',
          {
            'stok': newStock,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [stockIn.produkId],
        );
      }
    });
  }
}
