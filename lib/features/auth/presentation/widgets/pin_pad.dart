import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_animations.dart';
import '../../../../core/utils/responsive.dart';

class PinPad extends StatelessWidget {
  final void Function(String digit) onDigit;
  final VoidCallback onDelete;

  const PinPad({super.key, required this.onDigit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    const digits = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'del'],
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: R.s(60)),
      child: Column(
        children: digits.map((row) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: R.s(6)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: row.map((key) {
                if (key.isEmpty) {
                  return SizedBox(width: R.s(72), height: R.s(72));
                }

                return _PinKey(
                  label: key,
                  onTap: key == 'del' ? null : () => onDigit(key),
                  onDelete: key == 'del' ? onDelete : null,
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PinKey extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _PinKey({required this.label, this.onTap, this.onDelete});

  @override
  State<_PinKey> createState() => _PinKeyState();
}

class _PinKeyState extends State<_PinKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final isDelete = widget.label == 'del';

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (isDelete) {
          widget.onDelete?.call();
        } else {
          widget.onTap?.call();
        }
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: AppAnimations.fast,
        child: Container(
          width: R.s(72),
          height: R.s(72),
          decoration: BoxDecoration(
            color: _pressed ? AppColors.surfaceVariant : AppColors.background,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Center(
            child: isDelete
                ? Icon(
                    Icons.backspace_outlined,
                    color: AppColors.textSecondary,
                    size: R.s(22),
                  )
                : Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: R.t(24),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
