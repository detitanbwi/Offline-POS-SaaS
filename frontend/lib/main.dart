import 'dart:async';
import 'package:flutter/foundation.dart';
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
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/font_size_provider.dart';
import 'core/services/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Logger
  await AppLogger.init();
  // Initialize the Indonesian locale formatting
  await initializeDateFormatting('id_ID', null);
  
  final prefs = await SharedPreferences.getInstance();
  
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class _MyAppState extends ConsumerState<MyApp> {
  late final Future<Widget> _initialRouteFuture;
  Timer? _periodicValidationTimer;

  @override
  void initState() {
    super.initState();
    _initialRouteFuture = _getInitialRoute();
    
    // Start a strict periodic background validation every 7 days (Production)
    _periodicValidationTimer = Timer.periodic(const Duration(days: 7), (_) {
      _triggerBackgroundValidation();
    });

    // // Start a strict periodic background validation every 3 minutes (Testing)
    // _periodicValidationTimer = Timer.periodic(const Duration(minutes: 3), (_) {
    //   _triggerBackgroundValidation();
    // });
  }

  @override
  void dispose() {
    _periodicValidationTimer?.cancel();
    super.dispose();
  }

  Future<void> _triggerBackgroundValidation() async {
    final storage = ref.read(secureStorageServiceProvider);
    
    // Check if 7 days have passed since the last online validation
    final lastValidationStr = await storage.getLastValidation();
    if (lastValidationStr != null && lastValidationStr.isNotEmpty) {
      try {
        final lastValidation = DateTime.parse(lastValidationStr);
        if (DateTime.now().difference(lastValidation).inDays < 7) {
          return; // Skip validation if within the 7-day window
        }
      } catch (_) {
        // Continue if parsing fails
      }
    }

    final licenseService = ref.read(licenseServiceProvider);
    
    // Gunakan timeout 10 detik agar tidak terlalu sensitif terhadap koneksi lemot
    final result = await licenseService.validateLicenseOnline(customTimeout: 10);
    if (result['success'] == false) {
      if (result['is_offline'] == true) {
        // Jika offline, fallback ke cek lisensi lokal (offline)
        final isLicenseValid = await licenseService.checkLicenseOffline();
        if (!isLicenseValid) {
          ref.read(licenseExpiredProvider.notifier).state = true;
        }
      } else {
        // Jika gagal karena ditolak oleh server
        final isAuthError = result['message'] == 'Data aktivasi tidak lengkap' || 
                            result['message'] == 'Perangkat tidak terdaftar' ||
                            result['message'] == 'Unauthenticated.' ||
                            result['message'] == 'Unauthenticated';
        if (isAuthError) {
          final storage = ref.read(secureStorageServiceProvider);
          await storage.clearAll();
          
          if (appNavigatorKey.currentContext != null) {
            Navigator.pushAndRemoveUntil(
              appNavigatorKey.currentContext!,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        } else {
          ref.read(licenseExpiredProvider.notifier).state = true;
        }
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

    // 5. Pre-warm POS Database agar siap saat PinScreen memuat daftar akun
    try {
      final db = ref.read(posDatabaseProvider);
      await db.database;
    } catch (_) {
      // Database init gagal saat pre-warm, PinScreen akan retry sendiri
    }

    // 6. Normal PIN routing
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
    final fontSizeScale = ref.watch(fontSizeProvider).scale;

    // Determine design size dynamically (mobile vs tablet, portrait vs landscape)
    final mediaQuery = MediaQuery.maybeOf(context);
    double shortestSide = 360.0;
    bool isLandscape = false;
    if (mediaQuery != null) {
      shortestSide = mediaQuery.size.shortestSide;
      isLandscape = mediaQuery.orientation == Orientation.landscape;
    } else {
      final view = View.maybeOf(context);
      if (view != null) {
        final size = view.physicalSize / view.devicePixelRatio;
        shortestSide = size.shortestSide;
        isLandscape = size.width > size.height;
      }
    }

    final Size designSize;
    if (shortestSide < 600) {
      designSize = isLandscape ? const Size(800, 360) : const Size(360, 800);
    } else {
      designSize = isLandscape ? const Size(1024, 768) : const Size(768, 1024);
    }

    return ScreenUtilInit(
      designSize: designSize,
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'Offline POS Kasir SaaS',
          builder: (context, widget) {
            Widget child = widget ?? const SizedBox.shrink();
            if (isExpired) {
              child = const LicenseLockScreen();
            }
            // Removed global GestureDetector for unfocus to prevent tap swallowing
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(fontSizeScale),
              ),
              child: child,
            );
          },
          theme: AppTheme.getLightTheme(fontSizeScale),
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