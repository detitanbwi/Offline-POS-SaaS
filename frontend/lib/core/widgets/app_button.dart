import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/app_typography.dart';

enum AppButtonType { primary, secondary, outlined, destructive }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final bool isLoading;
  final IconData? icon;
  final double? width;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.isLoading = false,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final bool isButtonDisabled = onPressed == null || isLoading;

    Color getBgColor() {
      if (isButtonDisabled) return AppColors.disabled.withValues(alpha: 0.3);

      switch (type) {
        case AppButtonType.primary:
          return AppColors.primary;
        case AppButtonType.secondary:
          return AppColors.secondary;
        case AppButtonType.destructive:
          return AppColors.error;
        case AppButtonType.outlined:
          return Colors.transparent;
      }
    }

    Color getTextColor() {
      if (isButtonDisabled) return AppColors.disabled;
      switch (type) {
        case AppButtonType.primary:
        case AppButtonType.secondary:
        case AppButtonType.destructive:
          return Colors.white;
        case AppButtonType.outlined:
          return AppColors.primary;
      }
    }

    BorderSide? getBorderSide() {
      if (type == AppButtonType.outlined) {
        return BorderSide(
          color: isButtonDisabled ? AppColors.disabled : AppColors.primary,
          width: 1.5,
        );
      }
      return null;
    }

    final buttonContent = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(getTextColor()),
            ),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: 20, color: getTextColor()),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: AppTypography.labelLarge.copyWith(
            color: getTextColor(),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );

    final style = ButtonStyle(
      backgroundColor: WidgetStateProperty.all(getBgColor()),
      foregroundColor: WidgetStateProperty.all(getTextColor()),
      elevation: WidgetStateProperty.all(0),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
      shape: WidgetStateProperty.all(
        const RoundedRectangleBorder(
          borderRadius: AppRadius.radiusMax,
        ),
      ),
      side: getBorderSide() != null ? WidgetStateProperty.all(getBorderSide()) : null,
    );

    Widget button;
    if (type == AppButtonType.outlined) {
      button = OutlinedButton(
        onPressed: isButtonDisabled ? null : onPressed,
        style: style,
        child: buttonContent,
      );
    } else {
      button = ElevatedButton(
        onPressed: isButtonDisabled ? null : onPressed,
        style: style,
        child: buttonContent,
      );
    }

    if (width != null) {
      return SizedBox(width: width, child: button);
    }
    return button;
  }
}
