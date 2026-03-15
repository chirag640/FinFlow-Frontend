// Figma: Screen/ExpenseDetail
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive.dart';
import '../../domain/entities/expense.dart';
import '../providers/expense_provider.dart';

class ExpenseDetailPage extends ConsumerWidget {
  final Expense expense;
  const ExpenseDetailPage({super.key, required this.expense});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    R.init(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text(
          'Expense Detail',
          style: TextStyle(
              fontSize: R.t(18),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            onPressed: () =>
                context.push(AppRoutes.editExpense, extra: expense),
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error),
            onPressed: () => _confirmDelete(context, ref),
            tooltip: 'Delete',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(R.s(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero amount card
            _AmountHero(expense: expense)
                .animate()
                .fadeIn(duration: 350.ms)
                .slideY(begin: 0.08, end: 0),
            SizedBox(height: R.s(20)),

            // Detail rows
            _DetailCard(expense: expense)
                .animate(delay: 80.ms)
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.06, end: 0),

            // Note
            if (expense.note != null && expense.note!.isNotEmpty) ...[
              SizedBox(height: R.md),
              _NoteCard(note: expense.note!)
                  .animate(delay: 140.ms)
                  .fadeIn(duration: 300.ms),
            ],

            SizedBox(height: R.xl),

            // Delete CTA at bottom
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmDelete(context, ref),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete this expense',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: EdgeInsets.symmetric(vertical: R.s(12)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(R.s(12))),
                ),
              ),
            ).animate(delay: 200.ms).fadeIn(duration: 300.ms),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text(
            'Remove "${expense.description}" from your records? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(expenseProvider.notifier).deleteExpense(expense.id);
              context.pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Amount Hero ───────────────────────────────────────────────────────────────
class _AmountHero extends StatelessWidget {
  final Expense expense;
  const _AmountHero({required this.expense});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final isIncome = expense.isIncome;
    final bgGradient = isIncome
        ? [const Color(0xFF10B981), const Color(0xFF059669)]
        : [AppColors.primary, const Color(0xFF3730A3)];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(R.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: bgGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(R.s(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category bubble
          Container(
            width: R.s(56),
            height: R.s(56),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(R.s(14)),
            ),
            child: Center(
              child: Text(expense.category.emoji,
                  style: TextStyle(fontSize: R.t(26))),
            ),
          ),
          SizedBox(height: R.md),
          Text(
            expense.description,
            style: TextStyle(
                fontSize: R.t(20),
                fontWeight: FontWeight.w700,
                color: Colors.white),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: R.s(6)),
          Row(
            children: [
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: R.s(10), vertical: R.s(3)),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(R.s(20)),
                ),
                child: Text(
                  isIncome ? '↑ Income' : '↓ Expense',
                  style: TextStyle(
                      fontSize: R.t(11),
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
              const Spacer(),
              Text(
                CurrencyFormatter.format(expense.amount),
                style: TextStyle(
                    fontSize: R.t(28),
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Detail Card ───────────────────────────────────────────────────────────────
class _DetailCard extends StatelessWidget {
  final Expense expense;
  const _DetailCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    final rows = [
      _DetailRow(
        icon: Icons.category_outlined,
        label: 'Category',
        value: '${expense.category.emoji}  ${expense.category.label}',
      ),
      _DetailRow(
        icon: Icons.calendar_today_outlined,
        label: 'Date',
        value: DateFormat('EEEE, MMMM d, yyyy').format(expense.date),
      ),
      _DetailRow(
        icon: Icons.access_time_outlined,
        label: 'Time',
        value: DateFormat('h:mm a').format(expense.date),
      ),
      if (expense.isRecurring)
        _DetailRow(
          icon: Icons.repeat_rounded,
          label: 'Recurring',
          value: expense.recurringFrequency?.label ?? 'Yes',
          valueColor: AppColors.primary,
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: rows
            .asMap()
            .entries
            .map((e) => Column(
                  children: [
                    e.value,
                    if (e.key < rows.length - 1)
                      Divider(height: 1, indent: 56, color: AppColors.border),
                  ],
                ))
            .toList(),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: R.md, vertical: R.s(14)),
      child: Row(
        children: [
          Container(
            width: R.s(36),
            height: R.s(36),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(R.sm),
            ),
            child: Icon(icon, size: R.s(18), color: AppColors.textSecondary),
          ),
          SizedBox(width: R.s(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: R.t(11), color: AppColors.textTertiary)),
                SizedBox(height: R.s(2)),
                Text(value,
                    style: TextStyle(
                      fontSize: R.t(14),
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? AppColors.textPrimary,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Note Card ─────────────────────────────────────────────────────────────────
class _NoteCard extends StatelessWidget {
  final String note;
  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(R.md),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(R.s(14)),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sticky_note_2_outlined,
              color: AppColors.warning, size: R.s(18)),
          SizedBox(width: R.s(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Note',
                    style: TextStyle(
                        fontSize: R.t(11),
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning)),
                SizedBox(height: R.xs),
                Text(note,
                    style: TextStyle(
                        fontSize: R.t(14), color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
