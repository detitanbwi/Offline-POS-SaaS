import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../domain/value_objects/recovery_code.dart';
import '../providers/security_providers.dart';
import '../../../../core/di/providers.dart';

/// Modal component for Feature 2: Self-Recovery (Forgot PIN).
/// Verifies last 6 characters of License Key and Recovery Code,
/// prompts for a new Master PIN, burns old recovery code hash,
/// generates a brand new Recovery Code, and forces PDF export.
class ForgotPinRecoveryModal extends ConsumerStatefulWidget {
  final VoidCallback onRecoverySuccess;

  const ForgotPinRecoveryModal({
    super.key,
    required this.onRecoverySuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onRecoverySuccess,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ForgotPinRecoveryModal(
        onRecoverySuccess: onRecoverySuccess,
      ),
    );
  }

  @override
  ConsumerState<ForgotPinRecoveryModal> createState() => _ForgotPinRecoveryModalState();
}

class _ForgotPinRecoveryModalState extends ConsumerState<ForgotPinRecoveryModal> {
  // Stage 0: Input Verification, Stage 1: New PIN creation, Stage 2: Display Brand New Recovery Code
  int _stage = 0;
  bool _isLoading = false;
  String _errorMessage = '';

  // Stage 0 controllers
  final _licenseLast6Controller = TextEditingController();
  final _recoveryCodeController = TextEditingController();

  // Stage 1 controllers
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  // Stage 2 state
  RecoveryCode? _newRecoveryCode;
  bool _hasExportedPdf = false;
  bool _isAcknowledged = false;

