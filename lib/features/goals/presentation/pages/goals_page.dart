// Figma: Screen/Goals
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/components/ds_dialog.dart';
import '../../../../core/design/components/ds_empty_state.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive.dart';
import '../../domain/entities/savings_goal.dart';
import '../providers/goals_provider.dart';

class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    R.init(context);
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(goalsProvider);

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: colorScheme.onSurface),
        title: Text(
          'Savings Goals',
          style: TextStyle(
              fontSize: R.t(18),
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddGoalSheet(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Goal',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: state.goals.isEmpty
          ? DSEmptyState(
              emoji: '🎯',
              title: 'No savings goals yet',
              subtitle:
                  'Set a target, track your progress, and celebrate when you reach it.',
              actionLabel: 'Add Goal',
              onAction: () => _showAddGoalSheet(context, ref),
            )
          : CustomScrollView(
              slivers: [
                // Summary header
                SliverToBoxAdapter(
                  child: _GoalsSummaryBar(state: state)
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.08, end: 0),
                ),
                // Active goals
                if (state.active.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          EdgeInsets.fromLTRB(R.s(20), R.s(20), R.s(20), R.sm),
                      child: Text('ACTIVE',
                          style: TextStyle(
                            fontSize: R.t(11),
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTertiary,
                            letterSpacing: 1.2,
                          )),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: R.md),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _GoalCard(
                          goal: state.active[i],
                          index: i,
                          onAddFunds: () =>
                              _showAddFundsSheet(context, ref, state.active[i]),
                          onDelete: () =>
                              _confirmDelete(context, ref, state.active[i]),
                        )
                            .animate(delay: Duration(milliseconds: 60 * i))
                            .fadeIn(duration: 280.ms)
                            .slideY(begin: 0.08, end: 0),
                        childCount: state.active.length,
                      ),
                    ),
                  ),
                ],
                // Completed goals
                if (state.completed.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          EdgeInsets.fromLTRB(R.s(20), R.s(20), R.s(20), R.sm),
                      child: Text('COMPLETED 🎉',
                          style: TextStyle(
                            fontSize: R.t(11),
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                            letterSpacing: 1.2,
                          )),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: R.md),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _GoalCard(
                          goal: state.completed[i],
                          index: i,
                          onAddFunds: null,
                          onDelete: () =>
                              _confirmDelete(context, ref, state.completed[i]),
                        ).animate().fadeIn(duration: 250.ms),
                        childCount: state.completed.length,
                      ),
                    ),
                  ),
                ],
                SliverToBoxAdapter(child: SizedBox(height: R.s(100))),
              ],
            ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, SavingsGoal goal) {
    DSConfirmDialog.show(
      context: context,
      title: 'Delete goal?',
      message: '"${goal.title}" will be permanently removed.',
      confirmLabel: 'Delete',
      isDestructive: true,
    ).then((confirmed) {
      if (confirmed == true) {
        ref.read(goalsProvider.notifier).deleteGoal(goal.id);
      }
    });
  }
}

// ── Summary Bar ───────────────────────────────────────────────────────────────
class _GoalsSummaryBar extends StatelessWidget {
  final GoalsState state;
  const _GoalsSummaryBar({required this.state});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final overallPct = state.totalTargeted > 0
        ? (state.totalSaved / state.totalTargeted).clamp(0.0, 1.0)
        : 0.0;

    // Use theme-defined gradient colors for consistency
    const gradientColors = [AppColors.primary, AppColors.primaryDark];

