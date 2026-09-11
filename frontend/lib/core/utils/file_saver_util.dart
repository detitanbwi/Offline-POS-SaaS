import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class FileSaverUtil {
  /// Meminta izin penyimpanan pada Android
  static Future<bool> requestStoragePermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;

    try {
      // 1. Coba izin storage standar (Android 10 kebawah / read-write)
      final status = await Permission.storage.request();
      if (status.isGranted) return true;

      // 2. Coba izin manageExternalStorage jika di Android 11+ (API 30+)
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      }
      final manageStatus = await Permission.manageExternalStorage.request();
      return manageStatus.isGranted;
    } catch (e) {
      debugPrint('[FileSaverUtil] Permission request notice: $e');
      return false;
    }
  }

  /// Mendapatkan direktori 'Downloads' publik sesuai OS (Android, Windows, Mac, Linux)
  static Future<Directory> getDownloadsDirectoryPath() async {
    if (kIsWeb) {
      return await getApplicationDocumentsDirectory();
    }

    if (Platform.isAndroid) {
      final downloadDir = Directory('/storage/emulated/0/Download');
      try {
        if (await downloadDir.exists()) {
          return downloadDir;
        }
      } catch (_) {}

      try {
        final extDownloadDirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
        if (extDownloadDirs != null && extDownloadDirs.isNotEmpty) {
          return extDownloadDirs.first;
        }
      } catch (_) {}

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

  /// Menyimpan Uint8List bytes ke file di folder Downloads dengan multi-tier fallback aman
  static Future<File> saveToDownloads(Uint8List bytes, String fileName) async {
    // 1. Minta izin penyimpanan terlebih dahulu di Android
    await requestStoragePermission();

    final cleanFileName = fileName.replaceAll(RegExp(r'[^\w\.-]'), '_');

    // Tier 1: Coba simpan ke folder Downloads publik utama
    try {
      final downloadsDir = await getDownloadsDirectoryPath();
      final filePath = '${downloadsDir.path}/$cleanFileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (e) {
      debugPrint('[FileSaverUtil] Gagal menyimpan ke folder Downloads publik ($e). Menggunakan fallback direktori aplikasi...');
    }

    // Tier 2: Fallback ke folder eksternal aplikasi (Downloads / files yang selalu diizinkan oleh OS)
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final extDirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
        if (extDirs != null && extDirs.isNotEmpty) {
          final file = File('${extDirs.first.path}/$cleanFileName');
          await file.writeAsBytes(bytes, flush: true);
          return file;
        }

        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final file = File('${extDir.path}/$cleanFileName');
          await file.writeAsBytes(bytes, flush: true);
          return file;
        }
      }
    } catch (e) {
      debugPrint('[FileSaverUtil] Gagal menyimpan ke storage eksternal aplikasi: $e');
    }

    // Tier 3: Fallback ke Application Documents Directory (Pasti berhasil di semua platform)
    final docDir = await getApplicationDocumentsDirectory();
    final file = File('${docDir.path}/$cleanFileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
