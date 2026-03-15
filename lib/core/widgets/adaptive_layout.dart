import 'package:flutter/material.dart';
import '../utils/responsive.dart';

/// Renders one of three layouts depending on screen width.
/// Always initialises [R] so sub-layouts can safely call R.* values.
///
/// ```dart
/// AdaptiveLayout(
///   phone: SingleColumnDashboard(),
///   tablet: TwoColumnDashboard(),
///   desktop: SidebarDashboard(),
/// )
/// ```
class AdaptiveLayout extends StatelessWidget {
  const AdaptiveLayout({
    required this.phone,
    this.tablet,
    this.desktop,
    super.key,
  });

  final Widget phone;
  final Widget? tablet;
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    R.init(context);
    if (R.isDesktop && desktop != null) return desktop!;
    if (R.isTablet && tablet != null) return tablet!;
    return phone;
  }
}
