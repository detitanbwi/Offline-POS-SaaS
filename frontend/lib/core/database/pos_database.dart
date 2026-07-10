import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show sqfliteFfiInit, databaseFactoryFfi;
import '../../features/auth/services/secure_storage_service.dart';

class PosDatabase {
  static final PosDatabase instance = PosDatabase._init();
  static Database? _database;

  PosDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pos_database.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final isDesktop = !kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows);
    
    if (isDesktop) {
      sqfliteFfiInit();
    }

    final dbPath = isDesktop 
        ? await databaseFactoryFfi.getDatabasesPath()
        : await getDatabasesPath();
    final path = join(dbPath, filePath);

    final storage = SecureStorageService();
    final encryptionKey = await storage.getEncryptionKey();

    final shouldEncrypt = !kDebugMode && Platform.isAndroid && encryptionKey != null && encryptionKey.isNotEmpty;

    if (!shouldEncrypt) {
      if (isDesktop) {
        return await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 5,
            onCreate: _createDB,
            onUpgrade: _upgradeDB,
            onConfigure: _onConfigure,
          ),
        );
      } else {
        return await openDatabase(
          path,
          version: 5,
          onCreate: _createDB,
          onUpgrade: _upgradeDB,
          onConfigure: _onConfigure,
        );
      }
    }

    Database? db;
    try {
      db = await openDatabase(
        path,
        version: 5,
        password: encryptionKey,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
        onConfigure: _onConfigure,
      );
    } catch (e) {
      try {
        db = await openDatabase(
          path,
          version: 5,
          onCreate: _createDB,
          onUpgrade: _upgradeDB,
          onConfigure: _onConfigure,
        );
        if (db != null) {
          await db.execute("PRAGMA rekey = '$encryptionKey'");
        }
      } catch (innerErr) {
        rethrow;
      }
    }

    return db!;
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Categories
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        nama TEXT NOT NULL UNIQUE,
        status INTEGER NOT NULL DEFAULT 1,
        image TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 2. Products
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        kategori_id TEXT NOT NULL,
        nama TEXT NOT NULL UNIQUE,
        harga REAL NOT NULL DEFAULT 0,
        stok INTEGER NOT NULL DEFAULT 0,
        status INTEGER NOT NULL DEFAULT 1,
        image TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (kategori_id) REFERENCES categories(id) ON DELETE RESTRICT
      )
    ''');

    // 3. Stock In
    await db.execute('''
      CREATE TABLE stock_in (
        id TEXT PRIMARY KEY,
        produk_id TEXT NOT NULL,
        qty INTEGER NOT NULL,
        tanggal TEXT NOT NULL,
        catatan TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (produk_id) REFERENCES products(id) ON DELETE CASCADE
      )
    ''');

    // 4. Payment Methods
    await db.execute('''
      CREATE TABLE payment_methods (
        id TEXT PRIMARY KEY,
        nama TEXT NOT NULL UNIQUE,
        icon TEXT NOT NULL,
        aktif INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 5. Tax Settings
    await db.execute('''
      CREATE TABLE tax_settings (
        id INTEGER PRIMARY KEY DEFAULT 1,
        enable INTEGER NOT NULL DEFAULT 0,
        percentage REAL NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    // 6. Transactions
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        nomor_transaksi TEXT NOT NULL UNIQUE,
        subtotal REAL NOT NULL,
        tax_percentage REAL NOT NULL DEFAULT 0,
        tax_amount REAL NOT NULL DEFAULT 0,
        grand_total REAL NOT NULL,
        payment_method_id TEXT NOT NULL,
        payment_method_nama TEXT NOT NULL,
        nominal_bayar REAL NOT NULL DEFAULT 0,
        kembalian REAL NOT NULL DEFAULT 0,
        catatan TEXT,
        status TEXT NOT NULL DEFAULT 'completed',
        cashier_id TEXT,
        cashier_nama TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id) ON DELETE RESTRICT
      )
    ''');

    // 7. Transaction Items
    await db.execute('''
      CREATE TABLE transaction_items (
        id TEXT PRIMARY KEY,
        transaction_id TEXT NOT NULL,
        produk_id TEXT NOT NULL,
        produk_nama TEXT NOT NULL,
        produk_harga REAL NOT NULL,
        qty INTEGER NOT NULL,
        subtotal REAL NOT NULL,
        catatan TEXT,
        FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
        FOREIGN KEY (produk_id) REFERENCES products(id) ON DELETE RESTRICT
      )
    ''');

    // 8. Tables
    await db.execute('''
      CREATE TABLE tables (
        id TEXT PRIMARY KEY,
        nama TEXT NOT NULL UNIQUE,
        nomor TEXT NOT NULL UNIQUE,
        status INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 9. Orders
    await db.execute('''
      CREATE TABLE orders (
        id TEXT PRIMARY KEY,
        nomor_order TEXT NOT NULL UNIQUE,
        table_id TEXT NOT NULL,
        table_nama TEXT,
        table_nomor TEXT,
        subtotal REAL NOT NULL DEFAULT 0,
        tax_percentage REAL NOT NULL DEFAULT 0,
        tax_amount REAL NOT NULL DEFAULT 0,
        grand_total REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'draft',
        catatan TEXT,
        cashier_id TEXT,
        cashier_nama TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (table_id) REFERENCES tables(id) ON DELETE RESTRICT
      )
    ''');

    // 10. Order Items
    await db.execute('''
      CREATE TABLE order_items (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        produk_id TEXT NOT NULL,
        produk_nama TEXT NOT NULL,
        produk_harga REAL NOT NULL,
        qty INTEGER NOT NULL DEFAULT 1,
        subtotal REAL NOT NULL,
        catatan TEXT,
        status_cetak INTEGER NOT NULL DEFAULT 0,
        print_batch_id TEXT,
        FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
        FOREIGN KEY (produk_id) REFERENCES products(id) ON DELETE RESTRICT
      )
    ''');

    // 11. Print Batches
    await db.execute('''
      CREATE TABLE print_batches (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
      )
    ''');

    // 12. Printers Config
    await db.execute('''
      CREATE TABLE printers_config (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        address TEXT NOT NULL,
        type TEXT NOT NULL,
        is_connected INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // 13. Cashiers
    await db.execute('''
      CREATE TABLE cashiers (
        id TEXT PRIMARY KEY,
        nama TEXT NOT NULL,
        pin TEXT NOT NULL,
        status INTEGER NOT NULL DEFAULT 1,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Indexes for performance
    await _createIndexes(db);

    // Initial Seeds
    await _seedDatabase(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Create tables introduced in Version 2
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tables (
          id TEXT PRIMARY KEY,
          nama TEXT NOT NULL UNIQUE,
          nomor TEXT NOT NULL UNIQUE,
          status INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS orders (
          id TEXT PRIMARY KEY,
          nomor_order TEXT NOT NULL UNIQUE,
          table_id TEXT NOT NULL,
          table_nama TEXT,
          table_nomor TEXT,
          subtotal REAL NOT NULL DEFAULT 0,
          tax_percentage REAL NOT NULL DEFAULT 0,
          tax_amount REAL NOT NULL DEFAULT 0,
          grand_total REAL NOT NULL DEFAULT 0,
          status TEXT NOT NULL DEFAULT 'draft',
          catatan TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (table_id) REFERENCES tables(id) ON DELETE RESTRICT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS order_items (
          id TEXT PRIMARY KEY,
          order_id TEXT NOT NULL,
          produk_id TEXT NOT NULL,
          produk_nama TEXT NOT NULL,
          produk_harga REAL NOT NULL,
          qty INTEGER NOT NULL DEFAULT 1,
          subtotal REAL NOT NULL,
          catatan TEXT,
          status_cetak INTEGER NOT NULL DEFAULT 0,
          print_batch_id TEXT,
          FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
          FOREIGN KEY (produk_id) REFERENCES products(id) ON DELETE RESTRICT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS print_batches (
          id TEXT PRIMARY KEY,
          order_id TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS printers_config (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          address TEXT NOT NULL,
          type TEXT NOT NULL,
          is_connected INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');

      // Seed tables since they are newly added
      await _seedDefaultTables(db);
    }

    if (oldVersion < 3) {
      // Add performance indexes
      await _createIndexes(db);
    }

    if (oldVersion < 4) {
      await db.execute('ALTER TABLE categories ADD COLUMN image TEXT');
      await db.execute('ALTER TABLE products ADD COLUMN image TEXT');
    }

    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cashiers (
          id TEXT PRIMARY KEY,
          nama TEXT NOT NULL,
          pin TEXT NOT NULL,
          status INTEGER NOT NULL DEFAULT 1,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN cashier_id TEXT');
      } catch (e) {
        // ignore
      }
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN cashier_nama TEXT');
      } catch (e) {
        // ignore
      }
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN cashier_id TEXT');
      } catch (e) {
        // ignore
      }
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN cashier_nama TEXT');
      } catch (e) {
        // ignore
      }
    }
  }

  Future<void> _createIndexes(Database db) async {
    // Products
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_kategori_id ON products(kategori_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_status ON products(status)');

    // Transactions
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_payment_method_id ON transactions(payment_method_id)');

    // Transaction Items
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transaction_items_transaction_id ON transaction_items(transaction_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transaction_items_produk_id ON transaction_items(produk_id)');

    // Stock In
    await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_in_produk_id ON stock_in(produk_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_in_tanggal ON stock_in(tanggal)');

    // Orders
    await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_table_id ON orders(table_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at)');

    // Order Items
    await db.execute('CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_order_items_produk_id ON order_items(produk_id)');

    // Print Batches
    await db.execute('CREATE INDEX IF NOT EXISTS idx_print_batches_order_id ON print_batches(order_id)');
  }

  Future<void> _seedDatabase(Database db) async {
    final now = DateTime.now().toIso8601String();
    
    // Seed default Payment Methods
    final payments = [
      {'id': 'pm-tunai', 'nama': 'Tunai', 'icon': 'money', 'aktif': 1, 'created_at': now, 'updated_at': now},
      {'id': 'pm-qris', 'nama': 'QRIS', 'icon': 'qr_code', 'aktif': 1, 'created_at': now, 'updated_at': now},
      {'id': 'pm-gopay', 'nama': 'Gopay', 'icon': 'wallet', 'aktif': 1, 'created_at': now, 'updated_at': now},
      {'id': 'pm-shopeepay', 'nama': 'ShopeePay', 'icon': 'wallet', 'aktif': 1, 'created_at': now, 'updated_at': now},
      {'id': 'pm-dana', 'nama': 'Dana', 'icon': 'wallet', 'aktif': 1, 'created_at': now, 'updated_at': now},
      {'id': 'pm-bca', 'nama': 'BCA', 'icon': 'account_balance', 'aktif': 1, 'created_at': now, 'updated_at': now},
      {'id': 'pm-mandiri', 'nama': 'Mandiri', 'icon': 'account_balance', 'aktif': 1, 'created_at': now, 'updated_at': now},
      {'id': 'pm-bni', 'nama': 'BNI', 'icon': 'account_balance', 'aktif': 1, 'created_at': now, 'updated_at': now},
      {'id': 'pm-bri', 'nama': 'BRI', 'icon': 'account_balance', 'aktif': 1, 'created_at': now, 'updated_at': now},
    ];

    for (var pm in payments) {
      await db.insert('payment_methods', pm, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // Seed default Tax Setting (enable=0, percentage=11.0)
    await db.insert('tax_settings', {
      'id': 1,
      'enable': 0,
      'percentage': 11.0,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // Seed default Tables
    await _seedDefaultTables(db);
  }

  Future<void> _seedDefaultTables(Database db) async {
    final now = DateTime.now().toIso8601String();
    final defaultTables = [
      {'id': 'tbl-1', 'nama': 'Meja 01', 'nomor': '01', 'status': 0, 'created_at': now, 'updated_at': now},
      {'id': 'tbl-2', 'nama': 'Meja 02', 'nomor': '02', 'status': 0, 'created_at': now, 'updated_at': now},
      {'id': 'tbl-3', 'nama': 'Meja 03', 'nomor': '03', 'status': 0, 'created_at': now, 'updated_at': now},
      {'id': 'tbl-4', 'nama': 'Meja 04', 'nomor': '04', 'status': 0, 'created_at': now, 'updated_at': now},
      {'id': 'tbl-5', 'nama': 'Meja 05', 'nomor': '05', 'status': 0, 'created_at': now, 'updated_at': now},
    ];

    for (var table in defaultTables) {
      await db.insert('tables', table, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
}
