import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/pin_screen.dart';
import 'features/license/presentation/screens/activation_screen.dart';
import 'features/license/presentation/screens/license_expired_screen.dart';
import 'core/di/providers.dart';
import 'core/services/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Logger
  await AppLogger.init();
  // Initialize the Indonesian locale formatting
  await initializeDateFormatting('id_ID', null);
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  Future<void> _triggerBackgroundValidation(WidgetRef ref) async {
    final storage = ref.read(secureStorageServiceProvider);
    final lastValidationStr = await storage.getLastValidation();
    if (lastValidationStr != null && lastValidationStr.isNotEmpty) {
      try {
        final lastVal = DateTime.parse(lastValidationStr);
        final diff = DateTime.now().difference(lastVal).inDays;
        if (diff >= 7) {
          final licenseService = ref.read(licenseServiceProvider);
          licenseService.validateLicenseOnline().then((result) {
            if (kDebugMode) {
              debugPrint('Background license validation result: $result');
            }
          });
        }
      } catch (e) {
        // Silent catch
      }
    }
  }

  Future<Widget> _getInitialRoute(WidgetRef ref) async {
    final storage = ref.read(secureStorageServiceProvider);
    final onlineToken = await storage.getOnlineToken();
    final activationToken = await storage.getActivationToken();

    // 1. If not logged in -> LoginScreen
    if (onlineToken == null || onlineToken.isEmpty) {
      return const LoginScreen();
    }

    // 2. If logged in but not activated -> ActivationScreen
    if (activationToken == null || activationToken.isEmpty) {
      return const ActivationScreen();
    }

    // 3. If activated, check offline validity
    final licenseService = ref.read(licenseServiceProvider);
    final isLicenseValid = await licenseService.checkLicenseOffline();
    if (!isLicenseValid) {
      return const LicenseExpiredScreen(reason: 'Lisensi Anda telah kedaluwarsa secara offline.');
    }

    // 4. Background validation (triggered asynchronously)
    _triggerBackgroundValidation(ref);

    // 5. Normal PIN routing
    final savedPin = await storage.getLocalPIN();
    if (savedPin != null && savedPin.isNotEmpty) {
      return const PinScreen(isSetup: false);
    } else {
      return const PinScreen(isSetup: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Offline POS Kasir SaaS',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return GestureDetector(
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: child,
        );
      },
      home: FutureBuilder<Widget>(
        future: _getInitialRoute(ref),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          return snapshot.data ?? const LoginScreen();
        },
      ),
    );
  }
}