    return Container(
      margin: EdgeInsets.fromLTRB(R.md, R.md, R.md, 0),
      padding: EdgeInsets.all(R.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(R.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Saved',
                        style: TextStyle(
                            fontSize: R.t(12),
                            color: Colors.white.withValues(alpha: 0.7))),
                    SizedBox(height: R.xs),
                    Text(
                      CurrencyFormatter.format(state.totalSaved),
                      style: TextStyle(
                          fontSize: R.t(24),
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Target',
                      style: TextStyle(
                          fontSize: R.t(12),
                          color: Colors.white.withValues(alpha: 0.7))),
                  SizedBox(height: R.xs),
                  Text(
                    CurrencyFormatter.format(state.totalTargeted),
                    style: TextStyle(
                        fontSize: R.t(16),
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: R.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(R.sm),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: overallPct),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOut,
              builder: (_, val, __) => LinearProgressIndicator(
                value: val,
                minHeight: R.s(8),
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
          SizedBox(height: R.sm),
          Text(
            '${(overallPct * 100).toStringAsFixed(0)}% of total goal · '
            '${state.active.length} active, ${state.completed.length} completed',
            style: TextStyle(
                fontSize: R.t(11),
                color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

// ── Goal Card ─────────────────────────────────────────────────────────────────
// Figma: Card/Goal
class _GoalCard extends ConsumerWidget {
  final SavingsGoal goal;
  final int index;
  final VoidCallback? onAddFunds;
  final VoidCallback onDelete;

  const _GoalCard({
    required this.goal,
    required this.index,
    required this.onAddFunds,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    R.init(context);
    final color = GoalColors.at(goal.colorIndex);
    final pct = goal.progressPercent;
    final daysLeft = goal.deadline?.difference(DateTime.now()).inDays;

    return Container(
      margin: EdgeInsets.only(bottom: R.sm),
      padding: EdgeInsets.all(R.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(R.s(18)),
        border: Border.all(
          color: goal.isCompleted
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: R.s(46),
                height: R.s(46),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(R.s(12)),
                ),
                child: Center(
                  child: Text(goal.emoji, style: TextStyle(fontSize: R.t(22))),
                ),
              ),
              SizedBox(width: R.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            goal.title,
                            style: TextStyle(
                              fontSize: R.t(15),
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (goal.isCompleted)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: R.sm, vertical: R.s(2)),
                            decoration: BoxDecoration(
                              color: AppColors.successLight,
                              borderRadius: BorderRadius.circular(R.s(20)),
                            ),
                            child: Text('Done ✓',
                                style: TextStyle(
                                    fontSize: R.t(10),
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.success)),
                          ),
                      ],
                    ),
                    SizedBox(height: R.s(2)),
                    if (daysLeft != null)
                      Text(
                        daysLeft > 0
                            ? '$daysLeft days left · due ${DateFormat('MMM d, yyyy').format(goal.deadline!)}'
                            : 'Deadline passed',
                        style: TextStyle(
                          fontSize: R.t(11),
                          color: daysLeft <= 7 && !goal.isCompleted
                              ? AppColors.warning
                              : AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              // Delete
              IconButton(
                icon: Icon(Icons.more_vert_rounded,
                    color: AppColors.textTertiary, size: R.s(20)),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          SizedBox(height: R.s(14)),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(R.sm),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOut,
              builder: (_, val, __) => LinearProgressIndicator(
                value: val,
                minHeight: R.s(9),
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(
                  goal.isCompleted ? AppColors.success : color,
                ),
              ),
            ),
          ),
          SizedBox(height: R.s(10)),

          // Amount row
          Row(
            children: [
              Text(
                CurrencyFormatter.format(goal.currentAmount),
                style: TextStyle(
                  fontSize: R.t(14),
                  fontWeight: FontWeight.w700,
                  color: goal.isCompleted ? AppColors.success : color,
                ),
              ),
              Text(
                ' / ${CurrencyFormatter.format(goal.targetAmount)}',
                style:
                    TextStyle(fontSize: R.t(13), color: AppColors.textTertiary),
              ),
              const Spacer(),
              Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: R.t(13),
                  fontWeight: FontWeight.w700,
                  color: goal.isCompleted ? AppColors.success : color,
                ),
              ),
            ],
          ),

          // Add funds button
          if (onAddFunds != null && !goal.isCompleted) ...[
            SizedBox(height: R.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAddFunds,
                icon: Icon(Icons.add_rounded, size: R.s(16)),
                label: const Text('Add funds',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color.withValues(alpha: 0.4)),
                  padding: EdgeInsets.symmetric(vertical: R.sm),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(R.s(10))),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Add Goal Bottom Sheet ─────────────────────────────────────────────────────
void _showAddGoalSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddGoalSheet(ref: ref),
  );
}

void _showAddFundsSheet(BuildContext context, WidgetRef ref, SavingsGoal goal) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddFundsSheet(ref: ref, goal: goal),
  );
}

class _AddGoalSheet extends StatefulWidget {
  final WidgetRef ref;
  const _AddGoalSheet({required this.ref});

  @override
  State<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends State<_AddGoalSheet> {
  final _titleCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _currentCtrl = TextEditingController();
  String _emoji = '🎯';
  int _colorIndex = 0;
  DateTime? _deadline;
  final _formKey = GlobalKey<FormState>();

  static const _emojis = [
    '🎯',
    '🏠',
    '🚗',
    '✈️',
    '💻',
    '💍',
    '🎓',
    '🏋️',
    '📱',
    '🛍️',
    '🌴',
    '💰',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _targetCtrl.dispose();
    _currentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.s(24))),
      ),
      padding: EdgeInsets.fromLTRB(R.s(20), R.sm, R.s(20), R.s(20) + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: R.s(40),
                height: R.s(4),
                margin: EdgeInsets.only(bottom: R.s(20)),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(R.s(2)),
                ),
              ),
            ),
            Text('New Savings Goal',
                style: TextStyle(
                    fontSize: R.t(18),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            SizedBox(height: R.s(20)),

            // Emoji picker row
            SizedBox(
              height: R.s(44),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _emojis.length,
                separatorBuilder: (_, __) => SizedBox(width: R.sm),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => setState(() => _emoji = _emojis[i]),
                  child: Container(
                    width: R.s(44),
                    height: R.s(44),
                    decoration: BoxDecoration(
                      color: _emoji == _emojis[i]
                          ? AppColors.primaryExtraLight
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(R.s(12)),
                      border: Border.all(
                        color: _emoji == _emojis[i]
                            ? AppColors.primary
                            : Colors.transparent,
                      ),
                    ),
                    child: Center(
                        child: Text(_emojis[i],
                            style: TextStyle(fontSize: R.t(20)))),
                  ),
                ),
              ),
            ),
            SizedBox(height: R.md),

            // Color picker
            SizedBox(
              height: R.s(28),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: GoalColors.palette.length,
                separatorBuilder: (_, __) => SizedBox(width: R.sm),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => setState(() => _colorIndex = i),
                  child: Container(
                    width: R.s(28),
                    height: R.s(28),
                    decoration: BoxDecoration(
                      color: GoalColors.palette[i],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _colorIndex == i
                            ? AppColors.textPrimary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: _colorIndex == i
                        ? Icon(Icons.check_rounded,
                            color: Colors.white, size: R.s(14))
                        : null,
                  ),
                ),
              ),
            ),
            SizedBox(height: R.md),

            // Title
            TextFormField(
              controller: _titleCtrl,
              decoration: _inputDeco('Goal name', '(e.g. Emergency fund)'),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            SizedBox(height: R.sm),

            // Target + current side-by-side
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _targetCtrl,
                    decoration: _inputDeco('Target ₹', '50000'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Enter amount';
                      return null;
                    },
                  ),
                ),
                SizedBox(width: R.sm),
                Expanded(
                  child: TextFormField(
                    controller: _currentCtrl,
                    decoration: _inputDeco('Saved so far ₹', '0'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            SizedBox(height: R.sm),

            // Deadline (optional)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: R.s(40),
                height: R.s(40),
                decoration: BoxDecoration(
                  color: AppColors.primaryExtraLight,
                  borderRadius: BorderRadius.circular(R.s(10)),
                ),
                child: Icon(Icons.event_rounded,
                    color: AppColors.primary, size: R.s(20)),
              ),
              title: Text(
                _deadline != null
                    ? 'Target date: ${DateFormat('MMM d, yyyy').format(_deadline!)}'
                    : 'Add target date (optional)',
                style: TextStyle(
                    fontSize: R.t(14), color: AppColors.textSecondary),
              ),
              trailing: _deadline != null
                  ? IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: AppColors.textTertiary, size: R.s(18)),
                      onPressed: () => setState(() => _deadline = null),
                    )
                  : null,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 90)),
                  firstDate: DateTime.now().add(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                );
                if (picked != null) setState(() => _deadline = picked);
              },
            ),
            SizedBox(height: R.s(20)),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: R.s(14))),
                child: Text('Create Goal',
                    style: TextStyle(
                        fontSize: R.t(15), fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    widget.ref.read(goalsProvider.notifier).addGoal(
          title: _titleCtrl.text.trim(),
          emoji: _emoji,
          targetAmount: double.parse(_targetCtrl.text),
          currentAmount: double.tryParse(_currentCtrl.text) ?? 0,
          deadline: _deadline,
          colorIndex: _colorIndex,
        );
    Navigator.pop(context);
  }

  InputDecoration _inputDeco(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(R.s(12))),
        contentPadding:
            EdgeInsets.symmetric(horizontal: R.s(14), vertical: R.sm),
      );
}

