import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/components/ds_dialog.dart';
import '../../../../core/design/components/ds_empty_state.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/auth_interceptor.dart';
import '../../../../core/network/network_error.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/ui/error_feedback.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive.dart';
import '../../../auth/presentation/providers/cloud_auth_provider.dart';
import '../../../export/services/pdf_export_service.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_expense.dart';
import '../../domain/entities/group_member.dart';
import '../../domain/entities/group_settlement_audit.dart';
import '../providers/group_budget_provider.dart';
import '../providers/group_provider.dart';
import '../widgets/debt_summary_widget.dart';

class GroupDetailPage extends ConsumerWidget {
  final String groupId;
  const GroupDetailPage({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    R.init(context);
    listenForProviderError<GroupState>(
      ref: ref,
      context: context,
      provider: groupProvider,
      errorSelector: (s) => s.error,
    );
    listenForProviderError<GroupExpenseState>(
      ref: ref,
      context: context,
      provider: groupExpenseProvider(groupId),
      errorSelector: (s) => s.error,
    );
    listenForProviderError<GroupSettlementAuditState>(
      ref: ref,
      context: context,
      provider: groupSettlementAuditProvider(groupId),
      errorSelector: (s) => s.error,
    );
    final groupState = ref.watch(groupProvider);
    final expState = ref.watch(groupExpenseProvider(groupId));
    final settlementState = ref.watch(groupSettlementAuditProvider(groupId));
    final groupBudgetState = ref.watch(groupBudgetProvider);
    final cloudUserId = ref.watch(cloudAuthProvider).user?.id;
    final group = groupState.groups.firstWhere(
      (g) => g.id == groupId,
      orElse: () => Group(
        id: groupId,
        name: 'Group',
        emoji: '👥',
        ownerId: '',
        members: [],
        currentUserId: '',
        createdAt: DateTime.now(),
      ),
    );

    final balances = expState.netBalances(group.currentUserId);
    final settlements = simplifyDebts(balances);
    final now = DateTime.now();
    final monthlySpend = _monthlySpend(expState.expenses, now);
    final activeBudgetPlan = groupBudgetState.planFor(groupId, now);
    final leaderboard =
        _buildLeaderboardEntries(group.members, expState.expenses, now);
    final challengeProgress = _buildChallengeProgress(
      entries: leaderboard,
      monthExpenseCount: _monthlyExpenseCount(expState.expenses, now),
      monthlyBudget: activeBudgetPlan?.monthlyBudget,
      monthlySpend: monthlySpend,
    );
    final totalSpent = expState.expenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );
    final myGetBack = expState.myTotalOwing(group.currentUserId);
    final myOwe = expState.myTotalOwed(group.currentUserId);
    final myNet = myGetBack - myOwe;
    final isGroupOwner = cloudUserId != null && cloudUserId == group.ownerId;
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen<GroupExpenseState>(groupExpenseProvider(groupId), (prev, next) {
      final spend = _monthlySpend(next.expenses, DateTime.now());
      unawaited(
        ref.read(groupBudgetProvider.notifier).evaluateBudgetAlerts(
              groupId: groupId,
              groupName: group.name,
              monthlySpend: spend,
            ),
      );
    });

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            backgroundColor: colorScheme.surface,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
            title: Row(
              children: [
                Hero(
                  tag: 'group-avatar-${group.id}',
                  child: Material(
                    type: MaterialType.transparency,
                    child: Container(
                      width: R.s(34),
                      height: R.s(34),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(R.s(10)),
                      ),
                      alignment: Alignment.center,
                      child: Text(group.emoji,
                          style: TextStyle(fontSize: R.t(18))),
                    ),
                  ),
                ),
                SizedBox(width: R.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'group-name-${group.id}',
                      child: Material(
                        type: MaterialType.transparency,
                        child: Text(
                          group.name,
                          style: TextStyle(
                            fontSize: R.t(17),
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '${group.members.length} members',
                      style: TextStyle(
                        fontSize: R.t(12),
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'Export PDF',
                onPressed: expState.expenses.isEmpty
                    ? null
                    : () async {
                        try {
                          final currency = ref.read(settingsProvider).currency;
                          await PdfExportService.exportGroupExpenses(
                            expenses: expState.expenses,
                            groupName: group.name,
                            groupEmoji: group.emoji,
                            members: group.members,
                            fileName:
                                'finflow_${group.name.replaceAll(' ', '_')}_${DateTime.now().year}',
                            currencySymbol: currency,
                          );
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Export failed. Try again.')),
                            );
                          }
                        }
                      },
              ),
              IconButton(
                icon: const Icon(Icons.person_add_outlined),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => _AddMemberDialog(groupId: groupId),
                ),
                tooltip: 'Add member',
              ),
            ],
          ),
        ],
        body: expState.expenses.isEmpty
            ? DSEmptyState(
                emoji: '🧾',
                title: 'No expenses yet',
                subtitle:
                    'Add your first expense to start splitting costs with the group.',
                actionLabel: 'Add Expense',
                onAction: () => context.push(
                  AppRoutes.addGroupExpense.replaceAll(':id', groupId),
                ),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.all(R.s(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatRow(
                      totalSpent: totalSpent,
                      memberCount: group.members.length,
                      myGetBack: myGetBack,
                      myOwe: myOwe,
                      myNet: myNet,
                    ),
                    SizedBox(height: R.s(16)),
                    _GroupBudgetPlannerCard(
                      groupName: group.name,
                      monthlySpend: monthlySpend,
                      budgetPlan: activeBudgetPlan,
                      onSetBudget: () => _showGroupBudgetPlanDialog(
                        context,
                        ref,
                        groupId: group.id,
                        existingPlan: activeBudgetPlan,
                      ),
                      onClearBudget: activeBudgetPlan == null
                          ? null
                          : () => ref
                              .read(groupBudgetProvider.notifier)
                              .clearPlan(group.id),
                    ),
                    SizedBox(height: R.s(16)),
                    _GroupLeaderboardSection(entries: leaderboard),
                    SizedBox(height: R.s(16)),
                    _GroupChallengesSection(progress: challengeProgress),
                    SizedBox(height: R.s(16)),
                    if (settlements.isNotEmpty) ...[
                      DebtSummaryWidget(
                        settlements: settlements,
                        members: group.members,
                        currentUserId: group.currentUserId,
                        groupId: groupId,
                      ),
                      SizedBox(height: R.s(20)),
                    ],
                    _SettlementAuditSection(
                      group: group,
                      state: settlementState,
                      isGroupOwner: isGroupOwner,
                      onRefresh: () => ref
                          .read(groupSettlementAuditProvider(groupId).notifier)
                          .refresh(),
                      onDispute: (audit) =>
                          _showDisputeDialog(context, ref, audit),
                      onResolve: (audit) =>
                          _showResolveDialog(context, ref, audit),
                    ),
                    SizedBox(height: R.s(20)),
                    Text(
                      'TRANSACTIONS',
                      style: TextStyle(
                        fontSize: R.t(11),
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: R.s(10)),
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(R.md),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: ListView.separated(
                        primary: false,
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: expState.expenses.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: 16,
                          color: colorScheme.outlineVariant,
                        ),
                        itemBuilder: (ctx, i) {
                          final exp = expState.expenses[i];
                          final payer = group.members.isEmpty
                              ? null
                              : group.members.firstWhere(
                                  (m) => m.id == exp.paidByMemberId,
                                  orElse: () => group.members.first,
                                );
                          final payerHandle = payer?.handle ?? '@unknown';

                          // Settlement expenses — shown as read-only green tiles
                          if (exp.isSettlement) {
                            final payeeId = exp.shares.isNotEmpty
                                ? exp.shares.first.memberId
                                : null;
                            final payee =
                                payeeId == null || group.members.isEmpty
                                    ? null
                                    : group.members.firstWhere(
                                        (m) => m.id == payeeId,
                                        orElse: () => group.members.first,
                                      );
                            final payeeHandle = payee?.handle ?? '@unknown';
                            return ListTile(
                              key: Key(exp.id),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: R.md,
                                vertical: R.sm,
                              ),
                              leading: Container(
                                width: R.s(44),
                                height: R.s(44),
                                decoration: BoxDecoration(
                                  color: colorScheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(R.s(12)),
                                ),
                                child: Center(
                                  child: Text(
                                    '🤝',
                                    style: TextStyle(fontSize: R.t(20)),
                                  ),
                                ),
                              ),
                              title: Text(
                                exp.description,
                                style: TextStyle(
                                  fontSize: R.t(14),
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.tertiary,
                                ),
                              ),
                              subtitle: Text(
                                'Settlement $payerHandle → $payeeHandle · ${exp.date.day}/${exp.date.month}',
                                style: TextStyle(
                                  fontSize: R.t(12),
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              trailing: Text(
                                CurrencyFormatter.format(exp.amount),
                                style: TextStyle(
                                  fontSize: R.t(15),
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.tertiary,
                                ),
                              ),
                            )
                                .animate(delay: Duration(milliseconds: 40 * i))
                                .fadeIn(duration: 200.ms);
                          }

                          // Regular expenses — swipe-to-delete
                          return Dismissible(
                            key: Key(exp.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: EdgeInsets.only(right: R.s(20)),
                              color: colorScheme.errorContainer,
                              child: Icon(
                                Icons.delete_outline_rounded,
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                            confirmDismiss: (_) async {
                              final shouldDelete = await DSConfirmDialog.show(
                                context: ctx,
                                title: 'Delete expense?',
                                message:
                                    'This removes "${exp.description}" for everyone in the group.',
                                cancelLabel: 'Cancel',
                                confirmLabel: 'Delete',
                                isDestructive: true,
                              );
                              return shouldDelete ?? false;
                            },
                            onDismissed: (_) async {
                              try {
                                await ref
                                    .read(
                                      groupExpenseProvider(groupId).notifier,
                                    )
                                    .deleteExpense(exp.id);
                              } catch (_) {
                                // Restore the item — delete failed on server
                                await ref
                                    .read(
                                      groupExpenseProvider(groupId).notifier,
                                    )
                                    .refresh();
                              }
                            },
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: R.md,
                                vertical: R.sm,
                              ),
                              leading: Container(
                                width: R.s(44),
                                height: R.s(44),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(R.s(12)),
                                ),
                                child: Center(
                                  child: Text(
                                    '🧾',
                                    style: TextStyle(fontSize: R.t(20)),
                                  ),
                                ),
                              ),
                              title: Text(
                                exp.description,
                                style: TextStyle(
                                  fontSize: R.t(14),
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              subtitle: Text(
                                'Paid by $payerHandle · ${exp.shares.length} split · ${exp.date.day}/${exp.date.month}',
                                style: TextStyle(
                                  fontSize: R.t(12),
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              trailing: Text(
                                CurrencyFormatter.format(exp.amount),
                                style: TextStyle(
                                  fontSize: R.t(15),
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                          )
                              .animate(delay: Duration(milliseconds: 40 * i))
                              .fadeIn(duration: 200.ms);
                        },
                      ),
                    ),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () =>
            context.push(AppRoutes.addGroupExpense.replaceAll(':id', groupId)),
        tooltip: 'Add expense',
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  double _monthlySpend(List<GroupExpense> expenses, DateTime monthRef) {
    return expenses
        .where(
          (e) =>
              e.date.month == monthRef.month &&
              e.date.year == monthRef.year &&
              !e.isSettlement,
        )
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  int _monthlyExpenseCount(List<GroupExpense> expenses, DateTime monthRef) {
    return expenses
        .where(
          (e) =>
              e.date.month == monthRef.month &&
              e.date.year == monthRef.year &&
              !e.isSettlement,
        )
        .length;
  }

  List<_MemberLeaderboardEntry> _buildLeaderboardEntries(
    List<GroupMember> members,
    List<GroupExpense> expenses,
    DateTime monthRef,
  ) {
    final paidBy = <String, double>{};
    final owedBy = <String, double>{};

    for (final expense in expenses) {
      if (expense.isSettlement) continue;
      if (expense.date.month != monthRef.month ||
          expense.date.year != monthRef.year) {
        continue;
      }

      paidBy[expense.paidByMemberId] =
          (paidBy[expense.paidByMemberId] ?? 0) + expense.amount;
      for (final share in expense.shares) {
        owedBy[share.memberId] = (owedBy[share.memberId] ?? 0) + share.amount;
      }
    }

    final entries = members.map((member) {
      return _MemberLeaderboardEntry(
        member: member,
        paid: paidBy[member.id] ?? 0,
        owed: owedBy[member.id] ?? 0,
      );
    }).toList();

    entries.sort((a, b) => b.net.compareTo(a.net));
    return entries;
  }

  _GroupChallengeProgress _buildChallengeProgress({
    required List<_MemberLeaderboardEntry> entries,
    required int monthExpenseCount,
    required double? monthlyBudget,
    required double monthlySpend,
  }) {
    final totalMembers = entries.length;
    final settledMembers = entries.where((e) => e.net.abs() <= 50).length;
    final settlementProgress =
        totalMembers == 0 ? 0.0 : settledMembers / totalMembers;

    final expenseLoggingProgress = (monthExpenseCount / 8).clamp(0.0, 1.0);

    final budgetProgress = (() {
      if (monthlyBudget == null || monthlyBudget <= 0) return 0.0;
      final remainingRatio = (monthlyBudget - monthlySpend) / monthlyBudget;
      return remainingRatio.clamp(0.0, 1.0);
    })();

    return _GroupChallengeProgress(
      settlementProgress: settlementProgress,
      expenseLoggingProgress: expenseLoggingProgress,
      budgetGuardProgress: budgetProgress,
      monthlyBudget: monthlyBudget,
      monthlySpend: monthlySpend,
      monthExpenseCount: monthExpenseCount,
      settledMembers: settledMembers,
      totalMembers: totalMembers,
    );
  }

  Future<void> _showGroupBudgetPlanDialog(
    BuildContext context,
    WidgetRef ref, {
    required String groupId,
    required GroupBudgetPlan? existingPlan,
  }) async {
    final current = existingPlan?.monthlyBudget;
    final symbol = CurrencyFormatter.symbol();
    final ctrl = TextEditingController(
      text: current != null && current > 0 ? current.toStringAsFixed(0) : '',
    );

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Set Group Monthly Budget'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Budget amount',
            hintText: 'Enter amount',
            prefixText: '$symbol ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    final rawAmount = ctrl.text.trim();
    ctrl.dispose();

    if (shouldSave != true) return;

    final parsed = double.tryParse(rawAmount);
    if (parsed == null || parsed <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid positive amount.')),
        );
      }
      return;
    }

    await ref.read(groupBudgetProvider.notifier).setMonthlyBudget(
          groupId: groupId,
          monthlyBudget: parsed,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Group budget updated.')),
    );
  }

  Future<void> _showDisputeDialog(
    BuildContext context,
    WidgetRef ref,
    GroupSettlementAudit audit,
  ) async {
    final reasonCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Dispute settlement'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonCtrl,
                maxLength: 240,
                decoration: const InputDecoration(
                  labelText: 'Reason *',
                  hintText: 'Explain what looks incorrect',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtrl,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Submit dispute'),
          ),
        ],
      ),
    );

    final reason = reasonCtrl.text.trim();
    final note = noteCtrl.text.trim();
    reasonCtrl.dispose();
    noteCtrl.dispose();

    if (shouldSubmit != true) return;
    if (reason.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dispute reason is required.')),
        );
      }
      return;
    }

    try {
      await ref
          .read(groupSettlementAuditProvider(groupId).notifier)
          .submitDispute(
            settlementExpenseId: audit.settlementExpenseId,
            reason: reason,
            note: note,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settlement marked as disputed.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cleanExceptionMessage(e))),
      );
    }
  }

  Future<void> _showResolveDialog(
    BuildContext context,
    WidgetRef ref,
    GroupSettlementAudit audit,
  ) async {
    final noteCtrl = TextEditingController();
    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resolve dispute'),
        content: TextField(
          controller: noteCtrl,
          maxLength: 500,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Resolution note (optional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );

    final resolutionNote = noteCtrl.text.trim();
    noteCtrl.dispose();
    if (shouldSubmit != true) return;

    try {
      await ref
          .read(groupSettlementAuditProvider(groupId).notifier)
          .resolveDispute(
            settlementExpenseId: audit.settlementExpenseId,
            resolutionNote: resolutionNote,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settlement dispute resolved.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cleanExceptionMessage(e))),
      );
    }
  }

