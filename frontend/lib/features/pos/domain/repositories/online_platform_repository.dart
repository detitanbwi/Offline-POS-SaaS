import '../models/online_platform.dart';

abstract class OnlinePlatformRepository {
  Future<List<OnlinePlatformModel>> getAllPlatforms();
  Future<void> addPlatform(String nama);
  Future<void> updatePlatform(String id, String nama, int aktif);
  Future<void> deletePlatform(String id);
}
