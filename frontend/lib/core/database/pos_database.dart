import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: _onConfigure,
    );
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

    // Initial Seeds
    await _seedDatabase(db);
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
      await db.insert('payment_methods', pm);
    }

    // Seed default Tax Setting (enable=0, percentage=11.0)
    await db.insert('tax_settings', {
      'id': 1,
      'enable': 0,
      'percentage': 11.0,
      'updated_at': now,
    });
  }
}
