import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../providers/pin_recovery_provider.dart';

class NewPinSetupScreen extends ConsumerStatefulWidget {
  final String email;
  const NewPinSetupScreen({super.key, required this.email});

  @override
  ConsumerState<NewPinSetupScreen> createState() => _NewPinSetupScreenState();
}

class _NewPinSetupScreenState extends ConsumerState<NewPinSetupScreen> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  final List<String> _weakPins = [
    '123456', '654321', '000000', '111111', '222222',
    '333333', '444444', '555555', '666666', '777777',
    '888888', '999999', '121212', '101010',
  ];

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _submitNewPin() async {
    final pin = _pinController.text.trim();
    final confirm = _confirmPinController.text.trim();

    // 1. Validasi Panjang PIN
    if (pin.length != 6 || confirm.length != 6) {
      AppSnackbar.showWarning(context, 'PIN baru harus terdiri dari 6 digit angka.');
      return;
    }

    // 2. Validasi Kecocokan Konfirmasi
    if (pin != confirm) {
      AppSnackbar.showError(context, 'Konfirmasi PIN tidak cocok.');
      return;
    }

    // 3. Validasi PIN Default / Mudah Ditebak (Aturan Tambahan)
    if (_weakPins.contains(pin)) {
      AppSnackbar.showError(
        context,
        'PIN terlalu mudah ditebak. Jangan gunakan angka default atau berurutan (misal: 123456/000000).',
      );
      return;
    }

    // 4. Panggil API Reset PIN
    final notifier = ref.read(pinRecoveryProvider.notifier);
    final success = await notifier.resetPin(
      email: widget.email,
      newPin: pin,
      confirmPin: confirm,
    );

    if (!mounted) return;

    if (success) {
      AppSnackbar.showSuccess(
        context,
        'PIN berhasil diatur ulang. Silakan login kembali dengan PIN baru Anda.',
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      final error = ref.read(pinRecoveryProvider).errorMessage;
      AppSnackbar.showError(context, error ?? 'Gagal memperbarui PIN.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pinRecoveryProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Buat PIN Baru'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.r),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 440.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.lock_reset_rounded, size: 56.r, color: AppColors.primary),
                  SizedBox(height: 16.h),
                  Text(
                    'Atur PIN Masuk Baru',
                    textAlign: TextAlign.center,
                    style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Masukkan 6 digit angka untuk PIN baru Anda. Gunakan kombinasi yang aman dan tidak mudah ditebak.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                  SizedBox(height: 28.h),
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'PIN Baru (6 Digit)',
                      prefixIcon: Icon(Icons.lock_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: _confirmPinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Konfirmasi PIN Baru',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (state.errorMessage != null) ...[
                    SizedBox(height: 12.h),
                    Text(
                      state.errorMessage!,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  SizedBox(height: 28.h),
                  AppButton(
                    text: 'Simpan PIN Baru',
                    type: AppButtonType.primary,
                    isLoading: state.isLoading,
                    onPressed: _submitNewPin,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
