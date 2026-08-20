import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class DeviceFingerprintService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
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

  Future<String> getHardwareId() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        const platform = MethodChannel('com.wirodev.saaspos/device_id');
        final String? widevineId = await platform.invokeMethod('getWidevineId');
        if (widevineId != null && widevineId.isNotEmpty) {
          return widevineId;
        }
      } catch (e) {
        // Fallback to installation id if widevine fails
      }
      return await getInstallationId();
    }
    return await getInstallationId();
  }

  Future<Map<String, String>> getDeviceInfo() async {
    if (!kIsWeb && Platform.isAndroid) {
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
      'device_name': kIsWeb ? 'Web Browser' : 'Linux Simulator',
      'device_model': kIsWeb ? 'Chrome Web' : 'Simulator',
      'device_brand': kIsWeb ? 'Google Chrome' : 'Google',
      'manufacturer': kIsWeb ? 'Browser' : 'Google',
    };
  }

  Future<String> generateFingerprint() async {
    final hardwareId = await getHardwareId();
    final info = await getDeviceInfo();
    final manufacturer = info['manufacturer'] ?? 'unknown';
    final brand = info['device_brand'] ?? 'unknown';
    final model = info['device_model'] ?? 'unknown';

    final rawString = '$hardwareId$manufacturer$brand$model';
    final bytes = utf8.encode(rawString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
