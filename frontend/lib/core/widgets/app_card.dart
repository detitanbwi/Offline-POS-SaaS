import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/app_spacing.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final BorderSide? borderSide;
  final double? width;
  final double? height;

  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.paddingM,
    this.margin,
    this.onTap,
    this.color,
    this.borderSide,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final cardWidget = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: AppRadius.radius16,
        border: borderSide != null ? Border.fromBorderSide(borderSide!) : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000), // Very light shadow level 1
            blurRadius: 4.0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.radius16,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.radius16,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );

    return cardWidget;
  }
}
