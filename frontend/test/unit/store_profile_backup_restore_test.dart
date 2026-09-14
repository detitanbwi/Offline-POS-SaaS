import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/auth/services/secure_storage_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final Map<String, String> mockSecureStorage = {};

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'read':
          return mockSecureStorage[methodCall.arguments['key']];
        case 'write':
          mockSecureStorage[methodCall.arguments['key']] = methodCall.arguments['value'];
          return null;
        case 'delete':
          mockSecureStorage.remove(methodCall.arguments['key']);
          return null;
        case 'deleteAll':
          mockSecureStorage.clear();
          return null;
        case 'readAll':
          return mockSecureStorage;
        default:
          return null;
      }
    });
  });

  group('Store Profile Backup and Restore Tests', () {
    late Database db;
    late SecureStorageService storage;

    setUp(() async {
      mockSecureStorage.clear();
      storage = SecureStorageService();
      db = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS store_profile_backup (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      });
    });

    tearDown(() async {
      await db.close();
    });

    test('Store profile data correctly writes to store_profile_backup table and restores back', () async {
      // 1. Setup initial store profile
      await storage.saveStoreInfo(
        name: 'Toko Kopi Senja',
        address: 'Jl. Merdeka No. 10',
        phone: '08123456789',
      );
      await storage.saveOwnerName('Budi Santoso');
      await storage.saveOwnerUsername('budi_owner');

      // 2. Simulate Backup writing to DB table
      final name = await storage.getStoreName() ?? '';
      final address = await storage.getStoreAddress() ?? '';
      final phone = await storage.getStorePhone() ?? '';
      final ownerName = await storage.getOwnerName() ?? '';
      final ownerUsername = await storage.getOwnerUsername() ?? '';
      final dummyLogoBase64 = base64Encode(utf8.encode('fake_png_logo_data'));

      final entries = {
        'store_name': name,
        'store_address': address,
        'store_phone': phone,
        'owner_name': ownerName,
        'owner_username': ownerUsername,
        'store_logo_base64': dummyLogoBase64,
      };

      for (final entry in entries.entries) {
        await db.insert(
          'store_profile_backup',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Verify records in DB
      final rows = await db.query('store_profile_backup');
      expect(rows.length, equals(6));

      // 3. Overwrite with new store profile (simulate user editing before restore)
      await storage.saveStoreInfo(
        name: 'Toko Baru Yang Belum Di-restore',
        address: 'Jl. Sementara',
        phone: '08999999999',
      );
      expect(await storage.getStoreName(), equals('Toko Baru Yang Belum Di-restore'));

      // 4. Simulate Restore reading from DB table and overwriting current info
      final backupRows = await db.query('store_profile_backup');
      final map = <String, String>{};
      for (final r in backupRows) {
        map[r['key'] as String] = (r['value'] as String?) ?? '';
      }

      await storage.saveStoreInfo(
        name: map['store_name'] ?? '',
        address: map['store_address'] ?? '',
        phone: map['store_phone'] ?? '',
      );
      await storage.saveOwnerName(map['owner_name'] ?? '');
      await storage.saveOwnerUsername(map['owner_username'] ?? '');

      // 5. Verify restored store profile
      expect(await storage.getStoreName(), equals('Toko Kopi Senja'));
      expect(await storage.getStoreAddress(), equals('Jl. Merdeka No. 10'));
      expect(await storage.getStorePhone(), equals('08123456789'));
      expect(await storage.getOwnerName(), equals('Budi Santoso'));
      expect(await storage.getOwnerUsername(), equals('budi_owner'));
    });

    test('Product and Category images backup to Base64 table and restore to new paths', () async {
      // 1. Create tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS products (
          id TEXT PRIMARY KEY,
          nama TEXT NOT NULL,
          image TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories (
          id TEXT PRIMARY KEY,
          nama TEXT NOT NULL,
          image TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS product_images_backup (
          product_id TEXT PRIMARY KEY,
          file_name TEXT,
          base64_data TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS category_images_backup (
          category_id TEXT PRIMARY KEY,
          file_name TEXT,
          base64_data TEXT
        )
      ''');

      // 2. Insert initial products and categories with old device paths
      await db.insert('products', {
        'id': 'prod-1',
        'nama': 'Nasi Goreng Spesial',
        'image': '/old/device/path/pos_images/nasgor.png',
      });
      await db.insert('products', {
        'id': 'prod-2',
        'nama': 'Es Teh Manis',
        'image': 'https://example.com/remote_image.png', // Remote URL should not be broken
      });
      await db.insert('categories', {
        'id': 'cat-1',
        'nama': 'Makanan Utama',
        'image': '/old/device/path/pos_images/makanan.png',
      });

      // 3. Simulate backing up images to Base64
      final fakeNasgorBytes = utf8.encode('fake_nasgor_png_bytes');
      final fakeMakananBytes = utf8.encode('fake_makanan_png_bytes');

      await db.insert('product_images_backup', {
        'product_id': 'prod-1',
        'file_name': 'nasgor.png',
        'base64_data': base64Encode(fakeNasgorBytes),
      });

      await db.insert('category_images_backup', {
        'category_id': 'cat-1',
        'file_name': 'makanan.png',
        'base64_data': base64Encode(fakeMakananBytes),
      });

      // 4. Verify backup rows
      final prodBackupRows = await db.query('product_images_backup');
      expect(prodBackupRows.length, equals(1));
      expect(prodBackupRows.first['product_id'], equals('prod-1'));

      final catBackupRows = await db.query('category_images_backup');
      expect(catBackupRows.length, equals(1));
      expect(catBackupRows.first['category_id'], equals('cat-1'));

      // 5. Simulate restoration on a new device where local directory is /new/device/pos_images/
      const newDeviceDir = '/new/device/pos_images';
      for (final r in prodBackupRows) {
        final prodId = r['product_id'] as String;
        final fileName = r['file_name'] as String;
        final newPath = '$newDeviceDir/restored_$fileName';
        await db.update('products', {'image': newPath}, where: 'id = ?', whereArgs: [prodId]);
      }

      for (final r in catBackupRows) {
        final catId = r['category_id'] as String;
        final fileName = r['file_name'] as String;
        final newPath = '$newDeviceDir/restored_$fileName';
        await db.update('categories', {'image': newPath}, where: 'id = ?', whereArgs: [catId]);
      }

      // 6. Verify restored database has updated paths pointing to the new device storage
      final prod1 = (await db.query('products', where: 'id = ?', whereArgs: ['prod-1'])).first;
      expect(prod1['image'], equals('/new/device/pos_images/restored_nasgor.png'));

      final prod2 = (await db.query('products', where: 'id = ?', whereArgs: ['prod-2'])).first;
      expect(prod2['image'], equals('https://example.com/remote_image.png'));

      final cat1 = (await db.query('categories', where: 'id = ?', whereArgs: ['cat-1'])).first;
      expect(cat1['image'], equals('/new/device/pos_images/restored_makanan.png'));
    });
  });
}