  @override
  void dispose() {
    _licenseLast6Controller.dispose();
    _recoveryCodeController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _verifyRecoveryInput() async {
    final last6 = _licenseLast6Controller.text.trim();
    final code = _recoveryCodeController.text.trim();

    if (last6.isEmpty || code.isEmpty) {
      setState(() => _errorMessage = 'Harap isi 6 Karakter Akhir Lisensi dan Kode Pemulihan!');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final service = ref.read(securityServiceProvider);
      final isValid = await service.verifySelfRecovery(
        lastSixLicenseKey: last6,
        recoveryCode: code,
      );

      if (!mounted) return;
      if (isValid) {
        setState(() {
          _stage = 1;
          _isLoading = false;
          _errorMessage = '';
        });
      } else {
        setState(() {
          _errorMessage = '6 Karakter Akhir Lisensi atau Kode Pemulihan Tidak Sesuai!';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Terjadi kesalahan saat memverifikasi: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitNewPin() async {
    final pin = _newPinController.text.trim();
    final confirm = _confirmPinController.text.trim();

    if (pin.length < 4 || pin.length > 6) {
      setState(() => _errorMessage = 'PIN baru harus terdiri dari 4-6 digit angka.');
      return;
    }
    if (pin != confirm) {
      setState(() => _errorMessage = 'Konfirmasi PIN tidak cocok!');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final service = ref.read(securityServiceProvider);
      // Burns old Recovery Code hash, rotates PIN hash and generates brand new Recovery Code
      final newCode = await service.resetMasterPinAfterRecovery(newMasterPin: pin);

      if (!mounted) return;
      setState(() {
        _newRecoveryCode = newCode;
        _stage = 2;
        _isLoading = false;
      });
      AppSnackbar.showSuccess(context, 'PIN Master dan Kode Pemulihan berhasil direset!');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal mereset PIN: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleExportNewPdf() async {
    if (_newRecoveryCode == null) return;
    try {
      final storage = ref.read(secureStorageServiceProvider);
      final licenseKey = await storage.getLicenseKey() ?? 'XXXX-XXXX-XXXX';
      final storeName = await storage.getStoreName() ?? 'Toko Anda';

      final service = ref.read(securityServiceProvider);
      final pdfBytes = await service.generateRecoveryPdf(
        recoveryCode: _newRecoveryCode!.value,
        licenseKey: licenseKey,
        storeName: storeName,
      );

      await service.exportRecoveryPdfToLocalMachine(
        pdfBytes: pdfBytes,
        fileName: 'Kode_Pemulihan_Baru_POS_${_newRecoveryCode!.normalized.substring(0, 4)}.pdf',
      );

      if (mounted) {
        setState(() => _hasExportedPdf = true);
        AppSnackbar.showSuccess(context, 'PDF Kode Pemulihan Baru berhasil disimpan.');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Gagal export PDF: $e');
      }
    }
  }

  Widget _buildVerificationStage() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.restore_rounded, size: 52.r, color: AppColors.primary),
        SizedBox(height: 12.h),
        Text(
          "Pemulihan Mandiri (Lupa PIN)",
          textAlign: TextAlign.center,
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4.h),
        Text(
          "Masukkan 6 karakter terakhir Lisensi Key dan Kode Pemulihan 12-karakter Anda.",
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        SizedBox(height: 20.h),
        TextField(
          controller: _licenseLast6Controller,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: '6 Karakter Akhir Lisensi Key',
            hintText: 'Contoh: K9X2P1',
            prefixIcon: Icon(Icons.key_rounded),
          ),
        ),
        SizedBox(height: 12.h),
        TextField(
          controller: _recoveryCodeController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Kode Pemulihan (12 Karakter)',
            hintText: 'Contoh: R-9X2P-L44M-Q1',
            prefixIcon: Icon(Icons.security_rounded),
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            SizedBox(width: 12.w),
            ElevatedButton(
              onPressed: _isLoading ? null : _verifyRecoveryInput,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 18.r,
                      height: 18.r,
                      child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Verifikasi'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNewPinStage() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.lock_reset_rounded, size: 52.r, color: AppColors.primary),
        SizedBox(height: 12.h),
        Text(
          "Buat PIN Master Baru",
          textAlign: TextAlign.center,
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4.h),
        Text(
          "Kode pemulihan lama akan dihapus dan kode baru akan dibuat secara otomatis.",
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        SizedBox(height: 20.h),
        TextField(
          controller: _newPinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'PIN Master Baru (4-6 digit)',
            prefixIcon: Icon(Icons.lock_rounded),
          ),
        ),
        SizedBox(height: 12.h),
        TextField(
          controller: _confirmPinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Konfirmasi PIN Master Baru',
            prefixIcon: Icon(Icons.lock_outline_rounded),
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
        AppButton(
          text: 'Reset PIN & Generate Kode Baru',
          type: AppButtonType.primary,
          isLoading: _isLoading,
          onPressed: _submitNewPin,
        ),
      ],
    );
  }

  Widget _buildNewCodeStage() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.verified_rounded, size: 56.r, color: Colors.green),
        SizedBox(height: 12.h),
        Text(
          "Kode Pemulihan Baru",
          textAlign: TextAlign.center,
          style: AppTypography.titleLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          "Kode pemulihan lama Anda telah DIBATALKAN/DIHAPUS.\nSimpan kode baru di bawah ini sebagai penggantinya.",
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        SizedBox(height: 20.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: Text(
            _newRecoveryCode?.value ?? '',
            textAlign: TextAlign.center,
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.w,
            ),
          ),
        ),
        SizedBox(height: 20.h),
        AppButton(
          text: _hasExportedPdf
              ? 'PDF Berhasil Disimpan'
              : 'Export PDF Kode Baru (Wajib)',
          icon: _hasExportedPdf ? Icons.check_circle_rounded : Icons.picture_as_pdf_rounded,
          type: _hasExportedPdf ? AppButtonType.secondary : AppButtonType.primary,
          onPressed: _handleExportNewPdf,
        ),
        SizedBox(height: 16.h),
        InkWell(
          onTap: () => setState(() => _isAcknowledged = !_isAcknowledged),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _isAcknowledged,
                onChanged: (val) => setState(() => _isAcknowledged = val ?? false),
                activeColor: AppColors.primary,
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 10.h),
                  child: Text(
                    "Saya telah menyimpan Kode Pemulihan baru ini dan mengerti bahwa kode lama sudah tidak berlaku.",
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),
        AppButton(
          text: 'Selesai',
          type: AppButtonType.primary,
          onPressed: (_hasExportedPdf && _isAcknowledged)
              ? () {
                  Navigator.pop(context);
                  widget.onRecoverySuccess();
                }
              : null,
        ),
      ],
    );
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
          child: _stage == 0
              ? _buildVerificationStage()
              : _stage == 1
                  ? _buildNewPinStage()
                  : _buildNewCodeStage(),
        ),
      ),
    );
  }
}
