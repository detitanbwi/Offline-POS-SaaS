import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../providers/security_providers.dart';

/// Modal component for changing Master PIN with old PIN verification.
/// Validates the current Master PIN, requires confirmation of the new PIN,
/// and updates the secure credential storage.
class ChangeMasterPinModal extends ConsumerStatefulWidget {
  final VoidCallback? onSuccess;

  const ChangeMasterPinModal({
    super.key,
    this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onSuccess,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ChangeMasterPinModal(
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  ConsumerState<ChangeMasterPinModal> createState() => _ChangeMasterPinModalState();
}

class _ChangeMasterPinModalState extends ConsumerState<ChangeMasterPinModal> {
  final _oldPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _oldPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _submitChangePin() async {
    final oldPin = _oldPinController.text.trim();
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (oldPin.isEmpty) {
      setState(() => _errorMessage = 'Harap masukkan PIN Master saat ini.');
      return;
    }
    if (newPin.length < 4 || newPin.length > 6) {
      setState(() => _errorMessage = 'PIN Master baru harus terdiri dari 4-6 digit angka.');
      return;
    }
    if (newPin != confirmPin) {
      setState(() => _errorMessage = 'Konfirmasi PIN Master baru tidak cocok!');
      return;
    }
    if (newPin == oldPin) {
      setState(() => _errorMessage = 'PIN Master baru tidak boleh sama dengan PIN saat ini!');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final service = ref.read(securityServiceProvider);
      final success = await service.changeMasterPin(
        oldMasterPin: oldPin,
        newMasterPin: newPin,
      );

      if (!mounted) return;

      if (success) {
        Navigator.pop(context);
        AppSnackbar.showSuccess(context, 'PIN Master berhasil diubah!');
        widget.onSuccess?.call();
      } else {
        setState(() {
          _errorMessage = 'PIN Master saat ini salah! Coba lagi.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal mengubah PIN Master: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      backgroundColor: AppColors.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480.w),
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.lock_reset_rounded, size: 52.r, color: AppColors.primary),
              SizedBox(height: 12.h),
              Text(
                "Ubah PIN Master",
                textAlign: TextAlign.center,
                style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4.h),
              Text(
                "Masukkan PIN Master saat ini untuk verifikasi keamanan, lalu buat PIN Master baru.",
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              SizedBox(height: 20.h),
              TextField(
                controller: _oldPinController,
                obscureText: _obscureOld,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'PIN Master Saat Ini',
                  hintText: 'Masukkan PIN Master lama',
                  prefixIcon: const Icon(Icons.key_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureOld ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscureOld = !_obscureOld),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: _newPinController,
                obscureText: _obscureNew,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'PIN Master Baru (4-6 digit)',
                  hintText: 'Masukkan PIN baru',
                  prefixIcon: const Icon(Icons.lock_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: _confirmPinController,
                obscureText: _obscureConfirm,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Konfirmasi PIN Master Baru',
                  hintText: 'Ulangi PIN baru',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              if (_errorMessage.isNotEmpty) ...[
                SizedBox(height: 12.h),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              SizedBox(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: AppButton(
                      text: 'Simpan Perubahan',
                      type: AppButtonType.primary,
                      isLoading: _isLoading,
                      onPressed: _submitChangePin,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
