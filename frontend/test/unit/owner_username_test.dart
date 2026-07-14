import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/auth/services/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('Owner Username Storage Tests', () {
    late SecureStorageService storage;

    setUp(() async {
      storage = SecureStorageService();
      await storage.clearAll();
    });

    test('getOwnerUsername returns default "owner" when not set', () async {
      final username = await storage.getOwnerUsername();
      expect(username, equals('owner'));
    });

    test('saveOwnerUsername saves and retrieves custom owner username', () async {
      await storage.saveOwnerUsername('super_owner');
      final username = await storage.getOwnerUsername();
      expect(username, equals('super_owner'));
    });

    test('saveOwnerUsername trims whitespace properly', () async {
      await storage.saveOwnerUsername('   owner_boss   ');
      final username = await storage.getOwnerUsername();
      expect(username, equals('owner_boss'));
    });
  });
}
