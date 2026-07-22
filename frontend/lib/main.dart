import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/pin_screen.dart';
import 'features/auth/presentation/screens/onboarding_screen.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/license/presentation/screens/activation_screen.dart';
import 'features/license/presentation/screens/license_lock_screen.dart';
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

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  late final Future<Widget> _initialRouteFuture;

  @override
  void initState() {
    super.initState();
    _initialRouteFuture = _getInitialRoute();
  }

  Future<void> _triggerBackgroundValidation() async {
    final storage = ref.read(secureStorageServiceProvider);
    final lastValidationStr = await storage.getLastValidation();
    if (lastValidationStr != null && lastValidationStr.isNotEmpty) {
      try {
        final lastVal = DateTime.parse(lastValidationStr);
        final diff = DateTime.now().difference(lastVal).inDays;
        if (diff >= 7) {
          final licenseService = ref.read(licenseServiceProvider);
          final result = await licenseService.validateLicenseOnline();
          if (result['success'] == false) {
            ref.read(licenseExpiredProvider.notifier).state = true;
          }
        }
      } catch (e) {
        // Silent catch
      }
    }
  }

  Future<Widget> _getInitialRoute() async {
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(licenseExpiredProvider.notifier).state = true;
      });
      return const LicenseLockScreen();
    }

    // 4. Background validation (triggered asynchronously)
    _triggerBackgroundValidation();

    // 5. Normal PIN routing
    final savedPin = await storage.getLocalPIN();
    if (savedPin != null && savedPin.isNotEmpty) {
      return const PinScreen(isSetup: false);
    } else {
      return const OnboardingScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = ref.watch(licenseExpiredProvider);

    // Determine design size dynamically (mobile vs tablet)
    final mediaQuery = MediaQuery.maybeOf(context);
    double shortestSide = 360.0;
    if (mediaQuery != null) {
      shortestSide = mediaQuery.size.shortestSide;
    } else {
      final view = View.maybeOf(context);
      if (view != null) {
        shortestSide = (view.physicalSize / view.devicePixelRatio).shortestSide;
      }
    }

    final designSize = shortestSide < 600
        ? const Size(360, 800)
        : const Size(768, 1024);

    return ScreenUtilInit(
      designSize: designSize,
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'Offline POS Kasir SaaS',
          builder: (context, widget) {
            if (isExpired) {
              return const LicenseLockScreen();
            }
            return GestureDetector(
              onTap: () {
                FocusManager.instance.primaryFocus?.unfocus();
              },
              child: widget ?? const SizedBox.shrink(),
            );
          },
          theme: AppTheme.lightTheme,
          themeMode: ThemeMode.light,
          debugShowCheckedModeBanner: false,
          home: FutureBuilder<Widget>(
            future: _initialRouteFuture,
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
      },
    );
  }
}