import '../models/online_platform.dart';

abstract class OnlinePlatformRepository {
  Future<List<OnlinePlatformModel>> getAllPlatforms();
}
