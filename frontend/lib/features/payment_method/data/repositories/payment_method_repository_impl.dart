import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../../core/database/pos_database.dart';
import '../../../../core/utils/database_exception_extension.dart';
import '../../domain/models/payment_method.dart';
import '../../domain/repositories/payment_method_repository.dart';

class PaymentMethodRepositoryImpl implements PaymentMethodRepository {
  final PosDatabase _db;

  PaymentMethodRepositoryImpl(this._db);

  @override
  Future<List<PaymentMethod>> getAllPaymentMethods() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payment_methods',
      orderBy: 'nama ASC',
    );
    return List.generate(maps.length, (i) => PaymentMethod.fromMap(maps[i]));
  }

  @override
  Future<PaymentMethod?> getPaymentMethodById(String id) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payment_methods',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return PaymentMethod.fromMap(maps.first);
  }

  @override
  Future<void> insertPaymentMethod(PaymentMethod paymentMethod) async {
    final db = await _db.database;
    await db.insert(
      'payment_methods',
      paymentMethod.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  @override
  Future<void> updatePaymentMethod(PaymentMethod paymentMethod) async {
    final db = await _db.database;
    await db.update(
      'payment_methods',
      paymentMethod.toMap(),
      where: 'id = ?',
      whereArgs: [paymentMethod.id],
    );
  }

  @override
  Future<void> deletePaymentMethod(String id) async {
    final db = await _db.database;
    // Don't allow deleting 'pm-tunai' because it's required for cashier basic cash transaction!
    if (id == 'pm-tunai') {
      throw const PaymentMethodException('Metode pembayaran Tunai default tidak dapat dihapus.');
    }
    
    try {
      await db.delete(
        'payment_methods',
        where: 'id = ?',
        whereArgs: [id],
      );
    } on DatabaseException catch (e) {
      if (e.isForeignKeyConstraintViolation()) {
        throw const PaymentMethodException('Metode pembayaran tidak bisa dihapus karena telah digunakan dalam transaksi.');
      }
      rethrow;
    }
  }

  @override
  Future<bool> isPaymentMethodNameExists(String name, {String? excludeId}) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> result = await db.query(
      'payment_methods',
      where: excludeId == null ? 'LOWER(nama) = LOWER(?)' : 'LOWER(nama) = LOWER(?) AND id != ?',
      whereArgs: excludeId == null ? [name] : [name, excludeId],
    );
    return result.isNotEmpty;
  }
}

class PaymentMethodException implements Exception {
  final String message;
  const PaymentMethodException(this.message);
  @override
  String toString() => message;
}
