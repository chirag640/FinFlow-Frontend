// Figma: Screen/Export
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/components/ds_dialog.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/utils/responsive.dart';
import '../../../expenses/domain/entities/expense.dart';
import '../../../expenses/domain/entities/expense_category.dart';
import '../../../expenses/presentation/providers/expense_provider.dart';
import '../../data/export_preset_store.dart';
import '../../domain/export_options.dart';
import '../../services/csv_export_service.dart';
import '../../services/pdf_export_service.dart';

enum _ExportFormat { csv, pdf }

class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});
  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();
  bool _exporting = false;
  _ExportFormat _format = _ExportFormat.csv;
  ExportTransactionFilter _transactionFilter = ExportTransactionFilter.all;
  ExportGrouping _grouping = ExportGrouping.category;
  ExportSummaryLayout _summaryLayout = ExportSummaryLayout.standard;
  ExportBrandTemplate _brandTemplate = ExportBrandTemplate.classic;
  bool _includeComparison = false;
  final Set<ExpenseCategory> _categories = <ExpenseCategory>{};
  List<ExportPreset> _presets = const <ExportPreset>[];

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    final loaded = ExportPresetStore.load();
    if (!mounted) return;
    setState(() => _presets = loaded);
  }

  Future<void> _saveCurrentAsPreset() async {
    final name = await DSInputDialog.show(
      context: context,
      title: 'Save Export Preset',
      hintText: 'e.g. Executive Monthly PDF',
      confirmLabel: 'Save',
    );

    if (name == null || name.isEmpty) return;

    final preset = ExportPreset(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      format: _format.name,
      transactionFilter: _transactionFilter,
      grouping: _grouping,
      summaryLayout: _summaryLayout,
      brandTemplate: _brandTemplate,
      categories: _categories.map((c) => c.name).toSet(),
      includeComparison: _includeComparison,
    );
    final updated = <ExportPreset>[
      ..._presets.where((p) => p.name != name),
      preset
    ];
    await ExportPresetStore.saveAll(updated);
    if (!mounted) return;
    setState(() => _presets = updated);
  }

  Future<void> _deletePreset(String id) async {
    final updated = _presets.where((p) => p.id != id).toList();
    await ExportPresetStore.saveAll(updated);
    if (!mounted) return;
    setState(() => _presets = updated);
  }

  void _applyPreset(ExportPreset preset) {
    setState(() {
      _format = preset.format == _ExportFormat.pdf.name
          ? _ExportFormat.pdf
          : _ExportFormat.csv;
      _transactionFilter = preset.transactionFilter;
      _grouping = preset.grouping;
      _summaryLayout = preset.summaryLayout;
      _brandTemplate = preset.brandTemplate;
      _includeComparison = preset.includeComparison;
      _categories
        ..clear()
        ..addAll(
          ExpenseCategory.values
              .where((c) => preset.categories.contains(c.name)),
        );
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
        if (_to.isBefore(_from)) _from = _to;
      }
    });
  }

  List<Expense> _filteredExpenses(List<Expense> source) {
    return source.where((e) {
      if (e.date.isBefore(_from) || e.date.isAfter(_to)) return false;
      if (_transactionFilter == ExportTransactionFilter.expense && e.isIncome) {
        return false;
      }
      if (_transactionFilter == ExportTransactionFilter.income && !e.isIncome) {
        return false;
      }
      if (_categories.isNotEmpty && !_categories.contains(e.category)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final expenses = _filteredExpenses(ref.read(expenseProvider).expenses);

      if (expenses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No expenses in the selected range')),
        );
        return;
      }

      final fmt = DateFormat('yyyy-MM-dd');
      final name = 'finflow_${fmt.format(_from)}_${fmt.format(_to)}';
      final fmtLabel = DateFormat('d MMM yyyy');
      final options = ExportOptions(
        transactionFilter: _transactionFilter,
        grouping: _grouping,
        summaryLayout: _summaryLayout,
        brandTemplate: _brandTemplate,
      );

      if (_format == _ExportFormat.csv) {
        await CsvExportService.exportExpenses(
          expenses: expenses,
          fileName: name,
          options: options,
        );
      } else {
        final periodDays = _to.difference(_from).inDays + 1;
        final prevTo = _from.subtract(const Duration(days: 1));
        final prevFrom = prevTo.subtract(Duration(days: periodDays - 1));
        final prevPeriodExpenses = ref
            .read(expenseProvider)
            .expenses
            .where((e) =>
                !e.date.isBefore(prevFrom) &&
                !e.date.isAfter(prevTo) &&
                (_transactionFilter == ExportTransactionFilter.all ||
                    (_transactionFilter == ExportTransactionFilter.expense
                        ? !e.isIncome
                        : e.isIncome)) &&
                (_categories.isEmpty || _categories.contains(e.category)))
            .toList();
        final currency =
            ref.read(settingsProvider).currency; // e.g. "INR", "USD"
        final settings = ref.read(settingsProvider);
        await PdfExportService.exportExpenses(
          expenses: expenses,
          fileName: name,
          fromLabel: fmtLabel.format(_from),
          toLabel: fmtLabel.format(_to),
          currencySymbol: currency,
          options: options,
          previousPeriodExpenses:
              _includeComparison ? prevPeriodExpenses : null,
          previousFromLabel:
              _includeComparison ? fmtLabel.format(prevFrom) : null,
          previousToLabel: _includeComparison ? fmtLabel.format(prevTo) : null,
          organizationName: settings.organizationName,
          organizationFooter: settings.organizationFooter,
          executiveSignatory: settings.executiveSignatory,
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colorScheme = Theme.of(context).colorScheme;
    final fmt = DateFormat('d MMM yyyy');
    final allExpenses = ref.watch(expenseProvider).expenses;
    final filtered = _filteredExpenses(allExpenses);
    final expCount = filtered.length;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        title: Text('Export Data',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: colorScheme.onSurface)),
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back_ios_rounded, color: colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(R.s(20)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Format selector
            const Text('Export Format',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const Gap(12),
            Row(children: [
              Expanded(
                child: _FormatChip(
                  label: 'CSV',
                  icon: Icons.table_chart_outlined,
                  subtitle: 'Excel / Sheets',
                  selected: _format == _ExportFormat.csv,
                  onTap: () => setState(() => _format = _ExportFormat.csv),
                ),
              ),
              const Gap(12),
              Expanded(
                child: _FormatChip(
                  label: 'PDF',
                  icon: Icons.picture_as_pdf_outlined,
                  subtitle: 'Formatted report',
                  selected: _format == _ExportFormat.pdf,
                  onTap: () => setState(() => _format = _ExportFormat.pdf),
                ),
              ),
            ]).animate().fadeIn(),
            const Gap(24),

            const Text('Saved Presets',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const Gap(10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ChoicePill(
                  label: '+ Save Current',
                  selected: false,
                  onTap: _saveCurrentAsPreset,
                ),
                ..._presets.map((preset) {
                  return _PresetChip(
                    label: preset.name,
                    subtitle: preset.format.toUpperCase(),
                    onTap: () => _applyPreset(preset),
                    onDelete: () => _deletePreset(preset.id),
                  );
                }),
              ],
            ).animate().fadeIn(delay: 80.ms),
            const Gap(20),

            // Date range
            const Text('Date Range',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const Gap(12),
            Row(children: [
              Expanded(
                child: _DateTile(
                  label: 'From',
                  date: fmt.format(_from),
                  onTap: () => _pickDate(isFrom: true),
                ),
              ),
              const Gap(12),
              Expanded(
                child: _DateTile(
                  label: 'To',
                  date: fmt.format(_to),
                  onTap: () => _pickDate(isFrom: false),
                ),
              ),
            ]).animate().fadeIn(delay: 100.ms),
            const Gap(20),

            const Text('Transaction Type',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const Gap(10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ChoicePill(
                  label: 'All',
                  selected: _transactionFilter == ExportTransactionFilter.all,
                  onTap: () => setState(() {
                    _transactionFilter = ExportTransactionFilter.all;
                  }),
                ),
                _ChoicePill(
                  label: 'Expenses',
                  selected:
                      _transactionFilter == ExportTransactionFilter.expense,
                  onTap: () => setState(() {
                    _transactionFilter = ExportTransactionFilter.expense;
                  }),
                ),
                _ChoicePill(
                  label: 'Income',
                  selected:
                      _transactionFilter == ExportTransactionFilter.income,
                  onTap: () => setState(() {
                    _transactionFilter = ExportTransactionFilter.income;
                  }),
                ),
              ],
            ).animate().fadeIn(delay: 125.ms),
            const Gap(20),

            const Text('Category Filter',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const Gap(10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ChoicePill(
                  label: 'All Categories',
                  selected: _categories.isEmpty,
                  onTap: () => setState(() => _categories.clear()),
                ),
                ...ExpenseCategory.values.map((cat) {
                  final selected = _categories.contains(cat);
                  return _ChoicePill(
                    label: '${cat.emoji} ${cat.label}',
                    selected: selected,
                    onTap: () => setState(() {
                      if (selected) {
                        _categories.remove(cat);
                      } else {
                        _categories.add(cat);
                      }
                    }),
                  );
                }),
              ],
            ).animate().fadeIn(delay: 150.ms),
            const Gap(20),

            const Text('Grouping',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const Gap(10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ExportGrouping.values.map((g) {
                return _ChoicePill(
                  label: _groupingLabel(g),
                  selected: _grouping == g,
                  onTap: () => setState(() => _grouping = g),
                );
              }).toList(),
            ).animate().fadeIn(delay: 175.ms),
            const Gap(20),

            const Text('Summary Layout',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const Gap(10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ExportSummaryLayout.values.map((s) {
                return _ChoicePill(
                  label: _summaryLabel(s),
                  selected: _summaryLayout == s,
                  onTap: () => setState(() => _summaryLayout = s),
                );
              }).toList(),
            ).animate().fadeIn(delay: 200.ms),
            const Gap(20),

            const Text('Brand Template',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const Gap(10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ExportBrandTemplate.values.map((t) {
                return _ChoicePill(
                  label: _templateLabel(t),
                  selected: _brandTemplate == t,
                  onTap: () => setState(() => _brandTemplate = t),
                );
              }).toList(),
            ).animate().fadeIn(delay: 225.ms),
            const Gap(20),

            const Text('Comparison',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const Gap(10),
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: R.s(12), vertical: R.s(10)),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: AppRadius.md,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cross-period comparison',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        SizedBox(height: 2),
                        Text('Include previous period delta in PDF',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _includeComparison,
                    activeThumbColor: AppColors.primary,
                    onChanged: _format == _ExportFormat.pdf
                        ? (v) => setState(() => _includeComparison = v)
                        : null,
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 250.ms),
            const Gap(20),

            // Count indicator
            Container(
              padding: EdgeInsets.all(R.s(14)),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: AppRadius.md,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                const Icon(Icons.receipt_long_rounded,
                    color: AppColors.primary, size: 20),
                const Gap(10),
                Text('$expCount transaction${expCount == 1 ? '' : 's'} found',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ]),
            ).animate().fadeIn(delay: 150.ms),

            const Gap(20),

            // Export button
            SizedBox(
              width: double.infinity,
              height: R.s(52),
              child: ElevatedButton.icon(
                onPressed: (_exporting || expCount == 0) ? null : _export,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.mdPlus),
                  elevation: 0,
                ),
                icon: _exporting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Icon(_format == _ExportFormat.csv
                        ? Icons.download_rounded
                        : Icons.picture_as_pdf_outlined),
                label: Text(
                  _exporting
                      ? 'Exporting...'
                      : 'Export as ${_format == _ExportFormat.csv ? 'CSV' : 'PDF'}',
                  style:
                      TextStyle(fontSize: R.t(15), fontWeight: FontWeight.w700),
                ),
              ),
            ).animate().fadeIn(delay: 200.ms),
          ]),
        ),
      ),
    );
  }

  String _groupingLabel(ExportGrouping value) => switch (value) {
        ExportGrouping.none => 'None',
        ExportGrouping.category => 'By Category',
        ExportGrouping.type => 'By Type',
        ExportGrouping.day => 'By Day',
      };

  String _summaryLabel(ExportSummaryLayout value) => switch (value) {
        ExportSummaryLayout.compact => 'Compact',
        ExportSummaryLayout.standard => 'Standard',
        ExportSummaryLayout.executive => 'Executive',
      };

  String _templateLabel(ExportBrandTemplate value) => switch (value) {
        ExportBrandTemplate.classic => 'Classic',
        ExportBrandTemplate.minimal => 'Minimal',
        ExportBrandTemplate.ledger => 'Ledger',
      };
}

