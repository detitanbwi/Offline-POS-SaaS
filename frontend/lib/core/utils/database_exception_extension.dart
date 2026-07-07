import 'package:sqflite/sqflite.dart';

extension DatabaseExceptionExtension on DatabaseException {
  bool isForeignKeyConstraintViolation() {
    // SQLite foreign key constraint failure
    return toString().contains('FOREIGN KEY constraint failed') || getResultCode() == 787;
  }
}
