import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../../core/database/pos_database.dart';
import '../models/online_platform.dart';
import '../domain/repositories/online_platform_repository.dart';

class OnlinePlatformRepositoryImpl implements OnlinePlatformRepository {
  final PosDatabase _db;

  OnlinePlatformRepositoryImpl(this._db);

  @override
  Future<List<OnlinePlatformModel>> getAllPlatforms() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'online_platforms',
      where: 'is_deleted = 0 AND aktif = 1',
      orderBy: 'nama ASC',
    );
    return List.generate(maps.length, (i) => OnlinePlatformModel.fromMap(maps[i]));
  }
}
