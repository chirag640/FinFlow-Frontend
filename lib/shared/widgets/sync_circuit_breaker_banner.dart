import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../features/sync/presentation/providers/sync_provider.dart';

class SyncCircuitBreakerBanner extends ConsumerWidget {
  const SyncCircuitBreakerBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    R.init(context);
    final syncState = ref.watch(syncProvider);
    final status = syncState.circuitStatus;

    if (!status.hasOpenCircuit) {
      return const SizedBox.shrink();
    }

    final isFullCircuit = status.isFullOpen;
    final remaining =
        isFullCircuit ? status.fullOpenRemaining : status.pullOpenRemaining;
    final remainingSeconds =
        remaining == null ? 0 : remaining.inSeconds.clamp(1, 600);

    final title = isFullCircuit
        ? 'Sync paused after repeated full-sync failures'
        : 'Cloud pull paused after repeated failures';
    final detail = isFullCircuit
        ? 'Threshold ${status.fullFailureThreshold} failures reached. '
            'Automatic retry in ${remainingSeconds}s.'
        : 'Threshold ${status.pullFailureThreshold} pull failures reached. '
            'Automatic retry in ${remainingSeconds}s.';

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
              Icons.sync_problem_rounded,
              size: R.s(16),
              color: AppColors.warningDark,
            ),
          ),
          SizedBox(width: R.s(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: R.t(12),
                    fontWeight: FontWeight.w700,
                    color: AppColors.warningDark,
                  ),
                ),
                SizedBox(height: R.s(2)),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: R.t(11),
                    fontWeight: FontWeight.w600,
                    color: AppColors.warningDark,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: syncState.isSyncing
                ? null
                : () => ref
                    .read(syncProvider.notifier)
                    .retryNow(pullOnly: !isFullCircuit),
            child: Text(
              'Retry now',
              style: TextStyle(
                fontSize: R.t(12),
                color: AppColors.warningDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
