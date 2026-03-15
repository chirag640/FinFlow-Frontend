// Figma: Feedback/ConnectivityBanner
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/design/app_colors.dart';
import '../../core/providers/connectivity_provider.dart';
import '../../core/utils/responsive.dart';

class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    R.init(context);
    final isOnline = ref.watch(connectivityProvider);

    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 350),
      crossFadeState:
          isOnline ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      firstChild: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: R.s(7)),
        color: AppColors.error,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: R.s(13), color: Colors.white),
            SizedBox(width: R.s(6)),
            Text(
              'No internet connection',
              style: TextStyle(
                fontSize: R.t(12),
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 250.ms),
      secondChild: const SizedBox.shrink(),
    );
  }
}
