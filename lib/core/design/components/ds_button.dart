import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app_colors.dart';
import '../app_radius.dart';
import '../app_animations.dart';
import '../../utils/responsive.dart';

enum DSButtonVariant { primary, secondary, ghost, danger, success }

enum DSButtonSize { sm, md, lg }

class DSButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final DSButtonVariant variant;
  final DSButtonSize size;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final bool isLoading;
  final bool fullWidth;

  const DSButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = DSButtonVariant.primary,
    this.size = DSButtonSize.md,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = true,
  });

  @override
  State<DSButton> createState() => _DSButtonState();
}

class _DSButtonState extends State<DSButton> {
  bool _isPressed = false;

  Color get _bgColor => switch (widget.variant) {
        DSButtonVariant.primary => AppColors.primary,
        DSButtonVariant.secondary => AppColors.primaryExtraLight,
        DSButtonVariant.ghost => Colors.transparent,
        DSButtonVariant.danger => AppColors.error,
        DSButtonVariant.success => AppColors.success,
      };

  Color get _fgColor => switch (widget.variant) {
        DSButtonVariant.primary => Colors.white,
        DSButtonVariant.secondary => AppColors.primary,
        DSButtonVariant.ghost => AppColors.primary,
        DSButtonVariant.danger => Colors.white,
        DSButtonVariant.success => Colors.white,
      };

  double get _paddingV => switch (widget.size) {
        DSButtonSize.sm => R.s(10),
        DSButtonSize.md => R.s(14),
        DSButtonSize.lg => R.s(18),
      };

  double get _fontSize => switch (widget.size) {
        DSButtonSize.sm => R.t(13),
        DSButtonSize.md => R.t(15),
        DSButtonSize.lg => R.t(16),
      };

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final disabled = widget.onPressed == null || widget.isLoading;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: disabled ? null : widget.onPressed,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: AppAnimations.fast,
        curve: AppAnimations.emphasized,
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          width: widget.fullWidth ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            horizontal: R.lg,
            vertical: _paddingV,
          ),
          decoration: BoxDecoration(
            color: disabled
                ? _bgColor.withValues(alpha: 0.5)
                : _isPressed
                    ? Color.lerp(_bgColor, Colors.black, 0.05)
                    : _bgColor,
            borderRadius: AppRadius.lgAll,
            border: widget.variant == DSButtonVariant.ghost
                ? Border.all(color: AppColors.border, width: 1.5)
                : null,
          ),
          child: Row(
            mainAxisSize:
                widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading)
                SizedBox(
                  width: R.s(18),
                  height: R.s(18),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _fgColor,
                  ),
                )
              else ...[
                if (widget.leadingIcon != null) ...[
                  IconTheme(
                    data: IconThemeData(color: _fgColor, size: R.s(18)),
                    child: widget.leadingIcon!,
                  ),
                  SizedBox(width: R.sm),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: _fontSize,
                    fontWeight: FontWeight.w600,
                    color: _fgColor,
                    letterSpacing: 0.1,
                  ),
                ),
                if (widget.trailingIcon != null) ...[
                  SizedBox(width: R.sm),
                  IconTheme(
                    data: IconThemeData(color: _fgColor, size: R.s(18)),
                    child: widget.trailingIcon!,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    ).animate(target: disabled ? 0 : 1).custom(
          duration: AppAnimations.fast,
          builder: (_, value, child) =>
              Opacity(opacity: disabled ? 0.6 : 1.0, child: child),
        );
  }
}
