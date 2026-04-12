// Figma: Screen/ExpenseDetail
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/components/ds_dialog.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive.dart';
import '../../domain/entities/expense.dart';
import '../providers/expense_provider.dart';
import '../widgets/receipt_network_image.dart';

class ExpenseDetailPage extends ConsumerWidget {
  final Expense expense;
  const ExpenseDetailPage({super.key, required this.expense});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    R.init(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: colorScheme.onSurface),
        title: Text(
          'Expense Detail',
          style: TextStyle(
              fontSize: R.t(18),
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, color: AppColors.accent),
            onPressed: () => _openQuickSplitShare(context),
            tooltip: 'Quick split share',
          ),
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

            if ((expense.receiptImageBase64 != null &&
                    expense.receiptImageBase64!.isNotEmpty) ||
                (expense.receiptImageUrl != null &&
                    expense.receiptImageUrl!.isNotEmpty) ||
                (expense.receiptStorageKey != null &&
                    expense.receiptStorageKey!.isNotEmpty)) ...[
              SizedBox(height: R.md),
              _ReceiptImageCard(
                receiptImageBase64: expense.receiptImageBase64,
                receiptImageUrl: expense.receiptImageUrl,
                receiptStorageKey: expense.receiptStorageKey,
              ).animate(delay: 170.ms).fadeIn(duration: 300.ms),
            ],

            if (expense.receiptOcrText != null &&
                expense.receiptOcrText!.isNotEmpty) ...[
              SizedBox(height: R.md),
              _ReceiptOcrCard(receiptOcrText: expense.receiptOcrText!)
                  .animate(delay: 200.ms)
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
    DSConfirmDialog.show(
      context: context,
      title: 'Delete expense?',
      message:
          'Remove "${expense.description}" from your records? This cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    ).then((confirmed) {
      if (confirmed == true && context.mounted) {
        ref.read(expenseProvider.notifier).deleteExpense(expense.id);
        context.pop();
      }
    });
  }

  void _openQuickSplitShare(BuildContext context) {
    int participants = 2;
    final noteController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final perPerson = expense.amount / participants;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                R.s(20),
                R.s(18),
                R.s(20),
                MediaQuery.of(sheetContext).viewInsets.bottom + R.s(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Split Share',
                    style: TextStyle(
                      fontSize: R.t(18),
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: R.s(6)),
                  Text(
                    'Share this expense without creating a group.',
                    style: TextStyle(
                      fontSize: R.t(12),
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: R.md),
                  Text(
                    '$participants people · ${CurrencyFormatter.format(perPerson)} each',
                    style: TextStyle(
                      fontSize: R.t(13),
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  Slider(
                    value: participants.toDouble(),
                    min: 2,
                    max: 20,
                    divisions: 18,
                    label: '$participants',
                    onChanged: (value) {
                      setSheetState(() => participants = value.round());
                    },
                  ),
                  TextField(
                    controller: noteController,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Optional note',
                      hintText: 'e.g. UPI me by tonight',
                    ),
                  ),
                  SizedBox(height: R.sm),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final note = noteController.text.trim();
                        await _shareQuickSplit(participants, note);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Share Split'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(noteController.dispose);
  }

  Future<void> _shareQuickSplit(int participants, String note) async {
    final total = CurrencyFormatter.format(expense.amount);
    final perPerson = CurrencyFormatter.format(expense.amount / participants);
    final dateText = DateFormat('d MMM yyyy').format(expense.date);

    final message = StringBuffer()
      ..writeln('FinFlow Quick Split')
      ..writeln('${expense.category.emoji} ${expense.description}')
      ..writeln('Date: $dateText')
      ..writeln('Total: $total')
      ..writeln('Split: $participants people · $perPerson each');

    if (note.isNotEmpty) {
      message
        ..writeln()
        ..writeln('Note: $note');
    }

    await Share.share(
      message.toString(),
      subject: 'Split request: ${expense.description}',
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
    // Use theme colors instead of hardcoded hex values
    final bgGradient = isIncome
        ? [AppColors.success, const Color(0xFF059669)]
        : [AppColors.primary, AppColors.primaryDark];

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
        color: Theme.of(context).colorScheme.surface,
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
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
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

class _ReceiptImageCard extends StatelessWidget {
  final String? receiptImageBase64;
  final String? receiptImageUrl;
  final String? receiptStorageKey;

  const _ReceiptImageCard({
    this.receiptImageBase64,
    this.receiptImageUrl,
    this.receiptStorageKey,
  });

  Widget _buildFallback() {
    return const Center(
      child: Icon(
        Icons.broken_image_outlined,
        color: AppColors.textTertiary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasBase64 =
        receiptImageBase64 != null && receiptImageBase64!.isNotEmpty;
    final hasUrl = receiptImageUrl != null && receiptImageUrl!.isNotEmpty;
    final hasStorageKey =
        receiptStorageKey != null && receiptStorageKey!.isNotEmpty;

    if (!hasBase64 && !hasUrl && !hasStorageKey) {
      return const SizedBox.shrink();
    }

    Widget image;
    if (hasBase64) {
      try {
        image = Image.memory(
          base64Decode(receiptImageBase64!),
          width: double.infinity,
          height: R.s(220),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      } catch (_) {
        image = _buildFallback();
      }
    } else {
      image = ReceiptNetworkImage(
        receiptImageUrl: receiptImageUrl,
        receiptStorageKey: receiptStorageKey,
        width: double.infinity,
        height: R.s(220),
        fit: BoxFit.cover,
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(R.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(R.s(14)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Receipt',
            style: TextStyle(
              fontSize: R.t(12),
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: R.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(R.s(10)),
            child: image,
          ),
        ],
      ),
    );
  }
}

class _ReceiptOcrCard extends StatelessWidget {
  final String receiptOcrText;
  const _ReceiptOcrCard({required this.receiptOcrText});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(R.md),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(R.s(14)),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Receipt OCR',
            style: TextStyle(
              fontSize: R.t(12),
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
          SizedBox(height: R.xs),
          Text(
            receiptOcrText,
            style: TextStyle(
              fontSize: R.t(13),
              color: AppColors.textPrimary,
              height: 1.4,
            ),
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
