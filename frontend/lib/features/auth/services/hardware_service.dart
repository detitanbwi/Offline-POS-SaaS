import 'dart:io';
import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';

class HardwareService {
  final _androidIdPlugin = const AndroidId();

  Future<String> getDeviceId() async {
    if (Platform.isAndroid) {
      try {
        final id = await _androidIdPlugin.getId();
        return id ?? 'unknown_android_id';
      } catch (e) {
        return 'unknown_android_id_error';
      }
    } else if (Platform.isIOS) {
      final deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown_ios';
    }
    return 'unknown_device';
  }
}
