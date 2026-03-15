// Figma: Feedback/SyncStatusBanner
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/design/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../features/sync/presentation/providers/sync_provider.dart';
import '../../features/auth/presentation/providers/cloud_auth_provider.dart';

class SyncStatusBanner extends ConsumerWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    R.init(context);
    final cloud = ref.watch(cloudAuthProvider);
    final sync = ref.watch(syncProvider);

    if (!cloud.isConnected) return const SizedBox.shrink();
    if (!sync.isSyncing && sync.error == null) return const SizedBox.shrink();

    final isError = sync.error != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: isError ? AppColors.errorLight : AppColors.primaryExtraLight,
      padding: EdgeInsets.symmetric(horizontal: R.md, vertical: R.sm),
      child: Row(children: [
        if (sync.isSyncing)
          SizedBox.square(
            dimension: R.s(14),
            child: const CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary),
          )
        else
          Icon(
            isError ? Icons.sync_problem_rounded : Icons.sync_rounded,
            size: R.s(14),
            color: isError ? AppColors.error : AppColors.primary,
          ),
        const Gap(8),
        Expanded(
          child: Text(
            sync.isSyncing
                ? 'Syncing...'
                : isError
                    ? 'Sync failed. Tap to retry.'
                    : '',
            style: TextStyle(
              fontSize: R.t(12),
              color: isError ? AppColors.error : AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isError)
          GestureDetector(
            onTap: () => ref.read(syncProvider.notifier).sync(),
            child: Icon(Icons.refresh_rounded,
                size: R.s(16), color: AppColors.primary),
          ),
      ]),
    );
  }
}
