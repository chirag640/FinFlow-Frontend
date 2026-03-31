import 'package:flutter/material.dart';

import '../../utils/responsive.dart';

class DSTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final bool obscureText;
  final int? maxLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const DSTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontSize: R.t(13),
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(height: R.s(6)),
        ],
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          maxLength: maxLength,
          onChanged: onChanged,
          onTap: onTap,
          readOnly: readOnly,
          focusNode: focusNode,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          style: TextStyle(
            fontSize: R.t(15),
            fontWeight: FontWeight.w500,
            color: colors.onSurface,
            height: 1.4,
          ),
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            prefixIcon: prefixIcon != null
                ? Padding(
                    padding: EdgeInsets.symmetric(horizontal: R.sm + R.xs),
                    child: IconTheme(
                      data: IconThemeData(
                        color: colors.onSurfaceVariant,
                        size: R.s(20),
                      ),
                      child: prefixIcon!,
                    ),
                  )
                : null,
            suffixIcon: suffixIcon != null
                ? Padding(
                    padding: EdgeInsets.symmetric(horizontal: R.sm + R.xs),
                    child: IconTheme(
                      data: IconThemeData(
                        color: colors.onSurfaceVariant,
                        size: R.s(20),
                      ),
                      child: suffixIcon!,
                    ),
                  )
                : null,
            prefixIconConstraints: BoxConstraints(
              minWidth: R.s(44),
              minHeight: R.s(44),
            ),
            suffixIconConstraints: BoxConstraints(
              minWidth: R.s(44),
              minHeight: R.s(44),
            ),
          ),
        ),
      ],
    );
  }
}
