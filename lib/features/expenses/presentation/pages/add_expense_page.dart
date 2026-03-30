import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/components/ds_button.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../../../sync/presentation/providers/sync_provider.dart';
import '../providers/expense_provider.dart';
import '../widgets/category_picker_sheet.dart';
import '../widgets/recurring_section_widget.dart';

class AddExpensePage extends ConsumerStatefulWidget {
  const AddExpensePage({super.key});

  @override
  ConsumerState<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends ConsumerState<AddExpensePage> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.food;
  DateTime _date = DateTime.now();
  bool _isIncome = false;
  bool _isLoading = false;
  bool _isRecurring = false;
  RecurringFrequency _recurringFrequency = RecurringFrequency.monthly;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _pickCategory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategoryPickerSheet(
        selected: _category,
        onSelected: (cat) => setState(() => _category = cat),
      ),
    );
  }

  Future<void> _save() async {
    final amtError = Validators.amount(_amountCtrl.text);
    final descError = Validators.required(_descCtrl.text, 'Description');
    if (amtError != null || descError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(amtError ?? descError!)));
      return;
    }

    // Capture notifiers BEFORE any await — prevents "ref after widget disposed"
    final expenseNotifier = ref.read(expenseProvider.notifier);
    final syncNotifier = ref.read(syncProvider.notifier);

    setState(() => _isLoading = true);
    await expenseNotifier.addExpense(
      amount: double.parse(_amountCtrl.text.replaceAll(',', '')),
      description: _descCtrl.text.trim(),
      category: _category,
      date: _date,
      note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text.trim(),
      isIncome: _isIncome,
      isRecurring: _isRecurring,
      recurringFrequency: _isRecurring ? _recurringFrequency : null,
    );
    // Push to cloud immediately after local save (fire-and-forget)
    syncNotifier.sync();
    if (mounted) {
      setState(() => _isLoading = false);
      HapticFeedback.lightImpact();
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.pop(),
          ),
          title: const Text('Add Transaction'),
          actions: [
            Padding(
              padding: EdgeInsets.only(right: R.s(12)),
              child: TextButton(
                onPressed: _isLoading ? null : _save,
                child: Text(
                  'Save',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: R.t(16)),
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
            padding: EdgeInsets.all(R.s(20)),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Expense / Income toggle
                    Container(
                      padding: EdgeInsets.all(R.xs),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(R.s(12)),
                      ),
                      child: Row(
                        children: [
                          _TypeTab(
                            label: '💸  Expense',
                            selected: !_isIncome,
                            onTap: () => setState(() => _isIncome = false),
                          ),
                          _TypeTab(
                            label: '💰  Income',
                            selected: _isIncome,
                            onTap: () => setState(() => _isIncome = true),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 300.ms),
                    SizedBox(height: R.s(28)),
                    // Amount input (large)
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'AMOUNT',
                            style: TextStyle(
                              fontSize: R.t(11),
                              fontWeight: FontWeight.w700,
                              color: AppColors.textTertiary,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: R.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '₹',
                                style: TextStyle(
                                  fontSize: R.t(28),
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              SizedBox(width: R.xs),
                              IntrinsicWidth(
                                child: TextField(
                                  controller: _amountCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[\d.]')),
                                  ],
                                  autofocus: true,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: R.t(48),
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    height: 1.1,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '0',
                                    hintStyle: TextStyle(
                                      fontSize: R.t(48),
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textDisabled,
                                      height: 1.1,
                                    ),
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate(delay: 50.ms).fadeIn(duration: 300.ms),
                    SizedBox(height: R.xl),
                    const Divider(color: AppColors.border),
                    SizedBox(height: R.lg),
                    // Description
                    _fieldLabel('DESCRIPTION'),
                    SizedBox(height: R.sm),
                    TextField(
                      controller: _descCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      style: TextStyle(
                        fontSize: R.t(16),
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      decoration:
                          _fieldDecoration('e.g. Dinner at Mainland China'),
                    ).animate(delay: 100.ms).fadeIn(duration: 300.ms),
                    SizedBox(height: R.s(20)),
                    // Category
                    _fieldLabel('CATEGORY'),
                    SizedBox(height: R.sm),
                    GestureDetector(
                      onTap: _pickCategory,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: R.md,
                          vertical: R.s(14),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(R.s(14)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: R.s(36),
                              height: R.s(36),
                              decoration: BoxDecoration(
                                color: _category.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(R.sm),
                              ),
                              child: Center(
                                child: Text(
                                  _category.emoji,
                                  style: TextStyle(fontSize: R.t(18)),
                                ),
                              ),
                            ),
                            SizedBox(width: R.s(12)),
                            Expanded(
                              child: Text(
                                _category.label,
                                style: TextStyle(
                                  fontSize: R.t(15),
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textTertiary,
                            ),
                          ],
                        ),
                      ),
                    ).animate(delay: 150.ms).fadeIn(duration: 300.ms),
                    SizedBox(height: R.s(20)),
                    // Date
                    _fieldLabel('DATE'),
                    SizedBox(height: R.sm),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: R.md,
                          vertical: R.s(14),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(R.s(14)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: R.s(20),
                              color: AppColors.textTertiary,
                            ),
                            SizedBox(width: R.s(12)),
                            Expanded(
                              child: Text(
                                _date.relativeLabel == 'Today'
                                    ? 'Today, ${_date.formattedDate}'
                                    : _date.formattedDate,
                                style: TextStyle(
                                  fontSize: R.t(15),
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textTertiary,
                            ),
                          ],
                        ),
                      ),
                    ).animate(delay: 200.ms).fadeIn(duration: 300.ms),
                    SizedBox(height: R.s(20)),
                    // Note (optional)
                    _fieldLabel('NOTE (OPTIONAL)'),
                    SizedBox(height: R.sm),
                    TextField(
                      controller: _noteCtrl,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(
                        fontSize: R.t(15),
                        color: AppColors.textPrimary,
                      ),
                      decoration: _fieldDecoration('Add a note...'),
                    ).animate(delay: 250.ms).fadeIn(duration: 300.ms),
                    SizedBox(height: R.xl),
                    RecurringSectionWidget(
                      isRecurring: _isRecurring,
                      frequency: _recurringFrequency,
                      onToggle: (v) => setState(() {
                        _isRecurring = v;
                      }),
                      onFrequency: (f) =>
                          setState(() => _recurringFrequency = f),
                      delayMs: 275,
                    ),
                    SizedBox(height: R.xl),
                    DSButton(
                      label: _isLoading
                          ? 'Saving...'
                          : _isIncome
                              ? 'Add Income'
                              : 'Add Expense',
                      onPressed: _isLoading ? null : _save,
                      isLoading: _isLoading,
                    ).animate(delay: 320.ms).fadeIn(duration: 300.ms),
                    SizedBox(height: R.s(20)),
                  ],
                ),
              ),
            )));
  }

  Widget _fieldLabel(String label) => Text(
        label,
        style: TextStyle(
          fontSize: R.t(11),
          fontWeight: FontWeight.w700,
          color: AppColors.textTertiary,
          letterSpacing: 1.2,
        ),
      );

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(R.s(14)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(R.s(14)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(R.s(14)),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            EdgeInsets.symmetric(horizontal: R.md, vertical: R.s(14)),
      );
}

class _TypeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(vertical: R.s(10)),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(R.s(10)),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: R.xs,
                      offset: Offset(0, R.s(2)),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: R.t(14),
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.textPrimary : AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
