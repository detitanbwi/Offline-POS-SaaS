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
    if (_database != null && _database!.isOpen) return _database!;
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

    Future<Database> openWithParams({String? pwd}) async {
      if (isDesktop) {
        return await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 13,
            onCreate: _createDB,
            onUpgrade: _upgradeDB,
            onConfigure: _onConfigure,
          ),
        );
      } else {
        return await openDatabase(
          path,
          version: 13,
          password: pwd,
          onCreate: _createDB,
          onUpgrade: _upgradeDB,
          onConfigure: _onConfigure,
        );
      }
    }

    Database db;
    if (!shouldEncrypt) {
      try {
        db = await openWithParams();
      } catch (e) {
        debugPrint('[PosDatabase] Unencrypted open failed: $e. Re-creating DB...');
        try {
          if (isDesktop) {
            await databaseFactoryFfi.deleteDatabase(path);
          } else {
            await deleteDatabase(path);
          }
        } catch (_) {}
        db = await openWithParams();
      }
    } else {
      try {
        db = await openWithParams(pwd: encryptionKey);
      } catch (e) {
        debugPrint('[PosDatabase] Encrypted open failed: $e. Trying fallback...');
        try {
          db = await openWithParams();
          await db.execute("PRAGMA rekey = '$encryptionKey'");
        } catch (innerErr) {
          debugPrint('[PosDatabase] Fallback failed ($innerErr). Re-creating fresh database...');
          try {
            if (isDesktop) {
              await databaseFactoryFfi.deleteDatabase(path);
            } else {
              await deleteDatabase(path);
            }
          } catch (_) {}
          db = await openWithParams(pwd: encryptionKey);
        }
      }
    }

    await _ensureNewColumnsExist(db);
    return db;
  }

  Future<void> _ensureNewColumnsExist(Database db) async {
    await _addColumnIfNotExists(db, 'orders', 'online_platform_total', 'REAL');
    await _addColumnIfNotExists(db, 'orders', 'platform_difference', 'REAL');
    await _addColumnIfNotExists(db, 'orders', 'is_bill_printed', 'INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfNotExists(db, 'orders', 'bill_printed_at', 'TEXT');
    await _addColumnIfNotExists(db, 'transactions', 'online_platform_total', 'REAL');
    await _addColumnIfNotExists(db, 'transactions', 'platform_difference', 'REAL');
    await _addColumnIfNotExists(db, 'transactions', 'online_platform', 'TEXT');
  }

  Future<void> _addColumnIfNotExists(Database db, String table, String column, String type) async {
    final result = await db.rawQuery("PRAGMA table_info($table)");
    final hasColumn = result.any((row) => row['name'] == column);
    if (!hasColumn) {
      await db.execute("ALTER TABLE $table ADD COLUMN $column $type");
    }
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
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT,
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
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT,
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
        type TEXT NOT NULL DEFAULT 'in',
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
        master_order_id TEXT,
        subtotal REAL NOT NULL,
        tax_percentage REAL NOT NULL DEFAULT 0,
        tax_amount REAL NOT NULL DEFAULT 0,
        grand_total REAL NOT NULL,
        online_platform_total REAL,
        platform_difference REAL,
        online_platform TEXT,
        payment_method_id TEXT NOT NULL,
        payment_method_nama TEXT NOT NULL,
        nominal_bayar REAL NOT NULL DEFAULT 0,
        kembalian REAL NOT NULL DEFAULT 0,
        catatan TEXT,
        customer_name TEXT,
        order_type TEXT NOT NULL DEFAULT 'dine_in',
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
        order_item_id TEXT,
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
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 9. Orders
    await db.execute('''
      CREATE TABLE orders (
        id TEXT PRIMARY KEY,
        nomor_order TEXT NOT NULL UNIQUE,
        table_id TEXT,
        table_nama TEXT,
        table_nomor TEXT,
        customer_name TEXT,
        order_type TEXT NOT NULL DEFAULT 'dine_in',
        take_away_sub_type TEXT,
        online_platform TEXT,
        clear_table_reason TEXT,
        subtotal REAL NOT NULL DEFAULT 0,
        tax_percentage REAL NOT NULL DEFAULT 0,
        tax_amount REAL NOT NULL DEFAULT 0,
        grand_total REAL NOT NULL DEFAULT 0,
        online_platform_total REAL,
        platform_difference REAL,
        status TEXT NOT NULL DEFAULT 'draft',
        catatan TEXT,
        cashier_id TEXT,
        cashier_nama TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 10. Order Items
    await db.execute('''
      CREATE TABLE order_items (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        master_order_id TEXT,
        batch_id TEXT,
        produk_id TEXT NOT NULL,
        produk_nama TEXT NOT NULL,
        produk_harga REAL NOT NULL,
        base_price REAL NOT NULL DEFAULT 0,
        effective_price REAL NOT NULL DEFAULT 0,
        qty INTEGER NOT NULL DEFAULT 1,
        qty_ordered INTEGER NOT NULL DEFAULT 1,
        qty_paid INTEGER NOT NULL DEFAULT 0,
        subtotal REAL NOT NULL,
        catatan TEXT,
        status_cetak INTEGER NOT NULL DEFAULT 0,
        is_cancelled INTEGER NOT NULL DEFAULT 0,
        cancelled_qty INTEGER NOT NULL DEFAULT 0,
        cancelled_at TEXT,
        cancelled_reason TEXT,
        cancelled_by_manager_id TEXT,
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
        payment_status TEXT NOT NULL DEFAULT 'unpaid',
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
        paper_size INTEGER NOT NULL DEFAULT 58,
        chars_per_line INTEGER NOT NULL DEFAULT 0,
        auto_cut INTEGER NOT NULL DEFAULT 0,
        print_density TEXT NOT NULL DEFAULT 'normal',
        auto_reconnect INTEGER NOT NULL DEFAULT 1,
        is_connected INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // 13. Cashiers
    await db.execute('''
      CREATE TABLE cashiers (
        id TEXT PRIMARY KEY,
        nama TEXT NOT NULL,
        username TEXT NOT NULL,
        pin TEXT NOT NULL,
        status INTEGER NOT NULL DEFAULT 1,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        is_owner INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 14. Online Platforms
    await db.execute('''
      CREATE TABLE online_platforms (
        id TEXT PRIMARY KEY,
        nama TEXT NOT NULL UNIQUE,
        markup_type TEXT NOT NULL DEFAULT 'percentage',
        markup_value REAL NOT NULL DEFAULT 0,
        driver_receipt_format INTEGER NOT NULL DEFAULT 1,
        aktif INTEGER NOT NULL DEFAULT 1,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 15. Master Orders (Table Session / Open Tab Header)
    await db.execute('''
      CREATE TABLE master_orders (
        id TEXT PRIMARY KEY,
        nomor_order TEXT NOT NULL UNIQUE,
        table_id TEXT,
        customer_name TEXT,
        order_type TEXT NOT NULL,
        platform_id TEXT,
        platform_reference_id TEXT,
        subtotal REAL NOT NULL DEFAULT 0,
        tax_percentage REAL NOT NULL DEFAULT 0,
        tax_amount REAL NOT NULL DEFAULT 0,
        grand_total REAL NOT NULL DEFAULT 0,
        total_paid REAL NOT NULL DEFAULT 0,
        session_status TEXT NOT NULL DEFAULT 'open',
        payment_status TEXT NOT NULL DEFAULT 'unpaid',
        last_activity_at TEXT NOT NULL,
        all_items_served_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (table_id) REFERENCES tables(id) ON DELETE SET NULL,
        FOREIGN KEY (platform_id) REFERENCES online_platforms(id) ON DELETE SET NULL
      )
    ''');

    // 16. Order Batches (Child Orders / Rounds of Ordering)
    await db.execute('''
      CREATE TABLE order_batches (
        id TEXT PRIMARY KEY,
        master_order_id TEXT NOT NULL,
        batch_number INTEGER NOT NULL,
        created_by_cashier_id TEXT,
        payment_status TEXT NOT NULL DEFAULT 'unpaid',
        created_at TEXT NOT NULL,
        FOREIGN KEY (master_order_id) REFERENCES master_orders(id) ON DELETE CASCADE,
        UNIQUE(master_order_id, batch_number)
      )
    ''');

    // 17. Platform SKU Prices (Price Overrides per SKU per Platform)
    await db.execute('''
      CREATE TABLE platform_sku_prices (
        id TEXT PRIMARY KEY,
        platform_id TEXT NOT NULL,
        produk_id TEXT NOT NULL,
        override_price REAL NOT NULL,
        FOREIGN KEY (platform_id) REFERENCES online_platforms(id) ON DELETE CASCADE,
        FOREIGN KEY (produk_id) REFERENCES products(id) ON DELETE CASCADE,
        UNIQUE(platform_id, produk_id)
      )
    ''');

    // 18. ESC/POS Thermal Print Queue Jobs
    await db.execute('''
      CREATE TABLE print_queue_jobs (
        id TEXT PRIMARY KEY,
        target_printer_type TEXT NOT NULL,
        target_address TEXT NOT NULL,
        payload_bytes BLOB NOT NULL,
        job_type TEXT NOT NULL,
        reference_id TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        retry_count INTEGER NOT NULL DEFAULT 0,
        max_retries INTEGER NOT NULL DEFAULT 5,
        error_message TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 19. Void Authorization Logs
    await db.execute('''
      CREATE TABLE void_authorization_logs (
        id TEXT PRIMARY KEY,
        master_order_id TEXT NOT NULL,
        order_item_id TEXT NOT NULL,
        manager_id TEXT NOT NULL,
        manager_nama TEXT NOT NULL,
        qty_voided INTEGER NOT NULL,
        reason TEXT NOT NULL,
        was_kitchen_notified INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (master_order_id) REFERENCES master_orders(id) ON DELETE CASCADE
      )
    ''');

    // Indexes for performance
    await _createIndexes(db);

    // Initial Seeds
    await _seedDatabase(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 13) {
      // TAHAP PENGEMBANGAN: Hapus semua tabel dan buat ulang dari awal untuk memastikan schema bersih
      bool droppedAll = false;
      while (!droppedAll) {
        final tables = await db.rawQuery('SELECT name FROM sqlite_master WHERE type="table" AND name NOT LIKE "sqlite_%"');
        if (tables.isEmpty) {
          droppedAll = true;
          break;
        }
        int droppedCount = 0;
        for (final table in tables) {
          final tableName = table['name'];
          try {
            await db.execute('DROP TABLE IF EXISTS $tableName');
            droppedCount++;
          } catch (e) {
            // Ignore foreign key constraint errors and retry in next pass
          }
        }
        if (droppedCount == 0) {
          break; // Avoid infinite loop if a table cannot be dropped for other reasons
        }
      }
      await _createDB(db, newVersion);
      return; // Skip migrasi versi lama karena database sudah di-reset
    }

    if (oldVersion < 2) {
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
          payment_status TEXT NOT NULL DEFAULT 'unpaid',
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

      await _seedDefaultTables(db);
    }

    if (oldVersion < 3) {
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
      } catch (_) {
        // Column may already exist
      }
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN cashier_nama TEXT');
      } catch (_) {
        // Column may already exist
      }
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN cashier_id TEXT');
      } catch (_) {
        // Column may already exist
      }
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN cashier_nama TEXT');
      } catch (_) {
        // Column may already exist
      }
    }

    if (oldVersion < 6) {
      final alterColumns = [
        'ALTER TABLE printers_config ADD COLUMN paper_size INTEGER NOT NULL DEFAULT 58',
        'ALTER TABLE printers_config ADD COLUMN chars_per_line INTEGER NOT NULL DEFAULT 0',
        'ALTER TABLE printers_config ADD COLUMN auto_cut INTEGER NOT NULL DEFAULT 0',
        'ALTER TABLE printers_config ADD COLUMN print_density TEXT NOT NULL DEFAULT \'normal\'',
        'ALTER TABLE printers_config ADD COLUMN auto_reconnect INTEGER NOT NULL DEFAULT 1',
      ];
      for (final sql in alterColumns) {
        try {
          await db.execute(sql);
        } catch (e) {
          debugPrint('Migration error (version 6): $e');
        }
      }
    }

    if (oldVersion < 7) {
      final v7AlterColumns = [
        "ALTER TABLE stock_in ADD COLUMN type TEXT NOT NULL DEFAULT 'in'",
        "ALTER TABLE orders ADD COLUMN customer_name TEXT",
        "ALTER TABLE orders ADD COLUMN order_type TEXT NOT NULL DEFAULT 'dine_in'",
        "ALTER TABLE transactions ADD COLUMN customer_name TEXT",
        "ALTER TABLE transactions ADD COLUMN order_type TEXT NOT NULL DEFAULT 'dine_in'",
      ];
      for (final sql in v7AlterColumns) {
        try {
          await db.execute(sql);
        } catch (e) {
          debugPrint('Migration error (version 7): $e');
        }
      }
    }

    if (oldVersion < 8) {
      final v8AlterColumns = [
        "ALTER TABLE tables ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE tables ADD COLUMN deleted_at TEXT",
        "ALTER TABLE orders ADD COLUMN take_away_sub_type TEXT",
        "ALTER TABLE orders ADD COLUMN online_platform TEXT",
        "ALTER TABLE orders ADD COLUMN clear_table_reason TEXT",
        "ALTER TABLE order_items ADD COLUMN is_cancelled INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE order_items ADD COLUMN cancelled_at TEXT",
        "ALTER TABLE order_items ADD COLUMN cancelled_reason TEXT",
        "ALTER TABLE products ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE products ADD COLUMN deleted_at TEXT",
        "ALTER TABLE categories ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE categories ADD COLUMN deleted_at TEXT",
        "ALTER TABLE cashiers ADD COLUMN is_owner INTEGER NOT NULL DEFAULT 0",
      ];
      for (final sql in v8AlterColumns) {
        try {
          await db.execute(sql);
        } catch (e) {
          debugPrint('Migration error (version 8): $e');
        }
      }

      await db.execute('''
        CREATE TABLE IF NOT EXISTS online_platforms (
          id TEXT PRIMARY KEY,
          nama TEXT NOT NULL UNIQUE,
          aktif INTEGER NOT NULL DEFAULT 1,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tax_settings (
          id INTEGER PRIMARY KEY DEFAULT 1,
          enable INTEGER NOT NULL DEFAULT 0,
          percentage REAL NOT NULL DEFAULT 0,
          updated_at TEXT NOT NULL
        )
      ''');
      
      final now = DateTime.now().toIso8601String();
      await db.insert('tax_settings', {
        'id': 1,
        'enable': 0,
        'percentage': 11.0,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS master_orders (
          id TEXT PRIMARY KEY,
          nomor_order TEXT NOT NULL UNIQUE,
          table_id TEXT,
          customer_name TEXT,
          order_type TEXT NOT NULL,
          platform_id TEXT,
          platform_reference_id TEXT,
          subtotal REAL NOT NULL DEFAULT 0,
          tax_percentage REAL NOT NULL DEFAULT 0,
          tax_amount REAL NOT NULL DEFAULT 0,
          grand_total REAL NOT NULL DEFAULT 0,
          total_paid REAL NOT NULL DEFAULT 0,
          session_status TEXT NOT NULL DEFAULT 'open',
          payment_status TEXT NOT NULL DEFAULT 'unpaid',
          last_activity_at TEXT NOT NULL,
          all_items_served_at TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (table_id) REFERENCES tables(id) ON DELETE SET NULL,
          FOREIGN KEY (platform_id) REFERENCES online_platforms(id) ON DELETE SET NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS order_batches (
          id TEXT PRIMARY KEY,
          master_order_id TEXT NOT NULL,
          batch_number INTEGER NOT NULL,
          created_by_cashier_id TEXT,
          payment_status TEXT NOT NULL DEFAULT 'unpaid',
          created_at TEXT NOT NULL,
          FOREIGN KEY (master_order_id) REFERENCES master_orders(id) ON DELETE CASCADE,
          UNIQUE(master_order_id, batch_number)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS platform_sku_prices (
          id TEXT PRIMARY KEY,
          platform_id TEXT NOT NULL,
          produk_id TEXT NOT NULL,
          override_price REAL NOT NULL,
          FOREIGN KEY (platform_id) REFERENCES online_platforms(id) ON DELETE CASCADE,
          FOREIGN KEY (produk_id) REFERENCES products(id) ON DELETE CASCADE,
          UNIQUE(platform_id, produk_id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS print_queue_jobs (
          id TEXT PRIMARY KEY,
          target_printer_type TEXT NOT NULL,
          target_address TEXT NOT NULL,
          payload_bytes BLOB NOT NULL,
          job_type TEXT NOT NULL,
          reference_id TEXT,
          status TEXT NOT NULL DEFAULT 'pending',
          retry_count INTEGER NOT NULL DEFAULT 0,
          max_retries INTEGER NOT NULL DEFAULT 5,
          error_message TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS void_authorization_logs (
          id TEXT PRIMARY KEY,
          master_order_id TEXT NOT NULL,
          order_item_id TEXT NOT NULL,
          manager_id TEXT NOT NULL,
          manager_nama TEXT NOT NULL,
          qty_voided INTEGER NOT NULL,
          reason TEXT NOT NULL,
          was_kitchen_notified INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          FOREIGN KEY (master_order_id) REFERENCES master_orders(id) ON DELETE CASCADE
        )
      ''');

      // Safely add new columns to existing tables if they don't exist
      for (final stmt in [
        "ALTER TABLE online_platforms ADD COLUMN markup_type TEXT NOT NULL DEFAULT 'percentage'",
        "ALTER TABLE online_platforms ADD COLUMN markup_value REAL NOT NULL DEFAULT 0",
        "ALTER TABLE online_platforms ADD COLUMN driver_receipt_format INTEGER NOT NULL DEFAULT 1",
        "ALTER TABLE order_items ADD COLUMN master_order_id TEXT",
        "ALTER TABLE order_items ADD COLUMN batch_id TEXT",
        "ALTER TABLE order_items ADD COLUMN base_price REAL NOT NULL DEFAULT 0",
        "ALTER TABLE order_items ADD COLUMN effective_price REAL NOT NULL DEFAULT 0",
        "ALTER TABLE order_items ADD COLUMN qty_ordered INTEGER NOT NULL DEFAULT 1",
        "ALTER TABLE order_items ADD COLUMN qty_paid INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE order_items ADD COLUMN cancelled_qty INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE order_items ADD COLUMN cancelled_by_manager_id TEXT",
        "ALTER TABLE transactions ADD COLUMN master_order_id TEXT",
        "ALTER TABLE transaction_items ADD COLUMN order_item_id TEXT",
      ]) {
        try {
          await db.execute(stmt);
        } catch (_) {}
      }
    }

    if (oldVersion < 11) {
      try {
        await db.execute("ALTER TABLE cashiers ADD COLUMN username TEXT;");
        await db.execute("UPDATE cashiers SET username = LOWER(REPLACE(nama, ' ', '_')) WHERE username IS NULL OR username = '';");
      } catch (_) {}
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

    // Master Orders
    await db.execute('CREATE INDEX IF NOT EXISTS idx_master_orders_table_status ON master_orders(table_id, session_status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_master_orders_status ON master_orders(session_status, payment_status)');

    // Order Items (Master-Child)
    await db.execute('CREATE INDEX IF NOT EXISTS idx_order_items_master_batch ON order_items(master_order_id, batch_id)');

    // Print Queue Jobs
    await db.execute('CREATE INDEX IF NOT EXISTS idx_print_queue_status ON print_queue_jobs(status, retry_count)');

    // Cashiers
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cashiers_username ON cashiers(username)');
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

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      try {
        await db.close();
      } catch (_) {}
      _database = null;
    }
  }

  Future<void> deleteDatabaseFile() async {
    await close();
    final isDesktop = !kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows);
    final dbPath = isDesktop 
        ? await databaseFactoryFfi.getDatabasesPath()
        : await getDatabasesPath();
    final path = join(dbPath, 'pos_database.db');
    try {
      if (isDesktop) {
        await databaseFactoryFfi.deleteDatabase(path);
      } else {
        await deleteDatabase(path);
      }
    } catch (_) {}
  }
}
