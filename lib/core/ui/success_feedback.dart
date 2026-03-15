import 'package:flutter/material.dart';
import '../design/app_colors.dart';

void showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            AppColors.success, // You may need to define this in app_colors.dart
      ),
    );
}
