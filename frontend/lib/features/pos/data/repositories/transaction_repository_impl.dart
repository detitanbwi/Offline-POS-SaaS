import 'package:intl/intl.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../../core/database/pos_database.dart';
import '../../domain/models/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final PosDatabase _db;

  TransactionRepositoryImpl(this._db);

  @override
  Future<List<TransactionHeader>> getAllTransactions() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => TransactionHeader.fromMap(maps[i]));
  }

  @override
  Future<List<TransactionItem>> getTransactionItems(String transactionId) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transaction_items',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
    return List.generate(maps.length, (i) => TransactionItem.fromMap(maps[i]));
  }

  @override
  Future<void> saveTransaction(TransactionHeader header, List<TransactionItem> items) async {
    final db = await _db.database;

    await db.transaction((txn) async {
      // 1. Insert header
      await txn.insert(
        'transactions',
        header.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );

      // 2. Loop through items
      for (var item in items) {
        // Insert transaction item details
        await txn.insert(
          'transaction_items',
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.fail,
        );

        // 3. Deduct product stock
        final List<Map<String, dynamic>> productResult = await txn.query(
          'products',
          columns: ['stok', 'nama'],
          where: 'id = ?',
          whereArgs: [item.produkId],
          limit: 1,
        );

        if (productResult.isEmpty) {
          throw Exception('Produk "${item.produkNama}" tidak ditemukan.');
        }

        final currentStock = productResult.first['stok'] as int;
        final productName = productResult.first['nama'] as String;
        final newStock = currentStock - item.qty;

        if (newStock < 0) {
          throw Exception('Gagal menyimpan transaksi: Stok untuk produk "$productName" tidak mencukupi.');
        }

        await txn.update(
          'products',
          {
            'stok': newStock,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [item.produkId],
        );
      }
    });
  }

  @override
  Future<String> generateNextOrderNumber() async {
    final db = await _db.database;
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(now);
    final searchPattern = '${DateFormat('yyyy-MM-dd').format(now)}%';

    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM transactions WHERE created_at LIKE ?',
      [searchPattern],
    );

    final count = (result.first['count'] as int) + 1;
    final orderNumSuffix = count.toString().padLeft(4, '0');
    return 'TRX-$dateStr-$orderNumSuffix';
  }

  @override
  Future<Map<String, dynamic>> getDailySalesReport(String dateStr) async {
    final db = await _db.database;
    final searchPattern = '$dateStr%';

    final List<Map<String, dynamic>> summaryResult = await db.rawQuery(
      '''
      SELECT 
        COUNT(*) as total_transactions, 
        COALESCE(SUM(grand_total), 0) as total_sales, 
        COALESCE(SUM(tax_amount), 0) as total_tax 
      FROM transactions 
      WHERE created_at LIKE ?
      ''',
      [searchPattern],
    );

    final totalTransactions = summaryResult.first['total_transactions'] as int;
    final totalSales = (summaryResult.first['total_sales'] as num).toDouble();
    final totalTax = (summaryResult.first['total_tax'] as num).toDouble();

    final List<Map<String, dynamic>> paymentResult = await db.rawQuery(
      '''
      SELECT payment_method_nama, COALESCE(SUM(grand_total), 0) as total 
      FROM transactions 
      WHERE created_at LIKE ? 
      GROUP BY payment_method_nama
      ''',
      [searchPattern],
    );

    final Map<String, double> paymentBreakdown = {};
    for (var row in paymentResult) {
      final method = row['payment_method_nama'] as String;
      final total = (row['total'] as num).toDouble();
      paymentBreakdown[method] = total;
    }

    final List<Map<String, dynamic>> productResult = await db.rawQuery(
      '''
      SELECT produk_nama as nama, SUM(qty) as qty, SUM(subtotal) as total 
      FROM transaction_items 
      WHERE transaction_id IN (SELECT id FROM transactions WHERE created_at LIKE ?) 
      GROUP BY produk_id 
      ORDER BY qty DESC 
      LIMIT 5
      ''',
      [searchPattern],
    );

    final List<Map<String, dynamic>> topProducts = productResult.map((row) {
      return {
        'nama': row['nama'] as String,
        'qty': row['qty'] as int,
        'total': (row['total'] as num).toDouble(),
      };
    }).toList();

    return {
      'date': dateStr,
      'total_sales': totalSales,
      'total_transactions': totalTransactions,
      'total_tax': totalTax,
      'payment_breakdown': paymentBreakdown,
      'top_products': topProducts,
    };
  }
}
