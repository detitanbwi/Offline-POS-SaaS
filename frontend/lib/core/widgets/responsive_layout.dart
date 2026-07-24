import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? mobileLandscape;
  final Widget? tablet;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.mobileLandscape,
    this.tablet,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 600;

  static bool isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  static bool isKeyboardOpen(BuildContext context) =>
      MediaQuery.of(context).viewInsets.bottom > 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortestSide = MediaQuery.of(context).size.shortestSide;
        final isLandscapeMode = MediaQuery.of(context).orientation == Orientation.landscape;

        if (shortestSide >= 600 && tablet != null) {
          return tablet!;
        }

        if (shortestSide < 600 && isLandscapeMode && mobileLandscape != null) {
          return mobileLandscape!;
        }

        return mobile;
      },
    );
  }
}

