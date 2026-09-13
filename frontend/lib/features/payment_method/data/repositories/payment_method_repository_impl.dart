import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../../core/database/pos_database.dart';
import '../../../../core/utils/database_exception_extension.dart';
import '../../domain/models/payment_method.dart';
import '../../domain/repositories/payment_method_repository.dart';

import '../../../../core/utils/soft_delete_helper.dart';

class PaymentMethodRepositoryImpl implements PaymentMethodRepository {
  final PosDatabase _db;

  PaymentMethodRepositoryImpl(this._db);

  @override
  Future<List<PaymentMethod>> getAllPaymentMethods() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payment_methods',
      where: 'is_deleted = 0',
      orderBy: 'nama ASC',
    );
    return List.generate(maps.length, (i) => PaymentMethod.fromMap(maps[i]));
  }

  @override
  Future<PaymentMethod?> getPaymentMethodById(String id) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payment_methods',
      where: 'id = ? AND is_deleted = 0',
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
    if (id == 'pm-tunai') {
      throw const PaymentMethodException('Metode pembayaran Tunai default tidak dapat dihapus.');
    }
    
    final pm = await getPaymentMethodById(id);
    if (pm == null) return;
    final tombstoneName = SoftDeleteHelper.makeDeletedName(pm.nama);
    final now = DateTime.now().toIso8601String();

    await db.update(
      'payment_methods',
      {
        'nama': tombstoneName,
        'is_deleted': 1,
        'deleted_at': now,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<PaymentMethod>> getDeletedPaymentMethods() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payment_methods',
      where: 'is_deleted = 1',
      orderBy: 'deleted_at DESC',
    );
    return maps.map((m) {
      final rawNama = m['nama'] as String;
      final clean = SoftDeleteHelper.cleanDeletedName(rawNama);
      return PaymentMethod.fromMap({...m, 'nama': clean});
    }).toList();
  }

  @override
  Future<void> restorePaymentMethod(String id) async {
    final db = await _db.database;
    final rows = await db.query('payment_methods', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final rawNama = rows.first['nama'] as String;
    String cleanName = SoftDeleteHelper.cleanDeletedName(rawNama);

    final exists = await isPaymentMethodNameExists(cleanName, excludeId: id);
    if (exists) {
      cleanName = '$cleanName (Dipulihkan)';
    }

    final now = DateTime.now().toIso8601String();
    await db.update(
      'payment_methods',
      {
        'nama': cleanName,
        'is_deleted': 0,
        'deleted_at': null,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> permanentDeletePaymentMethod(String id) async {
    final db = await _db.database;
    if (id == 'pm-tunai') {
      throw const PaymentMethodException('Metode pembayaran Tunai default tidak dapat dihapus.');
    }

    // Check if used in transactions
    final txns = await db.query(
      'transactions',
      columns: ['id'],
      where: 'payment_method_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (txns.isNotEmpty) {
      throw const PaymentMethodException('Metode pembayaran tidak dapat dihapus permanen karena telah digunakan dalam riwayat transaksi.');
    }

    try {
      await db.delete(
        'payment_methods',
        where: 'id = ?',
        whereArgs: [id],
      );
    } on DatabaseException catch (e) {
      if (e.isForeignKeyConstraintViolation()) {
        throw const PaymentMethodException('Metode pembayaran tidak dapat dihapus permanen karena masih terkait dengan data lain.');
      }
      rethrow;
    }
  }

  @override
  Future<bool> isPaymentMethodNameExists(String name, {String? excludeId}) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> result = await db.query(
      'payment_methods',
      where: excludeId == null ? 'LOWER(nama) = LOWER(?) AND is_deleted = 0' : 'LOWER(nama) = LOWER(?) AND id != ? AND is_deleted = 0',
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
