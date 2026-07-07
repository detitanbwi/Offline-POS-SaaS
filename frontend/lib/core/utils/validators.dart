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
}
