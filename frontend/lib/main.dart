import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/pin_screen.dart';
import 'features/auth/services/secure_storage_service.dart';
import 'features/license/presentation/screens/activation_screen.dart';
import 'features/license/presentation/screens/license_expired_screen.dart';
import 'features/license/services/license_service.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<void> _triggerBackgroundValidation() async {
    final storage = SecureStorageService();
    final lastValidationStr = await storage.getLastValidation();
    if (lastValidationStr != null && lastValidationStr.isNotEmpty) {
      try {
        final lastVal = DateTime.parse(lastValidationStr);
        final diff = DateTime.now().difference(lastVal).inDays;
        if (diff >= 7) {
          final licenseService = LicenseService();
          licenseService.validateLicenseOnline().then((result) {
            if (kDebugMode) {
              print('Background license validation result: $result');
            }
          });
        }
      } catch (e) {
        // Silent catch
      }
    }
  }

  Future<Widget> _getInitialRoute() async {
    final storage = SecureStorageService();
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
    final licenseService = LicenseService();
    final isLicenseValid = await licenseService.checkLicenseOffline();
    if (!isLicenseValid) {
      return const LicenseExpiredScreen(reason: 'Lisensi Anda telah kedaluwarsa secara offline.');
    }

    // 4. Background validation (triggered asynchronously)
    _triggerBackgroundValidation();

    // 5. Normal PIN routing
    final savedPin = await storage.getLocalPIN();
    if (savedPin != null && savedPin.isNotEmpty) {
      return const PinScreen(isSetup: false);
    } else {
      return const PinScreen(isSetup: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline POS Kasir SaaS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: FutureBuilder<Widget>(
        future: _getInitialRoute(),
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