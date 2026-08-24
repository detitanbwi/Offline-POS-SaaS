import 'dart:async';
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
  final FutureOr<void> Function() onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;
  final bool isLoading;
  final bool scrollable;

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
    this.scrollable = true,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    String? message,
    Widget? content,
    String confirmText = 'Simpan',
    String cancelText = 'Batal',
    required FutureOr<void> Function() onConfirm,
    VoidCallback? onCancel,
    bool isDestructive = false,
    bool isLoading = false,
    bool scrollable = true,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: !isLoading,
      builder: (context) {
        bool internalIsLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AppDialog(
              title: title,
              message: message,
              content: content,
              confirmText: confirmText,
              cancelText: cancelText,
              scrollable: scrollable,
              onConfirm: () async {
                if (isLoading || internalIsLoading) return;
                
                final result = onConfirm();
                if (result is Future) {
                  setState(() => internalIsLoading = true);
                  try {
                    await result;
                  } finally {
                    if (context.mounted) {
                      setState(() => internalIsLoading = false);
                    }
                  }
                }
              },
              onCancel: onCancel,
              isDestructive: isDestructive,
              isLoading: isLoading || internalIsLoading,
            );
          },
        );
      },
    );
  }

  static Future<void> showConfirmDelete({
    required BuildContext context,
    required String title,
    required String itemName,
    required FutureOr<void> Function() onDelete,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing while deleting
      builder: (context) {
        bool internalIsLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AppDialog(
              title: title,
              message: 'Apakah Anda yakin ingin menghapus "$itemName"? Tindakan ini tidak dapat dibatalkan.',
              confirmText: 'Hapus',
              isDestructive: true,
              isLoading: internalIsLoading,
              onConfirm: () async {
                if (internalIsLoading) return;
                final result = onDelete();
                if (result is Future) {
                  setState(() => internalIsLoading = true);
                  try {
                    await result;
                  } finally {
                    if (context.mounted) {
                      setState(() => internalIsLoading = false);
                    }
                  }
                }
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth < 500 ? 12.0 : 32.0;

    return AlertDialog(
      scrollable: scrollable,
      insetPadding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 24),
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
        TextButton(
          onPressed: isLoading ? null : (onCancel ?? () => Navigator.pop(context)),
          child: Text(
            cancelText, 
            style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        AppButton(
          text: confirmText,
          isLoading: isLoading,
          type: isDestructive ? AppButtonType.destructive : AppButtonType.primary,
          onPressed: () {
            final result = onConfirm();
            // Note: Since AppDialog is stateless, the Future handling for 
            // AppButton's internal state must be passed down, but AppButton takes 
            // VoidCallback. However, the isLoading is passed from the StatefulBuilder
            // above, so we can just fire it. The StatefulBuilder will rebuild 
            // and set isLoading to true.
            // But wait, AppButton's onPressed is VoidCallback. 
          },
        ),
      ],
    );
  }
}
