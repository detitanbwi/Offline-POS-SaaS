import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/pos_database.dart';
import '../../domain/models/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final PosDatabase _db;
  final _uuid = const Uuid();

  TransactionRepositoryImpl(this._db);

  @override
  Future<List<TransactionHeader>> getAllTransactions({String? cashierId}) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: cashierId != null ? 'cashier_id = ?' : null,
      whereArgs: cashierId != null ? [cashierId] : null,
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

      // Check if stock for items was already deducted when dispatched to kitchen in draft order
      bool itemsAlreadyDeductedInDraft = false;
      final effectiveOrderId = header.masterOrderId;
      if (effectiveOrderId != null && effectiveOrderId.isNotEmpty) {
        final printedItems = await txn.query(
          'order_items',
          where: 'order_id = ? AND status_cetak = 1',
          whereArgs: [effectiveOrderId],
          limit: 1,
        );
        if (printedItems.isNotEmpty) {
          itemsAlreadyDeductedInDraft = true;
        }
      } else if (header.nomorTransaksi.isNotEmpty) {
        final existingOrders = await txn.query(
          'orders',
          columns: ['id'],
          where: 'nomor_order = ?',
          whereArgs: [header.nomorTransaksi],
          limit: 1,
        );
        if (existingOrders.isNotEmpty) {
          final orderId = existingOrders.first['id'] as String;
          final printedItems = await txn.query(
            'order_items',
            where: 'order_id = ? AND status_cetak = 1',
            whereArgs: [orderId],
            limit: 1,
          );
          if (printedItems.isNotEmpty) {
            itemsAlreadyDeductedInDraft = true;
          }
        }
      }

      // 2. Loop through items
      for (var item in items) {
        // Ensure manual product foreign key is satisfied
        await _ensureManualProductExists(txn, item.produkId, item.produkNama, item.produkHarga);

        // Insert transaction item details
        await txn.insert(
          'transaction_items',
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.fail,
        );

        // 3. Deduct product stock (supports MultiStock for Package Bundles, skips non-stock manual items and already deducted draft items)
        if (itemsAlreadyDeductedInDraft || item.produkId.startsWith('manual_')) {
          // Skip if stock was already deducted upon kitchen dispatch or is custom manual non-stock
          continue;
        }

        final List<Map<String, dynamic>> productResult = await txn.query(
          'products',
          columns: ['stok', 'nama', 'is_package'],
          where: 'id = ?',
          whereArgs: [item.produkId],
          limit: 1,
        );

        if (productResult.isEmpty) {
          // Gracefully skip stock deduction if product is not in database
          continue;
        }

        final isPackage = (productResult.first['is_package'] as int? ?? 0) == 1;
        final now = DateTime.now();
        final nowStr = now.toIso8601String();
        final todayStr = nowStr.split('T')[0];
        final saleNote = 'Penjualan #${header.nomorTransaksi}${header.customerName != null && header.customerName!.isNotEmpty ? ' (${header.customerName})' : ''}';

        if (isPackage) {
          // Fetch package components and deduct stock from each physical component
          final List<Map<String, dynamic>> compRows = await txn.rawQuery('''
            SELECT pi.qty as comp_qty, p.id as comp_id, p.nama as comp_nama, p.stok as comp_stok
            FROM package_items pi
            JOIN products p ON pi.product_id = p.id
            WHERE pi.package_id = ?
          ''', [item.produkId]);

          for (var comp in compRows) {
            final compStock = comp['comp_stok'] as int;
            if (compStock != -1) {
              final compQty = comp['comp_qty'] as int;
              final totalDeduct = compQty * item.qty;
              final newCompStock = compStock - totalDeduct;

              if (newCompStock < 0) {
                throw Exception(
                  'Gagal menyimpan transaksi: Stok komponen "${comp['comp_nama']}" untuk paket "${item.produkNama}" tidak mencukupi (Sisa: $compStock, Dibutuhkan: $totalDeduct).',
                );
              }

              await txn.update(
                'products',
                {
                  'stok': newCompStock,
                  'updated_at': nowStr,
                },
                where: 'id = ?',
                whereArgs: [comp['comp_id']],
              );

              // Insert into stock_in (Mutasi Stok Keluar)
              await txn.insert('stock_in', {
                'id': _uuid.v4(),
                'produk_id': comp['comp_id'],
                'type': 'out',
                'qty': totalDeduct,
                'tanggal': todayStr,
                'catatan': saleNote,
                'created_at': nowStr,
              });
            }
          }
        } else {
          // Standard single product stock deduction
          final currentStock = productResult.first['stok'] as int;
          if (currentStock != -1) {
            final productName = productResult.first['nama'] as String;
            final newStock = currentStock - item.qty;

            if (newStock < 0) {
              throw Exception('Gagal menyimpan transaksi: Stok untuk produk "$productName" tidak mencukupi.');
            }

            await txn.update(
              'products',
              {
                'stok': newStock,
                'updated_at': nowStr,
              },
              where: 'id = ?',
              whereArgs: [item.produkId],
            );

            // Insert into stock_in (Mutasi Stok Keluar)
            await txn.insert('stock_in', {
              'id': _uuid.v4(),
              'produk_id': item.produkId,
              'type': 'out',
              'qty': item.qty,
              'tanggal': todayStr,
              'catatan': saleNote,
              'created_at': nowStr,
            });
          }
        }
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
  Future<Map<String, dynamic>> getDailySalesReport(String dateStr, {String? cashierId}) async {
    final db = await _db.database;
    final searchPattern = '$dateStr%';

    // Exclude voided transactions from revenue, tax, and sales calculations
    String whereClause = "(status IS NULL OR status != 'voided') AND created_at LIKE ?";
    List<Object?> whereArgs = [searchPattern];

    if (cashierId != null) {
      whereClause += ' AND cashier_id = ?';
      whereArgs.add(cashierId);
    }

    final List<Map<String, dynamic>> summaryResult = await db.rawQuery(
      '''
      SELECT 
        COUNT(*) as total_transactions, 
        COALESCE(SUM(grand_total), 0) as total_sales, 
        COALESCE(SUM(subtotal), 0) as total_subtotal, 
        COALESCE(SUM(service_charge_amount), 0) as total_service_charge, 
        COALESCE(SUM(tax_amount), 0) as total_tax 
      FROM transactions 
      WHERE $whereClause
      ''',
      whereArgs,
    );

    final totalTransactions = summaryResult.first['total_transactions'] as int;
    final totalSales = (summaryResult.first['total_sales'] as num).toDouble();
    final totalSubtotal = (summaryResult.first['total_subtotal'] as num).toDouble();
    final totalServiceCharge = (summaryResult.first['total_service_charge'] as num).toDouble();
    final totalTax = (summaryResult.first['total_tax'] as num).toDouble();

    // Calculate voided transactions count and amount separately
    String voidWhereClause = "status = 'voided' AND created_at LIKE ?";
    List<Object?> voidWhereArgs = [searchPattern];
    if (cashierId != null) {
      voidWhereClause += ' AND cashier_id = ?';
      voidWhereArgs.add(cashierId);
    }

    final List<Map<String, dynamic>> voidResult = await db.rawQuery(
      '''
      SELECT 
        COUNT(*) as total_void_count, 
        COALESCE(SUM(grand_total), 0) as total_void_amount 
      FROM transactions 
      WHERE $voidWhereClause
      ''',
      voidWhereArgs,
    );

    final totalVoidCount = voidResult.first['total_void_count'] as int;
    final totalVoidAmount = (voidResult.first['total_void_amount'] as num).toDouble();

    final List<Map<String, dynamic>> paymentResult = await db.rawQuery(
      '''
      SELECT payment_method_nama, COALESCE(SUM(grand_total), 0) as total 
      FROM transactions 
      WHERE $whereClause 
      GROUP BY payment_method_nama
      ''',
      whereArgs,
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
      WHERE transaction_id IN (SELECT id FROM transactions WHERE $whereClause) 
      GROUP BY produk_id 
      ORDER BY qty DESC 
      LIMIT 5
      ''',
      whereArgs,
    );

    final List<Map<String, dynamic>> topProducts = productResult.map((row) {
      return {
        'nama': row['nama'] as String,
        'qty': row['qty'] as int,
        'total': (row['total'] as num).toDouble(),
      };
    }).toList();

    final List<Map<String, dynamic>> modifierItemsResult = await db.rawQuery(
      '''
      SELECT qty, modifier_details 
      FROM transaction_items 
      WHERE transaction_id IN (SELECT id FROM transactions WHERE $whereClause) 
        AND modifier_details IS NOT NULL 
        AND modifier_details != '' 
        AND modifier_details != '[]'
      ''',
      whereArgs,
    );

    final Map<String, Map<String, dynamic>> modifierAggMap = {};
    for (var row in modifierItemsResult) {
      final itemQty = (row['qty'] as num?)?.toInt() ?? 1;
      final rawModJson = row['modifier_details'] as String?;
      if (rawModJson == null || rawModJson.isEmpty) continue;
      try {
        final List<dynamic> list = jsonDecode(rawModJson);
        for (var item in list) {
          if (item is Map<String, dynamic>) {
            final groupName = item['groupName'] as String? ?? 'Varian';
            final optionName = item['optionName'] as String? ?? '';
            final harga = (item['harga'] as num?)?.toDouble() ?? 0.0;
            final key = '$groupName: $optionName';
            if (!modifierAggMap.containsKey(key)) {
              modifierAggMap[key] = {
                'nama': key,
                'group': groupName,
                'option': optionName,
                'qty': 0,
                'total': 0.0,
              };
            }
            modifierAggMap[key]!['qty'] = (modifierAggMap[key]!['qty'] as int) + itemQty;
            modifierAggMap[key]!['total'] = (modifierAggMap[key]!['total'] as double) + (harga * itemQty);
          }
        }
      } catch (e) {
        // ignore malformed json
      }
    }

    final topModifiers = modifierAggMap.values.toList()
      ..sort((a, b) => (b['qty'] as int).compareTo(a['qty'] as int));

    return {
      'date': dateStr,
      'total_sales': totalSales,
      'total_transactions': totalTransactions,
      'total_subtotal': totalSubtotal,
      'total_service_charge': totalServiceCharge,
      'total_tax': totalTax,
      'total_void_count': totalVoidCount,
      'total_void_amount': totalVoidAmount,
      'payment_breakdown': paymentBreakdown,
      'top_products': topProducts,
      'top_modifiers': topModifiers,
    };
  }

  @override
  Future<void> voidTransaction(String transactionId) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final List<Map<String, dynamic>> itemsResult = await txn.query(
        'transaction_items',
        where: 'transaction_id = ?',
        whereArgs: [transactionId],
      );

      for (var row in itemsResult) {
        final productId = row['produk_id'] as String;
        final qty = row['qty'] as int;

        final List<Map<String, dynamic>> productResult = await txn.query(
          'products',
          columns: ['stok', 'is_package'],
          where: 'id = ?',
          whereArgs: [productId],
          limit: 1,
        );
        if (productResult.isNotEmpty) {
          final isPackage = (productResult.first['is_package'] as int? ?? 0) == 1;
          if (isPackage) {
            final List<Map<String, dynamic>> compRows = await txn.rawQuery('''
              SELECT pi.qty as comp_qty, p.id as comp_id, p.stok as comp_stok
              FROM package_items pi
              JOIN products p ON pi.product_id = p.id
              WHERE pi.package_id = ?
            ''', [productId]);

            for (var comp in compRows) {
              final compStock = comp['comp_stok'] as int;
              if (compStock != -1) {
                final compQty = comp['comp_qty'] as int;
                final totalRestore = compQty * qty;
                await txn.rawUpdate(
                  'UPDATE products SET stok = stok + ?, updated_at = ? WHERE id = ?',
                  [totalRestore, DateTime.now().toIso8601String(), comp['comp_id']],
                );
              }
            }
          } else {
            final currentStock = productResult.first['stok'] as int;
            if (currentStock != -1) {
              await txn.rawUpdate(
                'UPDATE products SET stok = stok + ?, updated_at = ? WHERE id = ?',
                [qty, DateTime.now().toIso8601String(), productId],
              );
            }
          }
        }
      }

      await txn.update(
        'transactions',
        {
          'status': 'voided',
        },
        where: 'id = ?',
        whereArgs: [transactionId],
      );
    });
  }

  Future<void> _ensureManualProductExists(
    DatabaseExecutor txn,
    String produkId,
    String produkNama,
    double produkHarga,
  ) async {
    if (!produkId.startsWith('manual_')) return;

    final pCheck = await txn.query('products', where: 'id = ?', whereArgs: [produkId]);
    if (pCheck.isEmpty) {
      final anyCat = await txn.query('categories', limit: 1);
      String catId = anyCat.isNotEmpty ? (anyCat.first['id'] as String) : 'CAT_MANUAL';
      if (anyCat.isEmpty) {
        await txn.insert('categories', {
          'id': 'CAT_MANUAL',
          'nama': 'Manual Order',
          'status': 1,
          'is_deleted': 1,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      await txn.insert('products', {
        'id': produkId,
        'kategori_id': catId,
        'nama': produkNama,
        'harga': produkHarga,
        'stok': -1,
        'is_package': 0,
        'status': 1,
        'is_deleted': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }
}

