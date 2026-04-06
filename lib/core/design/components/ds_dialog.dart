import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_radius.dart';

/// Design System dialog component with consistent theming.
///
/// Provides pre-styled dialogs that match the FinFlow design system.
/// Use [DSDialog.show] for custom content or [DSConfirmDialog.show] for
/// confirmation prompts with standardized actions.
class DSDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? actionsPadding;
  final MainAxisAlignment actionsAlignment;

  const DSDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.contentPadding,
    this.actionsPadding,
    this.actionsAlignment = MainAxisAlignment.end,
  });

  /// Shows a themed dialog with custom content.
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      title: title,
      content: content,
      contentPadding: contentPadding ??
          const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0),
      actionsPadding: actionsPadding ??
          const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 16.0),
      actionsAlignment: actionsAlignment,
      actions: actions,
    );
  }
}

/// Pre-built confirmation dialog with cancel/confirm actions.
///
/// Example:
/// ```dart
/// final confirmed = await DSConfirmDialog.show(
///   context: context,
///   title: 'Delete expense?',
///   message: 'This action cannot be undone.',
///   confirmLabel: 'Delete',
///   isDestructive: true,
/// );
/// if (confirmed == true) { /* do delete */ }
/// ```
class DSConfirmDialog extends StatelessWidget {
  final String title;
  final String? message;
  final Widget? content;
  final String cancelLabel;
  final String confirmLabel;
  final bool isDestructive;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;

  const DSConfirmDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.cancelLabel = 'Cancel',
    this.confirmLabel = 'Confirm',
    this.isDestructive = false,
    this.onCancel,
    this.onConfirm,
  });

  /// Shows a confirmation dialog and returns true if confirmed, false if cancelled.
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    String? message,
    Widget? content,
    String cancelLabel = 'Cancel',
    String confirmLabel = 'Confirm',
    bool isDestructive = false,
    bool barrierDismissible = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => DSConfirmDialog(
        title: title,
        message: message,
        content: content,
        cancelLabel: cancelLabel,
        confirmLabel: confirmLabel,
        isDestructive: isDestructive,
        onCancel: () => Navigator.pop(ctx, false),
        onConfirm: () => Navigator.pop(ctx, true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmColor = isDestructive ? AppColors.error : colorScheme.primary;

    return DSDialog(
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      content: content ??
          (message != null
              ? Text(
                  message!,
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              : null),
      actions: [
        TextButton(
          onPressed: onCancel ?? () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: confirmColor),
          onPressed: onConfirm ?? () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

/// Dialog with a text input field.
///
/// Example:
/// ```dart
/// final value = await DSInputDialog.show(
///   context: context,
///   title: 'Rename',
///   hintText: 'Enter new name',
///   initialValue: 'Current Name',
/// );
/// ```
class DSInputDialog extends StatefulWidget {
  final String title;
  final String? message;
  final String? hintText;
  final String? labelText;
  final String? initialValue;
  final String cancelLabel;
  final String confirmLabel;
  final TextInputType keyboardType;
  final int? maxLength;
  final String? Function(String?)? validator;

  const DSInputDialog({
    super.key,
    required this.title,
    this.message,
    this.hintText,
    this.labelText,
    this.initialValue,
    this.cancelLabel = 'Cancel',
    this.confirmLabel = 'Save',
    this.keyboardType = TextInputType.text,
    this.maxLength,
    this.validator,
  });

  /// Shows an input dialog and returns the entered value, or null if cancelled.
  static Future<String?> show({
    required BuildContext context,
    required String title,
    String? message,
    String? hintText,
    String? labelText,
    String? initialValue,
    String cancelLabel = 'Cancel',
    String confirmLabel = 'Save',
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => DSInputDialog(
        title: title,
        message: message,
        hintText: hintText,
        labelText: labelText,
        initialValue: initialValue,
        cancelLabel: cancelLabel,
        confirmLabel: confirmLabel,
        keyboardType: keyboardType,
        maxLength: maxLength,
        validator: validator,
      ),
    );
  }

  @override
  State<DSInputDialog> createState() => _DSInputDialogState();
}

class _DSInputDialogState extends State<DSInputDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.pop(context, _controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DSDialog(
      title: Text(
        widget.title,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message != null) ...[
              Text(
                widget.message!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _controller,
              keyboardType: widget.keyboardType,
              maxLength: widget.maxLength,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.hintText,
                labelText: widget.labelText,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
              ),
              validator: widget.validator,
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
