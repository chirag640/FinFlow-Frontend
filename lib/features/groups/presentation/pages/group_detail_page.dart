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
    final totalSpent = expState.expenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );
    final myGetBack = expState.myTotalOwing(group.currentUserId);
    final myOwe = expState.myTotalOwed(group.currentUserId);
    final myNet = myGetBack - myOwe;
    final colorScheme = Theme.of(context).colorScheme;

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
                    if (settlements.isNotEmpty) ...[
                      DebtSummaryWidget(
                        settlements: settlements,
                        members: group.members,
                        currentUserId: group.currentUserId,
                        groupId: groupId,
                      ),
                      SizedBox(height: R.s(20)),
                    ],
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
