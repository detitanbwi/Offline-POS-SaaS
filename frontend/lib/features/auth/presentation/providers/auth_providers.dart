import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/auth_user.dart';

/// Provider to store the currently logged in user (Pemilik or Kasir)
final authSessionProvider = StateProvider<AuthUser?>((ref) => null);

/// Provider to store whether the license validation failed (blocks the screen)
final licenseExpiredProvider = StateProvider<bool>((ref) => false);
