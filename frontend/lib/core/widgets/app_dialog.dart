import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/app_spacing.dart';
import '../constants/app_typography.dart';
import 'app_button.dart';

class AppDialog extends StatelessWidget {
  final String title;
  final String? message;
  final Widget? content;
  final String confirmText;
  final String cancelText;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;
  final bool isLoading;

  const AppDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.confirmText = 'Simpan',
    this.cancelText = 'Batal',
    required this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
    this.isLoading = false,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    String? message,
    Widget? content,
    String confirmText = 'Simpan',
    String cancelText = 'Batal',
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
    bool isDestructive = false,
    bool isLoading = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: !isLoading,
      builder: (context) => AppDialog(
        title: title,
        message: message,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        onConfirm: onConfirm,
        onCancel: onCancel,
        isDestructive: isDestructive,
        isLoading: isLoading,
      ),
    );
  }

  static Future<void> showConfirmDelete({
    required BuildContext context,
    required String title,
    required String itemName,
    required VoidCallback onDelete,
  }) {
    return showDialog(
      context: context,
      builder: (context) => AppDialog(
        title: title,
        message: 'Apakah Anda yakin ingin menghapus "$itemName"? Tindakan ini tidak dapat dibatalkan.',
        confirmText: 'Hapus',
        isDestructive: true,
        onConfirm: onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.radius24,
      ),
      titlePadding: const EdgeInsets.only(
        left: AppSpacing.l,
        right: AppSpacing.l,
        top: AppSpacing.l,
        bottom: AppSpacing.s,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.s,
      ),
      actionsPadding: const EdgeInsets.all(AppSpacing.l),
      title: Text(
        title,
        style: AppTypography.titleLarge.copyWith(
          color: isDestructive ? AppColors.error : AppColors.textPrimary,
        ),
      ),
      content: content ??
          (message != null
              ? Text(
                  message!,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                )
              : null),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: isLoading ? null : (onCancel ?? () => Navigator.pop(context)),
              child: Text(cancelText, style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary)),
            ),
            const SizedBox(width: 8),
            AppButton(
              text: confirmText,
              isLoading: isLoading,
              type: isDestructive ? AppButtonType.destructive : AppButtonType.primary,
              onPressed: onConfirm,
            ),
          ],
        ),
      ],
    );
  }
}
