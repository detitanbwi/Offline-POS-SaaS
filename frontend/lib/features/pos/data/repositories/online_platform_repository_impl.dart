import 'package:uuid/uuid.dart';
import '../../../../core/database/pos_database.dart';
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
    final existing = await db.query(
      'online_platforms',
      where: 'LOWER(nama) = ? AND is_deleted = 0',
      whereArgs: [trimmed.toLowerCase()],
    );
    if (existing.isNotEmpty) {
      throw Exception('Platform online dengan nama "$trimmed" sudah terdaftar.');
    }

    final id = const Uuid().v4();
    final now = DateTime.now().toIso8601String();
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
    final existing = await db.query(
      'online_platforms',
      where: 'LOWER(nama) = ? AND id != ? AND is_deleted = 0',
      whereArgs: [trimmed.toLowerCase(), id],
    );
    if (existing.isNotEmpty) {
      throw Exception('Platform online dengan nama "$trimmed" sudah terdaftar.');
    }

    final now = DateTime.now().toIso8601String();
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
    final now = DateTime.now().toIso8601String();
    await db.update(
      'online_platforms',
      {
        'is_deleted': 1,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
