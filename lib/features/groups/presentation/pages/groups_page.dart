import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/components/ds_empty_state.dart';
import '../../../../core/design/components/ds_skeleton.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/ui/error_feedback.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive.dart';
import '../../domain/entities/group.dart';
import '../providers/group_provider.dart';
import '../widgets/group_card.dart';

enum _GroupFilter { all, getBack, owe, settled }

class GroupsPage extends ConsumerStatefulWidget {
  const GroupsPage({super.key});

  @override
  ConsumerState<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends ConsumerState<GroupsPage> {
  final _searchCtrl = TextEditingController();
  bool _searchActive = false;
  _GroupFilter _filter = _GroupFilter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matchesSearch(Group group, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (group.name.toLowerCase().contains(q)) return true;
    return group.members.any((m) {
      final name = m.name.toLowerCase();
      final handle = m.handle.toLowerCase();
      return name.contains(q) || handle.contains(q);
    });
  }

  bool _passesFilter(double net) {
    switch (_filter) {
      case _GroupFilter.getBack:
        return net > 0.01;
      case _GroupFilter.owe:
        return net < -0.01;
      case _GroupFilter.settled:
        return net.abs() <= 0.01;
      case _GroupFilter.all:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colorScheme = Theme.of(context).colorScheme;
    listenForProviderError<GroupState>(
      ref: ref,
      context: context,
      provider: groupProvider,
      errorSelector: (s) => s.error,
    );
    final state = ref.watch(groupProvider);
    final query = _searchCtrl.text;

    final entries = <_GroupListEntry>[];
    var totalYouGet = 0.0;
    var totalYouOwe = 0.0;
    var totalSpent = 0.0;
    var openBalanceGroups = 0;
    var totalMembers = 0;

    for (final group in state.groups) {
      final expState = ref.watch(groupExpenseProvider(group.id));
      final youGet = expState.myTotalOwing(group.currentUserId);
      final youOwe = expState.myTotalOwed(group.currentUserId);
      final net = youGet - youOwe;
      totalMembers += group.members.length;
      if (net.abs() > 0.01) {
        openBalanceGroups += 1;
      }
      final spent = expState.expenses.fold<double>(
        0,
        (sum, expense) => sum + expense.amount,
      );

      totalYouGet += youGet;
      totalYouOwe += youOwe;
      totalSpent += spent;

      if (_matchesSearch(group, query) && _passesFilter(net)) {
        entries.add(
          _GroupListEntry(
            group: group,
            net: net,
            expenseCount: expState.expenses.length,
            totalSpent: spent,
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        title: Text(
          'Groups',
          style: TextStyle(
            fontSize: R.t(20),
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _searchActive ? Icons.close_rounded : Icons.search_rounded,
            ),
            onPressed: () {
              setState(() {
                _searchActive = !_searchActive;
                if (!_searchActive) {
                  _searchCtrl.clear();
                }
              });
            },
            tooltip: _searchActive ? 'Close search' : 'Search groups',
          ),
          if (state.groups.isNotEmpty)
            TextButton.icon(
              onPressed: () => context.push(AppRoutes.createGroup),
              icon: Icon(Icons.add_rounded, size: R.s(18)),
              label: const Text('New'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
        ],
      ),
      body: state.isLoading && state.groups.isEmpty
          ? Padding(
              padding: EdgeInsets.all(R.s(20)),
              child: Column(
                children: List.generate(
                  3,
                  (i) => Padding(
                    padding: EdgeInsets.only(bottom: R.s(12)),
                    child: DSSkeletonCard(height: R.s(96)),
                  ),
                ),
              ),
            )
          : state.groups.isEmpty
              ? DSEmptyState(
                  emoji: '??',
                  title: 'No groups yet',
                  subtitle:
                      'Create a group to split expenses with friends, family, or colleagues.',
                  actionLabel: 'Create Group',
                  onAction: () => context.push(AppRoutes.createGroup),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(groupProvider.notifier).refresh(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      R.s(20),
                      R.s(8),
                      R.s(20),
                      R.s(24),
                    ),
                    children: [
                      if (_searchActive)
                        Padding(
                          padding: EdgeInsets.only(bottom: R.s(12)),
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (_) => setState(() {}),
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'Search groups or members',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: query.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.clear_rounded),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() {});
                                      },
                                    ),
                            ),
                          ),
                        ),
                      _GroupsOverviewRow(
                        groupCount: state.groups.length,
                        memberCount: totalMembers,
                        openBalanceGroups: openBalanceGroups,
                        totalYouGet: totalYouGet,
                        totalYouOwe: totalYouOwe,
                        totalSpent: totalSpent,
                      ),
                      SizedBox(height: R.s(12)),
                      Wrap(
                        spacing: R.s(8),
                        runSpacing: R.s(8),
                        children: _GroupFilter.values.map((f) {
                          final selected = _filter == f;
                          return FilterChip(
                            label: Text(
                              _labelForFilter(f),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: R.t(11),
                                color: selected
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurface,
                              ),
                            ),
                            selectedColor: colorScheme.primary,
                            backgroundColor: colorScheme.surfaceContainerHigh,
                            side: BorderSide(
                              color: selected
                                  ? colorScheme.primary
                                  : colorScheme.outline,
                            ),
                            showCheckmark: false,
                            selected: selected,
                            onSelected: (_) => setState(() => _filter = f),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: R.s(14)),
                      if (entries.isEmpty)
                        Container(
                          padding: EdgeInsets.all(R.md),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(R.s(14)),
                            border:
                                Border.all(color: colorScheme.outlineVariant),
                          ),
                          child: Text(
                            'No groups match your current search/filter.',
                            style: TextStyle(
                              fontSize: R.t(13),
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        ...entries.asMap().entries.map((entry) {
                          final i = entry.key;
                          final item = entry.value;
                          return GroupCard(
                            group: item.group,
                            myNetBalance: item.net,
                            expenseCount: item.expenseCount,
                            totalSpent: item.totalSpent,
                            compact: true,
                            onTap: () => context.push(
                              AppRoutes.groupDetail
                                  .replaceAll(':id', item.group.id),
                            ),
                          )
                              .animate(delay: Duration(milliseconds: 60 * i))
                              .fadeIn(duration: 300.ms)
                              .slideY(begin: 0.04, end: 0);
                        }),
                    ],
                  ),
                ),
    );
  }

  String _labelForFilter(_GroupFilter filter) {
    switch (filter) {
      case _GroupFilter.all:
        return 'All';
      case _GroupFilter.getBack:
        return 'You get back';
      case _GroupFilter.owe:
        return 'You owe';
      case _GroupFilter.settled:
        return 'Settled';
    }
  }
}

class _GroupsOverviewRow extends StatelessWidget {
  final int groupCount;
  final int memberCount;
  final int openBalanceGroups;
  final double totalYouGet;
  final double totalYouOwe;
  final double totalSpent;

  const _GroupsOverviewRow({
    required this.groupCount,
    required this.memberCount,
    required this.openBalanceGroups,
    required this.totalYouGet,
    required this.totalYouOwe,
    required this.totalSpent,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row(
        //   children: [
        //     Icon(
        //       Icons.insights_rounded,
        //       size: R.s(16),
        //       color: colorScheme.primary,
        //     ),
        //     SizedBox(width: R.s(6)),
        //     Text(
        //       'Snapshot',
        //       style: TextStyle(
        //         fontSize: R.t(11),
        //         fontWeight: FontWeight.w700,
        //         color: colorScheme.onSurfaceVariant,
        //         letterSpacing: 0.4,
        //       ),
        //     ),
        //   ],
        // ),
        // SizedBox(height: R.s(10)),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _MetricPill(
                icon: Icons.groups_rounded,
                label: 'Groups',
                value: '$groupCount',
                color: colorScheme.primary,
                background: colorScheme.primaryContainer,
              ),
              SizedBox(width: R.s(8)),
              _MetricPill(
                icon: Icons.person_rounded,
                label: 'Members',
                value: '$memberCount',
                color: colorScheme.onSecondaryContainer,
                background: colorScheme.secondaryContainer,
              ),
              SizedBox(width: R.s(8)),
              _MetricPill(
                icon: Icons.compare_arrows_rounded,
                label: 'Open',
                value: '$openBalanceGroups',
                color: colorScheme.tertiary,
                background: colorScheme.tertiaryContainer,
              ),
              SizedBox(width: R.s(8)),
              _MetricPill(
                icon: Icons.arrow_downward_rounded,
                label: 'You get',
                value: CurrencyFormatter.format(totalYouGet),
                color: AppColors.income,
                background: AppColors.incomeLight,
              ),
              SizedBox(width: R.s(8)),
              _MetricPill(
                icon: Icons.arrow_upward_rounded,
                label: 'You owe',
                value: CurrencyFormatter.format(totalYouOwe),
                color: AppColors.expense,
                background: AppColors.errorLight,
              ),
              SizedBox(width: R.s(8)),
              _MetricPill(
                icon: Icons.payments_rounded,
                label: 'Total spent',
                value: CurrencyFormatter.format(totalSpent),
                color: colorScheme.primary,
                background: colorScheme.primaryContainer,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color background;

  const _MetricPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Container(
      constraints: BoxConstraints(minWidth: R.s(98)),
      padding: EdgeInsets.symmetric(horizontal: R.s(10), vertical: R.s(8)),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(R.s(12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: R.s(14), color: color),
          SizedBox(width: R.s(6)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: R.t(9),
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.85),
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: R.t(11),
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupListEntry {
  final Group group;
  final double net;
  final int expenseCount;
  final double totalSpent;

  const _GroupListEntry({
    required this.group,
    required this.net,
    required this.expenseCount,
    required this.totalSpent,
  });
}
