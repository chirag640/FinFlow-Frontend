import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_colors.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/responsive.dart';

class LocalCacheRepairBanner extends ConsumerWidget {
  const LocalCacheRepairBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    R.init(context);
    final settings = ref.watch(settingsProvider);

    if (!settings.localCacheRepairNoticeActive) {
      return const SizedBox.shrink();
    }

    final message = settings.localCacheRepairNoticeMessage.isEmpty
        ? 'Local cache was repaired after a storage issue. Review sync conflicts.'
        : settings.localCacheRepairNoticeMessage;

    return Container(
      width: double.infinity,
      color: AppColors.warningLight,
      padding: EdgeInsets.symmetric(horizontal: R.md, vertical: R.s(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: R.s(2)),
            child: Icon(
              Icons.build_circle_outlined,
              size: R.s(16),
              color: AppColors.warningDark,
            ),
          ),
          SizedBox(width: R.s(8)),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: R.t(12),
                fontWeight: FontWeight.w600,
                color: AppColors.warningDark,
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.push(AppRoutes.syncConflicts),
            child: Text(
              'Review',
              style: TextStyle(
                fontSize: R.t(12),
                color: AppColors.warningDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => ref
                .read(settingsProvider.notifier)
                .dismissLocalCacheRepairNotice(),
            child: Text(
              'Dismiss',
              style: TextStyle(
                fontSize: R.t(12),
                color: AppColors.warningDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