  String _cleanExceptionMessage(Object error) {
    final raw = error.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length);
    }
    return raw;
  }
}

class _StatRow extends StatelessWidget {
  final double totalSpent;
  final int memberCount;
  final double myGetBack;
  final double myOwe;
  final double myNet;

  const _StatRow({
    required this.totalSpent,
    required this.memberCount,
    required this.myGetBack,
    required this.myOwe,
    required this.myNet,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(R.md),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(R.s(14)),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Group overview',
            style: TextStyle(
              fontSize: R.t(12),
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0.4,
            ),
          ),
          SizedBox(height: R.s(8)),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'Total spent',
                  value: CurrencyFormatter.format(totalSpent),
                  color: colorScheme.onSurface,
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Per person',
                  value: CurrencyFormatter.format(
                    memberCount > 0 ? totalSpent / memberCount : 0,
                  ),
                  color: colorScheme.primary,
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Your net',
                  value: CurrencyFormatter.format(myNet.abs()),
                  color: myNet >= 0 ? AppColors.income : colorScheme.error,
                  helper: myNet >= 0 ? 'you get back' : 'you owe',
                ),
              ),
            ],
          ),
          SizedBox(height: R.s(12)),
          Row(
            children: [
              Expanded(
                child: _AmountBadge(
                  label: 'You get',
                  amount: myGetBack,
                  bg: colorScheme.tertiaryContainer,
                  color: AppColors.income,
                ),
              ),
              SizedBox(width: R.s(10)),
              Expanded(
                child: _AmountBadge(
                  label: 'You owe',
                  amount: myOwe,
                  bg: colorScheme.errorContainer,
                  color: colorScheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String? helper;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:
              TextStyle(fontSize: R.t(11), color: colorScheme.onSurfaceVariant),
        ),
        SizedBox(height: R.s(2)),
        Text(
          value,
          style: TextStyle(
            fontSize: R.t(17),
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        if (helper != null)
          Text(
            helper!,
            style: TextStyle(
              fontSize: R.t(10),
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }
}

class _AmountBadge extends StatelessWidget {
  final String label;
  final double amount;
  final Color bg;
  final Color color;

  const _AmountBadge({
    required this.label,
    required this.amount,
    required this.bg,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: R.s(12), vertical: R.s(10)),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(R.s(12)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: R.t(11),
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            CurrencyFormatter.format(amount),
            style: TextStyle(
              fontSize: R.t(12),
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberLeaderboardEntry {
  final GroupMember member;
  final double paid;
  final double owed;

  const _MemberLeaderboardEntry({
    required this.member,
    required this.paid,
    required this.owed,
  });

  double get net => paid - owed;
}

class _GroupChallengeProgress {
  final double settlementProgress;
  final double expenseLoggingProgress;
  final double budgetGuardProgress;
  final double? monthlyBudget;
  final double monthlySpend;
  final int monthExpenseCount;
  final int settledMembers;
  final int totalMembers;

  const _GroupChallengeProgress({
    required this.settlementProgress,
    required this.expenseLoggingProgress,
    required this.budgetGuardProgress,
    required this.monthlyBudget,
    required this.monthlySpend,
    required this.monthExpenseCount,
    required this.settledMembers,
    required this.totalMembers,
  });
}

class _GroupBudgetPlannerCard extends StatelessWidget {
  final String groupName;
  final double monthlySpend;
  final GroupBudgetPlan? budgetPlan;
  final VoidCallback onSetBudget;
  final VoidCallback? onClearBudget;

  const _GroupBudgetPlannerCard({
    required this.groupName,
    required this.monthlySpend,
    required this.budgetPlan,
    required this.onSetBudget,
    required this.onClearBudget,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colorScheme = Theme.of(context).colorScheme;
    final hasPlan = budgetPlan != null && budgetPlan!.monthlyBudget > 0;
    final planAmount = budgetPlan?.monthlyBudget ?? 0;
    final ratio = hasPlan ? (monthlySpend / planAmount).clamp(0.0, 1.4) : 0.0;

    Color meterColor;
    if (ratio >= 1) {
      meterColor = colorScheme.error;
    } else if (ratio >= 0.8) {
      meterColor = AppColors.warning;
    } else {
      meterColor = AppColors.success;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(R.md),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(R.s(14)),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'GROUP BUDGET PLANNER',
                style: TextStyle(
                  fontSize: R.t(11),
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onSetBudget,
                icon: const Icon(Icons.edit_rounded),
                label: Text(hasPlan ? 'Edit' : 'Set'),
              ),
              if (onClearBudget != null)
                TextButton(
                  onPressed: onClearBudget,
                  child: const Text('Clear'),
                ),
            ],
          ),
          Text(
            hasPlan
                ? 'Track $groupName against a monthly cap'
                : 'Set a monthly group budget to unlock progress and alert nudges.',
            style: TextStyle(
              fontSize: R.t(12),
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (hasPlan) ...[
            SizedBox(height: R.s(12)),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Spent: ${CurrencyFormatter.format(monthlySpend)}',
                    style: TextStyle(
                      fontSize: R.t(12),
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  'Budget: ${CurrencyFormatter.format(planAmount)}',
                  style: TextStyle(
                    fontSize: R.t(12),
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            SizedBox(height: R.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(R.s(10)),
              child: LinearProgressIndicator(
                value: ratio > 1 ? 1 : ratio,
                minHeight: R.s(8),
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(meterColor),
              ),
            ),
            SizedBox(height: R.xs),
            Text(
              ratio >= 1
                  ? 'Budget exceeded by ${CurrencyFormatter.format(monthlySpend - planAmount)}'
                  : '${(ratio * 100).toStringAsFixed(0)}% of monthly budget used',
              style: TextStyle(
                fontSize: R.t(11),
                color: ratio >= 1 ? colorScheme.error : colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupLeaderboardSection extends StatelessWidget {
  final List<_MemberLeaderboardEntry> entries;

  const _GroupLeaderboardSection({required this.entries});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(R.md),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(R.s(14)),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LEADERBOARD',
            style: TextStyle(
              fontSize: R.t(11),
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: R.s(8)),
          if (entries.isEmpty)
            Text(
              'No leaderboard data for this month yet.',
              style: TextStyle(
                fontSize: R.t(12),
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...entries.take(5).toList().asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final row = entry.value;
              final net = row.net;
              final netColor =
                  net >= 0 ? AppColors.success : colorScheme.error;
              return Padding(
                padding: EdgeInsets.only(bottom: R.xs),
                child: Row(
                  children: [
                    Container(
                      width: R.s(24),
                      height: R.s(24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(R.s(8)),
                      ),
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          fontSize: R.t(11),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(width: R.s(10)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.member.handle,
                            style: TextStyle(
                              fontSize: R.t(12),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Paid ${CurrencyFormatter.format(row.paid)} · Share ${CurrencyFormatter.format(row.owed)}',
                            style: TextStyle(
                              fontSize: R.t(10),
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${net >= 0 ? '+' : '-'}${CurrencyFormatter.format(net.abs())}',
                      style: TextStyle(
                        fontSize: R.t(12),
                        fontWeight: FontWeight.w800,
                        color: netColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _GroupChallengesSection extends StatelessWidget {
  final _GroupChallengeProgress progress;

  const _GroupChallengesSection({required this.progress});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(R.md),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(R.s(14)),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SOCIAL CHALLENGES',
            style: TextStyle(
              fontSize: R.t(11),
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: R.s(8)),
          _ChallengeTile(
            icon: Icons.check_circle_outline_rounded,
            title: 'Settle-Up Sprint',
            subtitle:
                '${progress.settledMembers}/${progress.totalMembers} members near-zero balance',
            progress: progress.settlementProgress,
          ),
          _ChallengeTile(
            icon: Icons.list_alt_rounded,
            title: '8 Expense Logs',
            subtitle: '${progress.monthExpenseCount}/8 shared expenses logged',
            progress: progress.expenseLoggingProgress,
          ),
          _ChallengeTile(
            icon: Icons.shield_outlined,
            title: 'Budget Guard',
            subtitle: progress.monthlyBudget == null
                ? 'Set a group budget to track this challenge'
                : 'Spend ${CurrencyFormatter.format(progress.monthlySpend)} of ${CurrencyFormatter.format(progress.monthlyBudget!)}',
            progress: progress.monthlyBudget == null
                ? 0
                : progress.budgetGuardProgress,
          ),
        ],
      ),
    );
  }
}

class _ChallengeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double progress;

  const _ChallengeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colorScheme = Theme.of(context).colorScheme;
    final pct = (progress * 100).clamp(0.0, 100.0);
    return Padding(
      padding: EdgeInsets.only(bottom: R.s(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(R.s(8)),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(R.s(10)),
            ),
            child: Icon(icon, size: R.s(16), color: colorScheme.primary),
          ),
          SizedBox(width: R.s(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: R.t(12),
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: R.xs),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: R.t(10),
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: R.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(R.s(999)),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: R.s(6),
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: R.s(8)),
          Text(
            '${pct.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: R.t(11),
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettlementAuditSection extends StatelessWidget {
  const _SettlementAuditSection({
    required this.group,
    required this.state,
    required this.isGroupOwner,
    required this.onRefresh,
    required this.onDispute,
    required this.onResolve,
  });

  final Group group;
  final GroupSettlementAuditState state;
  final bool isGroupOwner;
  final Future<void> Function() onRefresh;
  final Future<void> Function(GroupSettlementAudit audit) onDispute;
  final Future<void> Function(GroupSettlementAudit audit) onResolve;

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(R.md),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'SETTLEMENT AUDIT',
                style: TextStyle(
                  fontSize: R.t(11),
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh settlement audits',
                onPressed: state.isLoading ? null : onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          SizedBox(height: R.s(8)),
          if (state.isLoading && state.audits.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(),
              ),
            )
          else if (state.audits.isEmpty)
            Text(
              'No settlement audit entries yet.',
              style: TextStyle(
                fontSize: R.t(12),
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            Column(
              children: state.audits.map((audit) {
                final fromHandle = _memberHandle(group, audit.fromMemberId);
                final toHandle = _memberHandle(group, audit.toMemberId);
                final dispute = audit.dispute;

                return Container(
                  margin: EdgeInsets.only(bottom: R.s(10)),
                  padding: EdgeInsets.all(R.s(10)),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(R.s(10)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$fromHandle → $toHandle',
                              style: TextStyle(
                                fontSize: R.t(13),
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          _SettlementStatusChip(audit: audit),
                        ],
                      ),
                      SizedBox(height: R.s(4)),
                      Text(
                        '${CurrencyFormatter.format(audit.amount)} · ${audit.settledAt.toLocal()}',
                        style: TextStyle(
                          fontSize: R.t(11),
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (dispute != null) ...[
                        SizedBox(height: R.s(8)),
                        Text(
                          'Dispute reason: ${dispute.reason}',
                          style: TextStyle(
                            fontSize: R.t(11),
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        if (dispute.note != null &&
                            dispute.note!.trim().isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: R.s(2)),
                            child: Text(
                              'Note: ${dispute.note}',
                              style: TextStyle(
                                fontSize: R.t(11),
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        if (dispute.resolutionNote != null &&
                            dispute.resolutionNote!.trim().isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: R.s(2)),
                            child: Text(
                              'Resolution: ${dispute.resolutionNote}',
                              style: TextStyle(
                                fontSize: R.t(11),
                                color: colorScheme.tertiary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                      SizedBox(height: R.s(8)),
                      Wrap(
                        spacing: R.s(8),
                        runSpacing: R.s(8),
                        children: [
                          if (!audit.isResolved && !audit.isDisputed)
                            OutlinedButton.icon(
                              onPressed: state.isSubmitting
                                  ? null
                                  : () => onDispute(audit),
                              icon: const Icon(Icons.report_problem_outlined),
                              label: const Text('Dispute'),
                            ),
                          if (audit.isDisputed && isGroupOwner)
                            FilledButton.icon(
                              onPressed: state.isSubmitting
                                  ? null
                                  : () => onResolve(audit),
                              icon: const Icon(Icons.verified_rounded),
                              label: const Text('Resolve as owner'),
                            ),
                          if (audit.isDisputed && !isGroupOwner)
                            Text(
                              'Awaiting owner resolution',
                              style: TextStyle(
                                fontSize: R.t(11),
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  String _memberHandle(Group group, String memberId) {
    for (final member in group.members) {
      if (member.id == memberId) {
        return member.handle;
      }
    }
    return memberId;
  }
}

class _SettlementStatusChip extends StatelessWidget {
  const _SettlementStatusChip({required this.audit});

  final GroupSettlementAudit audit;

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colorScheme = Theme.of(context).colorScheme;

    Color bg;
    Color fg;
    String label;

    if (audit.isResolved) {
      bg = colorScheme.tertiaryContainer;
      fg = colorScheme.tertiary;
      label = 'Resolved';
    } else if (audit.isDisputed) {
      bg = colorScheme.errorContainer;
      fg = colorScheme.error;
      label = 'Disputed';
    } else {
      bg = colorScheme.primaryContainer;
      fg = colorScheme.primary;
      label = 'Recorded';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: R.s(8), vertical: R.s(4)),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(R.s(999)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: R.t(10),
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

// ── Add Member Dialog (username search) ───────────────────────────────────────
class _AddMemberDialog extends ConsumerStatefulWidget {
  final String groupId;
  const _AddMemberDialog({required this.groupId});

  @override
  ConsumerState<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends ConsumerState<_AddMemberDialog> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;
  bool _searched = false;
  String? _searchError;
  String _lastQuery = '';
  int _searchToken = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search({String? query}) async {
    final q = (query ?? _ctrl.text).trim();
    if (q.length < 2) return;

    final currentToken = ++_searchToken;
    setState(() {
      _isSearching = true;
      _searched = false;
      _searchError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        ApiEndpoints.userSearch,
        queryParameters: {'username': q},
      );
      if (!mounted || currentToken != _searchToken) return;

      final list = (res.data['data'] as List?) ?? [];
      setState(() {
        _results = list.cast<Map<String, dynamic>>();
        _isSearching = false;
        _searched = true;
        _searchError = null;
        _lastQuery = q;
      });
    } on DioException catch (e) {
      if (!mounted || currentToken != _searchToken) return;
      setState(() {
        _results = [];
        _isSearching = false;
        _searched = true;
        _searchError = formatDioError(
          e,
          fallback: 'Unable to search users right now.',
        );
      });
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();

    if (q.length < 2) {
      setState(() {
        _results = [];
        _searched = false;
        _searchError = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (q == _lastQuery && _searched && _searchError == null) return;
      _search(query: q);
    });
  }

  Future<void> _addUser(Map<String, dynamic> user) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    try {
      await ref.read(groupProvider.notifier).addMemberByUserId(
            widget.groupId,
            user['id'] as String,
            (user['name'] as String?) ??
                (user['username'] as String? ?? 'Member'),
          );
    } catch (e) {
      final raw = e.toString();
      final message = raw.startsWith('Exception: ')
          ? raw.substring('Exception: '.length)
          : raw;
      messenger.showSnackBar(
        SnackBar(
            content: Text(message.isEmpty ? 'Failed to add member.' : message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final query = _ctrl.text.trim();

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      title: const Text('Add member'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _ctrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Search by username (e.g. chirag19)',
                prefixIcon: const Icon(Icons.person_search_outlined),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: _search,
                ),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )
            else if (query.isNotEmpty && query.length < 2)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Type at least 2 characters to search.'),
              )
            else if (_searchError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _searchError!,
                      style: TextStyle(color: colorScheme.error),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _search(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry search'),
                    ),
                  ],
                ),
              )
            else if (_searched && _results.isEmpty)
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'No users found.',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              )
            else if (_results.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final user = _results[i];
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_outline),
                      ),
                      title: Text('@${user['username'] ?? ''}'),
                      subtitle: Text(user['name'] as String? ?? ''),
                      trailing: const Icon(Icons.add_rounded),
                      onTap: () => _addUser(user),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