class _AddFundsSheet extends StatefulWidget {
  final WidgetRef ref;
  final SavingsGoal goal;
  const _AddFundsSheet({required this.ref, required this.goal});

  @override
  State<_AddFundsSheet> createState() => _AddFundsSheetState();
}

class _AddFundsSheetState extends State<_AddFundsSheet> {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final remaining = widget.goal.remaining;
    final color = GoalColors.at(widget.goal.colorIndex);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.s(24))),
      ),
      padding: EdgeInsets.fromLTRB(R.s(20), R.sm, R.s(20), R.s(20) + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: R.s(40),
                height: R.s(4),
                margin: EdgeInsets.only(bottom: R.md),
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(R.s(2))),
              ),
            ),
            Row(
              children: [
                Text(widget.goal.emoji, style: TextStyle(fontSize: R.t(28))),
                SizedBox(width: R.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.goal.title,
                        style: TextStyle(
                            fontSize: R.t(16),
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text(
                      '${CurrencyFormatter.format(remaining)} still needed',
                      style: TextStyle(
                          fontSize: R.t(12), color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: R.s(20)),
            TextFormField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Amount to add ₹',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(R.s(12))),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: R.s(14), vertical: R.sm),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Enter a positive amount';
                return null;
              },
            ),
            SizedBox(height: R.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  widget.ref
                      .read(goalsProvider.notifier)
                      .addFunds(widget.goal.id, double.parse(_ctrl.text));
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  padding: EdgeInsets.symmetric(vertical: R.s(14)),
                ),
                child: Text('Add Funds',
                    style: TextStyle(
                        fontSize: R.t(15), fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
