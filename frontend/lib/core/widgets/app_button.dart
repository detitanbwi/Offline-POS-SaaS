import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
  final bool isDense;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.isLoading = false,
    this.icon,
    this.width,
    this.isDense = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isButtonDisabled = onPressed == null || isLoading;
    final double scale = MediaQuery.textScalerOf(context).scale(1);

    Color getBgColor() {
      if (isLoading) {
        switch (type) {
          case AppButtonType.primary:
            return AppColors.primary.withValues(alpha: 0.7);
          case AppButtonType.secondary:
            return AppColors.secondary.withValues(alpha: 0.7);
          case AppButtonType.destructive:
            return AppColors.error.withValues(alpha: 0.7);
          case AppButtonType.outlined:
            return Colors.transparent;
        }
      }
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
      if (isLoading) {
        switch (type) {
          case AppButtonType.primary:
          case AppButtonType.secondary:
          case AppButtonType.destructive:
            return Colors.white;
          case AppButtonType.outlined:
            return AppColors.primary;
        }
      }
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
            width: (isDense ? 14.r : 18.r) * scale,
            height: (isDense ? 14.r : 18.r) * scale,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(getTextColor()),
            ),
          ),
          SizedBox(width: (isDense ? 4.w : 6.w) * scale),
        ] else if (icon != null) ...[
          Icon(icon, size: (isDense ? 16.r : 20.r) * scale, color: getTextColor()),
          SizedBox(width: (isDense ? 4.w : 6.w) * scale),
        ],
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: isDense
                ? AppTypography.labelMedium.copyWith(
                    color: getTextColor(),
                    fontWeight: FontWeight.bold,
                  )
                : AppTypography.labelLarge.copyWith(
                    color: getTextColor(),
                    fontWeight: FontWeight.bold,
                  ),
          ),
        ),
      ],
    );

    final style = ButtonStyle(
      backgroundColor: WidgetStateProperty.all(getBgColor()),
      foregroundColor: WidgetStateProperty.all(getTextColor()),
      elevation: WidgetStateProperty.all(0),
      padding: WidgetStateProperty.all(
        isDense
            ? EdgeInsets.symmetric(horizontal: (8.w) * scale, vertical: (6.h) * scale)
            : EdgeInsets.symmetric(horizontal: (14.w) * scale, vertical: (10.h) * scale),
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
