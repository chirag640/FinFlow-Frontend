import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/components/ds_empty_state.dart';
import '../../../../core/design/components/ds_skeleton.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/ui/error_feedback.dart';
import '../../../../core/utils/responsive.dart';
import '../providers/group_provider.dart';
import '../widgets/group_card.dart';

class GroupsPage extends ConsumerWidget {
  const GroupsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    R.init(context);
    listenForProviderError<GroupState>(
      ref: ref,
      context: context,
      provider: groupProvider,
      errorSelector: (s) => s.error,
    );
    final state = ref.watch(groupProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          'Groups',
          style: TextStyle(
            fontSize: R.t(20),
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (state.groups.isNotEmpty)
            TextButton.icon(
              onPressed: () => context.push(AppRoutes.createGroup),
              icon: Icon(Icons.add_rounded, size: R.s(18)),
              label: const Text('New'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
        ],
      ),
      body: state.isLoading
          ? Padding(
              padding: EdgeInsets.all(R.s(20)),
              child: Column(
                children: List.generate(
                  3,
                  (i) => Padding(
                    padding: EdgeInsets.only(bottom: R.s(12)),
                    child: DSSkeletonCard(height: R.s(90)),
                  ),
                ),
              ),
            )
          : state.groups.isEmpty
              ? DSEmptyState(
                  emoji: '👥',
                  title: 'No groups yet',
                  subtitle:
                      'Create a group to split expenses with friends, family, or colleagues.',
                  actionLabel: 'Create Group',
                  onAction: () => context.push(AppRoutes.createGroup),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(R.s(20)),
                  itemCount: state.groups.length,
                  itemBuilder: (context, i) {
                    final group = state.groups[i];
                    final expState = ref.watch(groupExpenseProvider(group.id));
                    final balances = expState.netBalances(group.currentUserId);
                    final myNet = balances[group.currentUserId] ?? 0.0;
                    return GroupCard(
                      group: group,
                      myNetBalance: myNet,
                      onTap: () => context.push(
                        AppRoutes.groupDetail.replaceAll(':id', group.id),
                      ),
                    )
                        .animate(delay: Duration(milliseconds: 60 * i))
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.1, end: 0);
                  },
                ),
      floatingActionButton:
          state.groups.isEmpty ? null : null, // FAB shown via AppBar action
    );
  }
}