class _DateTile extends StatelessWidget {
  final String label;
  final String date;
  final VoidCallback onTap;
  const _DateTile(
      {required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(R.s(14)),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: AppRadius.md,
            border: Border.all(color: AppColors.border),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    fontSize: R.t(11), color: AppColors.textTertiary)),
            const Gap(4),
            Text(date,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontSize: R.t(14))),
          ]),
        ),
      );
}

// Figma: Input/FormatChip
class _FormatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _FormatChip({
    required this.label,
    required this.icon,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: R.s(14), vertical: R.s(12)),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryExtraLight : Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.md,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Icon(icon,
              size: 20,
              color: selected ? AppColors.primary : AppColors.textSecondary),
          const Gap(10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: R.t(13),
                    color:
                        selected ? AppColors.primary : AppColors.textPrimary)),
            Text(subtitle,
                style: TextStyle(
                    fontSize: R.t(10), color: AppColors.textTertiary)),
          ]),
        ]),
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return InkWell(
      borderRadius: AppRadius.xl,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: R.s(12), vertical: R.s(8)),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryExtraLight : Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.xl,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: R.t(12),
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PresetChip({
    required this.label,
    required this.subtitle,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.card,
      onLongPress: onDelete,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: R.s(10), vertical: R.s(8)),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.card,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_outline_rounded,
                size: R.s(14), color: AppColors.textSecondary),
            const Gap(6),
            Text(
              label,
              style: TextStyle(
                fontSize: R.t(12),
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Gap(6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: R.t(10),
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
