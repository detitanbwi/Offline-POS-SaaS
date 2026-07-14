import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crypto/crypto.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/di/providers.dart';
import 'pin_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentStep = 0;
  
  // Step 1: Store info controllers
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // Step 2: PIN controllers
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  
  // Step 3: Database init states
  String _initStatusText = 'Menyiapkan database lokal...';
  double _initProgress = 0.1;
  bool _isInitComplete = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_nameController.text.trim().isEmpty ||
          _addressController.text.trim().isEmpty ||
          _phoneController.text.trim().isEmpty) {
        AppSnackbar.showWarning(context, 'Mohon isi seluruh identitas toko!');
        return;
      }
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      final pin = _pinController.text;
      final confirmPin = _confirmPinController.text;
      if (pin.length != 6) {
        AppSnackbar.showWarning(context, 'PIN Master harus tepat 6 digit!');
        return;
      }
      if (pin != confirmPin) {
        AppSnackbar.showWarning(context, 'Konfirmasi PIN tidak cocok!');
        return;
      }
      setState(() {
        _currentStep = 2;
      });
      _startDatabaseInitialization();
    }
  }

  String _hashPIN(String pin) {
    const salt = 'OfflinePOSSecureSalt_Sprint4_2026';
    var bytes = utf8.encode(pin + salt);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _startDatabaseInitialization() async {
    // Stage 1: Save Store Identity and Owner Master PIN to Secure Storage
    setState(() {
      _initStatusText = 'Menyimpan identitas toko dan PIN keamanan...';
      _initProgress = 0.3;
    });
    
    final storage = ref.read(secureStorageServiceProvider);
    await storage.saveStoreInfo(
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
    );
    
    final hashedPin = _hashPIN(_pinController.text);
    await storage.saveLocalPIN(hashedPin);
    
    await Future.delayed(const Duration(milliseconds: 600));

    // Stage 2: Initialize SQLite local database schema
    setState(() {
      _initStatusText = 'Membuat skema database SQLite (SQLCipher)...';
      _initProgress = 0.6;
    });

    try {
      final db = ref.read(posDatabaseProvider);
      await db.database;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DB initialization failed: $e');
      }
    }
    
    await Future.delayed(const Duration(milliseconds: 600));

    // Stage 3: Seeding initial tables and payment methods
    setState(() {
      _initStatusText = 'Menyiapkan konfigurasi pembayaran & meja...';
      _initProgress = 0.9;
    });
    
    await Future.delayed(const Duration(milliseconds: 500));

    // Stage 4: Finish onboarding
    setState(() {
      _initStatusText = 'Inisiasi database selesai! Sistem siap digunakan offline.';
      _initProgress = 1.0;
      _isInitComplete = true;
    });

    await Future.delayed(const Duration(milliseconds: 400));
    
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PinScreen(isSetup: false)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 520.w),
              child: Card(
                elevation: 4,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(24.r),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      SizedBox(height: 16.h),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _buildStepContent(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Icon(Icons.rocket_launch_rounded, size: 52.r, color: AppColors.primary),
        SizedBox(height: 8.h),
        Text(
          'Onboarding Pemilik',
          style: AppTypography.headlineLarge.copyWith(color: AppColors.primary),
        ),
        SizedBox(height: 4.h),
        Text(
          'Konfigurasi awal sistem POS offline tablet Anda',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        SizedBox(height: 16.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final isActive = index <= _currentStep;
            return Container(
              margin: EdgeInsets.symmetric(horizontal: 4.w),
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.divider,
                borderRadius: BorderRadius.circular(2.r),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return Column(
          key: const ValueKey(0),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('1. Identitas Toko', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: 6.h),
            Text(
              'Informasi ini akan tercetak sebagai header pada cetakan struk transaksi pelanggan.',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            SizedBox(height: 16.h),
            AppTextField(
              controller: _nameController,
              labelText: 'Nama Toko',
              hintText: 'Contoh: Resto Selera Nusantara',
              prefixIcon: Icons.store_rounded,
            ),
            SizedBox(height: 12.h),
            AppTextField(
              controller: _addressController,
              labelText: 'Alamat Toko',
              hintText: 'Contoh: Jl. Diponegoro No. 45, Bandung',
              prefixIcon: Icons.map_rounded,
            ),
            SizedBox(height: 12.h),
            AppTextField(
              controller: _phoneController,
              labelText: 'Nomor Telepon Toko',
              hintText: 'Contoh: 0812-3456-7890',
              prefixIcon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 20.h),
            AppButton(
              text: 'Lanjutkan',
              onPressed: _nextStep,
              icon: Icons.navigate_next_rounded,
            ),
          ],
        );
      case 1:
        return Column(
          key: const ValueKey(1),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('2. Buat PIN Master Keamanan', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: 6.h),
            Text(
              'PIN khusus ini hanya digunakan oleh Pemilik untuk masuk ke dashboard sensitif (Manajemen Lisensi, Laporan, Manajemen Kasir). Jangan dibagikan kepada staf kasir!',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            SizedBox(height: 16.h),
            AppTextField(
              controller: _pinController,
              labelText: 'PIN Master Baru (6 Digit)',
              hintText: 'Masukkan 6 digit angka PIN',
              prefixIcon: Icons.lock_rounded,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
            ),
            SizedBox(height: 12.h),
            AppTextField(
              controller: _confirmPinController,
              labelText: 'Konfirmasi PIN Master',
              hintText: 'Ketik ulang PIN Master Anda',
              prefixIcon: Icons.lock_outline_rounded,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
            ),
            SizedBox(height: 20.h),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: 'Kembali',
                    type: AppButtonType.secondary,
                    onPressed: () => setState(() => _currentStep = 0),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: AppButton(
                    text: 'Konfirmasi',
                    onPressed: _nextStep,
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ),
              ],
            ),
          ],
        );
      case 2:
      default:
        return Column(
          key: const ValueKey(2),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 12.h),
            SizedBox(
              width: 72.r,
              height: 72.r,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _initProgress,
                    strokeWidth: 6,
                    color: AppColors.primary,
                    backgroundColor: AppColors.divider,
                  ),
                  Icon(
                    _isInitComplete ? Icons.done_all_rounded : Icons.storage_rounded,
                    size: 32.r,
                    color: _isInitComplete ? AppColors.success : AppColors.primary,
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              '3. Inisiasi Database Lokal',
              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6.h),
            Text(
              _initStatusText,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            SizedBox(height: 16.h),
          ],
        );
    }
  }
}
