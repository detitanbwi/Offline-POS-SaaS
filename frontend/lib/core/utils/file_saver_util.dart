import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class FileSaverUtil {
  /// Mendapatkan direktori 'Downloads' publik sesuai OS (Android, Windows, Mac, Linux)
  static Future<Directory> getDownloadsDirectoryPath() async {
    if (kIsWeb) {
      return await getApplicationDocumentsDirectory();
    }

    if (Platform.isAndroid) {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) {
        return downloadDir;
      }
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) return extDir;
      } catch (_) {}
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final winDownload = Directory('$userProfile\\Downloads');
        if (await winDownload.exists()) {
          return winDownload;
        }
      }
    } else if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        final macDownload = Directory('$home/Downloads');
        if (await macDownload.exists()) {
          return macDownload;
        }
      }
    }

    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null && await downloadsDir.exists()) {
        return downloadsDir;
      }
    } catch (_) {}

    return await getApplicationDocumentsDirectory();
  }

  /// Menyimpan Uint8List bytes ke file di folder Downloads dan mengembalikan objek File yang disimpan
  static Future<File> saveToDownloads(Uint8List bytes, String fileName) async {
    final downloadsDir = await getDownloadsDirectoryPath();
    // Ganti karakter tidak valid untuk nama file
    final cleanFileName = fileName.replaceAll(RegExp(r'[^\w\.-]'), '_');
    final filePath = '${downloadsDir.path}/$cleanFileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
