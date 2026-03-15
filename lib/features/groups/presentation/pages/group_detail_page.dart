import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/components/ds_empty_state.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/auth_interceptor.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/ui/error_feedback.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive.dart';
import '../../../export/services/pdf_export_service.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_expense.dart';
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
    final groupState = ref.watch(groupProvider);
    final expState = ref.watch(groupExpenseProvider(groupId));
    final group = groupState.groups.firstWhere(
      (g) => g.id == groupId,
      orElse: () => Group(
        id: groupId,
        name: 'Group',
        emoji: '👥',
        members: [],
        currentUserId: '',
        createdAt: DateTime.now(),
      ),
    );

    final balances = expState.netBalances(group.currentUserId);
    final settlements = simplifyDebts(balances);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            backgroundColor: AppColors.surface,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
            title: Row(
              children: [
                Text(group.emoji, style: TextStyle(fontSize: R.t(22))),
                SizedBox(width: R.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: TextStyle(
                        fontSize: R.t(17),
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${group.members.length} members',
                      style: TextStyle(
                        fontSize: R.t(12),
                        color: AppColors.textTertiary,
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
                padding: EdgeInsets.all(R.s(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (settlements.isNotEmpty) ...[
                      DebtSummaryWidget(
                        settlements: settlements,
                        members: group.members,
                        currentUserId: group.currentUserId,
                        groupId: groupId,
                      ),
                      SizedBox(height: R.s(20)),
                    ],
                    // Total stats
                    _StatRow(
                      totalSpent: expState.expenses.fold(
                        0.0,
                        (s, e) => s + e.amount,
                      ),
                      memberCount: group.members.length,
                    ),
                    SizedBox(height: R.s(20)),
                    Text(
                      'TRANSACTIONS',
                      style: TextStyle(
                        fontSize: R.t(11),
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: R.s(10)),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(R.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ListView.separated(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: expState.expenses.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          indent: 16,
                          color: AppColors.border,
                        ),
                        itemBuilder: (ctx, i) {
                          final exp = expState.expenses[i];
                          final payer = group.members.firstWhere(
                            (m) => m.id == exp.paidByMemberId,
                            orElse: () => group.members.first,
                          );

                          // Settlement expenses — shown as read-only green tiles
                          if (exp.isSettlement) {
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
                                  color: AppColors.successLight,
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
                                  color: AppColors.success,
                                ),
                              ),
                              subtitle: Text(
                                'Settlement · ${exp.date.day}/${exp.date.month}',
                                style: TextStyle(
                                  fontSize: R.t(12),
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              trailing: Text(
                                CurrencyFormatter.format(exp.amount),
                                style: TextStyle(
                                  fontSize: R.t(15),
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success,
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
                              color: AppColors.errorLight,
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.error,
                              ),
                            ),
                            confirmDismiss: (_) async => await showDialog<bool>(
                              context: ctx,
                              builder: (d) => AlertDialog(
                                title: const Text('Delete expense?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => d.pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => d.pop(true),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            ),
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
                                  color: AppColors.primaryExtraLight,
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
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                'Paid by ${payer.name} · ${exp.date.day}/${exp.date.month}',
                                style: TextStyle(
                                  fontSize: R.t(12),
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              trailing: Text(
                                CurrencyFormatter.format(exp.amount),
                                style: TextStyle(
                                  fontSize: R.t(15),
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push(AppRoutes.addGroupExpense.replaceAll(':id', groupId)),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Expense',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final double totalSpent;
  final int memberCount;
  const _StatRow({required this.totalSpent, required this.memberCount});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Container(
      padding: EdgeInsets.all(R.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(R.s(14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Spent',
                  style: TextStyle(
                      fontSize: R.t(12), color: AppColors.textTertiary),
                ),
                SizedBox(height: R.s(2)),
                Text(
                  CurrencyFormatter.format(totalSpent),
                  style: TextStyle(
                    fontSize: R.t(20),
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Per Person',
                style:
                    TextStyle(fontSize: R.t(12), color: AppColors.textTertiary),
              ),
              SizedBox(height: R.s(2)),
              Text(
                CurrencyFormatter.format(
                  memberCount > 0 ? totalSpent / memberCount : 0,
                ),
                style: TextStyle(
                  fontSize: R.t(20),
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
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
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;
  bool _searched = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.length < 2) return;
    setState(() {
      _isSearching = true;
      _searched = false;
    });
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        ApiEndpoints.userSearch,
        queryParameters: {'username': q},
      );
      final list = (res.data['data'] as List?) ?? [];
      setState(() {
        _results = list.cast<Map<String, dynamic>>();
        _isSearching = false;
        _searched = true;
      });
    } on DioException {
      setState(() {
        _isSearching = false;
        _searched = true;
      });
    }
  }

  Future<void> _addUser(Map<String, dynamic> user) async {
    Navigator.pop(context);
    try {
      await ref.read(groupProvider.notifier).addMemberByUserId(
            widget.groupId,
            user['id'] as String,
            (user['name'] as String?) ??
                (user['username'] as String? ?? 'Member'),
          );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
              decoration: InputDecoration(
                hintText: 'Search by username (e.g. chirag19)',
                prefixIcon: const Icon(Icons.person_search_outlined),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: _search,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )
            else if (_searched && _results.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('No users found.',
                    style: TextStyle(color: Colors.grey)),
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
