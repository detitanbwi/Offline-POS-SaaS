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

      // 3. Clear storage (simulate fresh install / restore to new device)
      mockSecureStorage.clear();
      expect(await storage.getStoreName(), isNull);

      // 4. Simulate Restore reading from DB table
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
  });
}
