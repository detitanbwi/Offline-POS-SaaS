import 'dart:convert';
import 'dart:io';
import 'package:android_id/android_id.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class DeviceFingerprintService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final _androidIdPlugin = const AndroidId();
  final _deviceInfo = DeviceInfoPlugin();

  static const String _keyInstallationId = 'installation_id';

  Future<String> getInstallationId() async {
    String? id = await _storage.read(key: _keyInstallationId);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await _storage.write(key: _keyInstallationId, value: id);
    }
    return id;
  }

  Future<String> getAndroidId() async {
    if (Platform.isAndroid) {
      try {
        final androidId = await _androidIdPlugin.getId();
        return androidId ?? 'unknown_android_id';
      } catch (e) {
        return 'unknown_android_id_error';
      }
    }
    return 'simulator_android_id';
  }

  Future<Map<String, String>> getDeviceInfo() async {
    if (Platform.isAndroid) {
      try {
        final info = await _deviceInfo.androidInfo;
        return {
          'device_name': '${info.brand} ${info.model}',
          'device_model': info.model,
          'device_brand': info.brand,
          'manufacturer': info.manufacturer,
        };
      } catch (e) {
        return {
          'device_name': 'Android Device',
          'device_model': 'Android',
          'device_brand': 'Android',
          'manufacturer': 'Android',
        };
      }
    }
    return {
      'device_name': 'Linux Simulator',
      'device_model': 'Simulator',
      'device_brand': 'Google',
      'manufacturer': 'Google',
    };
  }

  Future<String> generateFingerprint(String activationTimestamp) async {
    final androidId = await getAndroidId();
    final info = await getDeviceInfo();
    final manufacturer = info['manufacturer'] ?? 'unknown';
    final brand = info['device_brand'] ?? 'unknown';
    final model = info['device_model'] ?? 'unknown';
    final installationId = await getInstallationId();

    final rawString = '$androidId$manufacturer$brand$model$installationId$activationTimestamp';
    final bytes = utf8.encode(rawString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
