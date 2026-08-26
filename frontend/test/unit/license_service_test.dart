import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/device_fingerprint_service.dart';
import 'package:frontend/features/license/services/license_service.dart';
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

  group('DeviceFingerprintService Tests', () {
    late DeviceFingerprintService service;

    setUp(() {
      service = DeviceFingerprintService();
    });

    test('generateFingerprint produces a valid SHA-256 hash', () async {
      final hash = await service.generateFingerprint();
      
      expect(hash, isNotNull);
      expect(hash.length, 64);
    });

    test('getHardwareId returns non-empty value', () async {
      final hardwareId = await service.getHardwareId();
      expect(hardwareId, isNotEmpty);
    });

    test('getDeviceInfo contains expected properties', () async {
      final info = await service.getDeviceInfo();
      expect(info, contains('device_name'));
      expect(info, contains('device_model'));
      expect(info, contains('device_brand'));
    });
  });

  group('LicenseService Offline Checks', () {
    late LicenseService licenseService;
    late SecureStorageService storage;

    setUp(() {
      storage = SecureStorageService();
      licenseService = LicenseService(storage, DeviceFingerprintService());
    });

    test('checkLicenseOffline returns false when no expiry is set', () async {
      await storage.clearAll();
      final isValid = await licenseService.checkLicenseOffline();
      expect(isValid, isFalse);
    });

    test('checkLicenseOffline returns true when subscription is active and not expired', () async {
      await storage.clearAll();
      await storage.saveActivationData(
        activationToken: 'test_token',
        licenseKey: 'PRO-1234-5678',
        encryptionKey: 'test_enc_key',
        fingerprintHash: 'test_fp',
        expiryDateStr: DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      );
      await storage.saveLastValidation(DateTime.now().subtract(const Duration(days: 10)).toIso8601String());

      final isValid = await licenseService.checkLicenseOffline();
      expect(isValid, isTrue);
    });

    test('checkLicenseOffline returns false when subscription has expired', () async {
      await storage.clearAll();
      await storage.saveActivationData(
        activationToken: 'test_token',
        licenseKey: 'PRO-1234-5678',
        encryptionKey: 'test_enc_key',
        fingerprintHash: 'test_fp',
        expiryDateStr: DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      );
      await storage.saveLastValidation(DateTime.now().subtract(const Duration(days: 2)).toIso8601String());

      final isValid = await licenseService.checkLicenseOffline();
      expect(isValid, isFalse);
    });

    test('checkLicenseOffline returns false when system clock is manipulated backwards', () async {
      await storage.clearAll();
      await storage.saveActivationData(
        activationToken: 'test_token',
        licenseKey: 'PRO-1234-5678',
        encryptionKey: 'test_enc_key',
        fingerprintHash: 'test_fp',
        expiryDateStr: DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      );
      // Last validation recorded in the future
      await storage.saveLastValidation(DateTime.now().add(const Duration(days: 1)).toIso8601String());

      final isValid = await licenseService.checkLicenseOffline();
      expect(isValid, isFalse);
    });
  });
}
