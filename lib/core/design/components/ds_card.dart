import 'package:flutter/material.dart';

import '../../utils/responsive.dart';
import '../app_animations.dart';
import '../app_colors.dart';
import '../app_radius.dart';
import '../app_shadows.dart';

class DSCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool hasBorder;
  final bool hasShadow;
  final BorderRadius? borderRadius;

  const DSCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.hasBorder = true,
    this.hasShadow = false,
    this.borderRadius,
  });

  @override
  State<DSCard> createState() => _DSCardState();
}

class _DSCardState extends State<DSCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final radius = widget.borderRadius ?? AppRadius.lgAll;
    final colors = Theme.of(context).colorScheme;
    final bg = widget.color ?? colors.surface;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          curve: AppAnimations.emphasizedOut,
          transform: Matrix4.diagonal3Values(
              _isPressed ? 0.985 : 1.0, _isPressed ? 0.985 : 1.0, 1.0),
          decoration: BoxDecoration(
            color: _isPressed
                ? Color.lerp(bg, Colors.black, 0.02)
                : _isHovered
                    ? Color.lerp(bg, AppColors.primary, 0.02)
                    : bg,
            borderRadius: radius,
            border: widget.hasBorder
                ? Border.all(
                    color: _isPressed || _isHovered
                        ? colors.outline
                        : colors.outlineVariant,
                    width: 1,
                  )
                : null,
            boxShadow: widget.hasShadow
                ? (_isHovered ? AppShadows.md : AppShadows.sm)
                : null,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Padding(
              padding: widget.padding ?? EdgeInsets.all(R.md),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
