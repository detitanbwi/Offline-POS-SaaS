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

/// Modal component for Feature 1: Initialization (First Setup).
/// Displays generated Recovery Code, enforces mandatory PDF auto-export,
/// and requires user acknowledgment before completing Master PIN creation.
class MasterPinSetupModal extends ConsumerStatefulWidget {
  final String masterPin;
  final VoidCallback onCompleted;

  const MasterPinSetupModal({
    super.key,
    required this.masterPin,
    required this.onCompleted,
  });

  static Future<void> show(
    BuildContext context, {
    required String masterPin,
    required VoidCallback onCompleted,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MasterPinSetupModal(
        masterPin: masterPin,
        onCompleted: onCompleted,
      ),
    );
  }

  @override
  ConsumerState<MasterPinSetupModal> createState() => _MasterPinSetupModalState();
}

class _MasterPinSetupModalState extends ConsumerState<MasterPinSetupModal> {
  bool _isLoading = true;
  RecoveryCode? _recoveryCode;
  bool _hasExportedPdf = false;
  bool _isAcknowledged = false;

  @override
  void initState() {
    super.initState();
    _initializeSecurity();
  }

  Future<void> _initializeSecurity() async {
    try {
      final storage = ref.read(secureStorageServiceProvider);
      final licenseKey = await storage.getLicenseKey() ?? 'XXXX-XXXX-XXXX';
      
      final service = ref.read(securityServiceProvider);
      final recoveryCode = await service.initializeMasterSecurity(
        masterPin: widget.masterPin,
        licenseKey: licenseKey,
      );

      if (mounted) {
        setState(() {
          _recoveryCode = recoveryCode;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackbar.showError(context, 'Gagal menginisiasi modul keamanan: $e');
      }
    }
  }

  Future<void> _handleExportPdf() async {
    if (_recoveryCode == null) return;
    try {
      final storage = ref.read(secureStorageServiceProvider);
      final licenseKey = await storage.getLicenseKey() ?? 'XXXX-XXXX-XXXX';
      final storeName = await storage.getStoreName() ?? 'Toko Anda';

      final service = ref.read(securityServiceProvider);
      final pdfBytes = await service.generateRecoveryPdf(
        recoveryCode: _recoveryCode!.value,
        licenseKey: licenseKey,
        storeName: storeName,
      );

      await service.exportRecoveryPdfToLocalMachine(
        pdfBytes: pdfBytes,
        fileName: 'Kode_Pemulihan_POS_${_recoveryCode!.normalized.substring(0, 4)}.pdf',
      );

      if (mounted) {
        setState(() => _hasExportedPdf = true);
        AppSnackbar.showSuccess(context, 'PDF Kode Pemulihan berhasil diexport dan disimpan.');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Gagal export PDF: $e');
      }
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
          child: _isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.shield_rounded,
                      size: 56.r,
                      color: AppColors.primary,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      "Kode Pemulihan Master PIN",
                      textAlign: TextAlign.center,
                      style: AppTypography.titleLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      "Simpan kode pemulihan 12-karakter ini dengan aman.\nKode ini WAJIB untuk mereset PIN Master jika Anda lupa.",
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
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
                        _recoveryCode?.value ?? '',
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
                          ? 'PDF Berhasil Diunduh / Dicetak'
                          : 'Export PDF Kode Pemulihan (Wajib)',
                      icon: _hasExportedPdf ? Icons.check_circle_rounded : Icons.picture_as_pdf_rounded,
                      type: _hasExportedPdf ? AppButtonType.secondary : AppButtonType.primary,
                      onPressed: _handleExportPdf,
                    ),
                    SizedBox(height: 16.h),
                    InkWell(
                      onTap: () {
                        setState(() => _isAcknowledged = !_isAcknowledged);
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _isAcknowledged,
                            onChanged: (val) {
                              setState(() => _isAcknowledged = val ?? false);
                            },
                            activeColor: AppColors.primary,
                          ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(top: 10.h),
                              child: Text(
                                "Saya telah mengunduh & menyimpan Kode Pemulihan di atas dengan aman serta mengerti bahwa sistem tidak dapat dipulihkan tanpa kode ini.",
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
                      text: 'Selesai & Masuk ke Sistem',
                      type: AppButtonType.primary,
                      onPressed: (_hasExportedPdf && _isAcknowledged)
                          ? () {
                              Navigator.pop(context);
                              widget.onCompleted();
                            }
                          : null,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
