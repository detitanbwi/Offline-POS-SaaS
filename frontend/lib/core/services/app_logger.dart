import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel { info, warning, error, debug }

class AppLogger {
  static File? _logFile;
  static const int _maxLogSize = 1 * 1024 * 1024; // 1 MB

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/app_logs.txt');
      
      // Clean up/rotate if too big
      if (await _logFile!.exists()) {
        final size = await _logFile!.length();
        if (size > _maxLogSize) {
          await _logFile!.writeAsString(''); // Reset log
        }
      } else {
        await _logFile!.create(recursive: true);
      }
    } catch (e) {
      debugPrint('Failed to initialize logger: $e');
    }
  }

  static void log(LogLevel level, String message, {Object? error, StackTrace? stackTrace}) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] [${level.name.toUpperCase()}] $message'
        '${error != null ? '\nError: $error' : ''}'
        '${stackTrace != null ? '\nStackTrace: $stackTrace' : ''}\n';

    if (kDebugMode) {
      debugPrint(logMessage.trim());
    }

    _writeToLogFile(logMessage);
  }

  static void info(String message) => log(LogLevel.info, message);
  static void warning(String message) => log(LogLevel.warning, message);
  static void error(String message, {Object? error, StackTrace? stackTrace}) => 
      log(LogLevel.error, message, error: error, stackTrace: stackTrace);
  static void debug(String message) => log(LogLevel.debug, message);

  static Future<void> _writeToLogFile(String message) async {
    if (_logFile == null) return;
    try {
      await _logFile!.writeAsString(message, mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('Failed to write log: $e');
    }
  }

  static Future<String> readLogs() async {
    if (_logFile == null || !await _logFile!.exists()) {
      return 'No logs available.';
    }
    try {
      return await _logFile!.readAsString();
    } catch (e) {
      return 'Error reading logs: $e';
    }
  }

  static Future<void> clearLogs() async {
    if (_logFile == null) return;
    try {
      if (await _logFile!.exists()) {
        await _logFile!.writeAsString('');
      }
    } catch (e) {
      debugPrint('Error clearing logs: $e');
    }
  }
}
