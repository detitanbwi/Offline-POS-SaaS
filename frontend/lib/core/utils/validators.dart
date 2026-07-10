import 'dart:io';

class Validators {
  static String? required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName tidak boleh kosong';
    }
    return null;
  }

  static String? number(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName tidak boleh kosong';
    }
    final numVal = num.tryParse(value);
    if (numVal == null) {
      return '$fieldName harus berupa angka';
    }
    if (numVal < 0) {
      return '$fieldName tidak boleh negatif';
    }
    return null;
  }

  static String? integer(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName tidak boleh kosong';
    }
    final intVal = int.tryParse(value);
    if (intVal == null) {
      return '$fieldName harus berupa angka bulat';
    }
    if (intVal < 0) {
      return '$fieldName tidak boleh negatif';
    }
    return null;
  }

  static bool isValidWebUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    if (!url.startsWith('http://') && !url.startsWith('https://')) return false;
    try {
      final uri = Uri.parse(url);
      return uri.hasAbsolutePath && uri.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static bool isValidLocalFile(String? path) {
    if (path == null || path.isEmpty) return false;
    try {
      final file = File(path);
      return file.existsSync();
    } catch (_) {
      return false;
    }
  }
}

