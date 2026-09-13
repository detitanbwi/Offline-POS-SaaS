import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/pos_database.dart';
import '../../../../core/utils/database_exception_extension.dart';
import '../../../../core/utils/soft_delete_helper.dart';
import '../../domain/models/online_platform.dart';
import '../../domain/repositories/online_platform_repository.dart';

class OnlinePlatformRepositoryImpl implements OnlinePlatformRepository {
  final PosDatabase _db;

  OnlinePlatformRepositoryImpl(this._db);

  @override
  Future<List<OnlinePlatformModel>> getAllPlatforms() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'online_platforms',
      where: 'is_deleted = 0',
      orderBy: 'nama ASC',
    );
    return List.generate(maps.length, (i) => OnlinePlatformModel.fromMap(maps[i]));
  }

  @override
  Future<void> addPlatform(String nama) async {
    final db = await _db.database;
    final trimmed = nama.trim();
    final now = DateTime.now().toIso8601String();

    // 1. Cek apakah ada platform aktif dengan nama yang sama
    final existingActive = await db.query(
      'online_platforms',
      where: 'LOWER(nama) = ? AND is_deleted = 0',
      whereArgs: [trimmed.toLowerCase()],
    );
    if (existingActive.isNotEmpty) {
      throw Exception('Platform online dengan nama "$trimmed" sudah terdaftar.');
    }

    // 2. Cek apakah platform dengan nama ini pernah dihapus (soft-deleted)
    final existingDeleted = await db.query(
      'online_platforms',
      where: 'LOWER(nama) = ? AND is_deleted = 1',
      whereArgs: [trimmed.toLowerCase()],
    );
    if (existingDeleted.isNotEmpty) {
      // Pulihkan kembali entri yang sebelumnya dihapus
      final existingId = existingDeleted.first['id'] as String;
      await db.update(
        'online_platforms',
        {
          'nama': trimmed,
          'aktif': 1,
          'is_deleted': 0,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [existingId],
      );
      return;
    }

    // 3. Jika belum pernah terdaftar sama sekali, tambahkan baris baru
    final id = const Uuid().v4();
    await db.insert('online_platforms', {
      'id': id,
      'nama': trimmed,
      'aktif': 1,
      'is_deleted': 0,
      'created_at': now,
      'updated_at': now,
    });
  }

  @override
  Future<void> updatePlatform(String id, String nama, int aktif) async {
    final db = await _db.database;
    final trimmed = nama.trim();
    final now = DateTime.now().toIso8601String();

    // 1. Cek apakah nama ini sudah digunakan oleh platform aktif lain
    final existingActive = await db.query(
      'online_platforms',
      where: 'LOWER(nama) = ? AND id != ? AND is_deleted = 0',
      whereArgs: [trimmed.toLowerCase(), id],
    );
    if (existingActive.isNotEmpty) {
      throw Exception('Platform online dengan nama "$trimmed" sudah terdaftar.');
    }

    // 2. Cek apakah ada platform terhapus yang memakai nama ini selain ID ini
    final existingDeleted = await db.query(
      'online_platforms',
      where: 'LOWER(nama) = ? AND id != ? AND is_deleted = 1',
      whereArgs: [trimmed.toLowerCase(), id],
    );
    if (existingDeleted.isNotEmpty) {
      // Ubah nama entri terhapus agar constraint SQLite UNIQUE tidak konflik
      for (final row in existingDeleted) {
        final delId = row['id'] as String;
        await db.update(
          'online_platforms',
          {
            'nama': '${row['nama']}_deleted_${DateTime.now().millisecondsSinceEpoch}',
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [delId],
        );
      }
    }

    await db.update(
      'online_platforms',
      {
        'nama': trimmed,
        'aktif': aktif,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> deletePlatform(String id) async {
    final db = await _db.database;
    final rows = await db.query('online_platforms', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return;
    final rawNama = rows.first['nama'] as String;
    final tombstoneName = SoftDeleteHelper.makeDeletedName(rawNama);
    final now = DateTime.now().toIso8601String();

    await db.update(
      'online_platforms',
      {
        'nama': tombstoneName,
        'is_deleted': 1,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<OnlinePlatformModel>> getDeletedPlatforms() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'online_platforms',
      where: 'is_deleted = 1',
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) {
      final rawNama = m['nama'] as String;
      final clean = SoftDeleteHelper.cleanDeletedName(rawNama);
      return OnlinePlatformModel.fromMap({...m, 'nama': clean});
    }).toList();
  }

  @override
  Future<void> restorePlatform(String id) async {
    final db = await _db.database;
    final rows = await db.query('online_platforms', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final rawNama = rows.first['nama'] as String;
    String cleanName = SoftDeleteHelper.cleanDeletedName(rawNama);

    final existing = await db.query(
      'online_platforms',
      where: 'LOWER(nama) = ? AND id != ? AND is_deleted = 0',
      whereArgs: [cleanName.toLowerCase()],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      cleanName = '$cleanName (Dipulihkan)';
    }

    final now = DateTime.now().toIso8601String();
    await db.update(
      'online_platforms',
      {
        'nama': cleanName,
        'is_deleted': 0,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> permanentDeletePlatform(String id) async {
    final db = await _db.database;
    final rows = await db.query('online_platforms', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return;
    final rawNama = rows.first['nama'] as String;
    final cleanName = SoftDeleteHelper.cleanDeletedName(rawNama);

    // Check if used in transactions or master_orders
    final txns = await db.query(
      'transactions',
      columns: ['id'],
      where: 'online_platform = ?',
      whereArgs: [cleanName],
      limit: 1,
    );
    if (txns.isNotEmpty) {
      throw const OnlinePlatformException('Platform online tidak dapat dihapus permanen karena masih tercatat dalam transaksi penjualan.');
    }

    final masterOrds = await db.query(
      'master_orders',
      columns: ['id'],
      where: 'platform_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (masterOrds.isNotEmpty) {
      throw const OnlinePlatformException('Platform online tidak dapat dihapus permanen karena masih tercatat dalam sesi pesanan.');
    }

    try {
      await db.delete('platform_sku_prices', where: 'platform_id = ?', whereArgs: [id]);
      await db.delete('online_platforms', where: 'id = ?', whereArgs: [id]);
    } on DatabaseException catch (e) {
      if (e.isForeignKeyConstraintViolation()) {
        throw const OnlinePlatformException('Platform online tidak dapat dihapus permanen karena masih terkait dengan data lain.');
      }
      rethrow;
    }
  }
}

class OnlinePlatformException implements Exception {
  final String message;
  const OnlinePlatformException(this.message);
  @override
  String toString() => message;
}
