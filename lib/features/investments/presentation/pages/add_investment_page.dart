// Figma: Screen/AddInvestment
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../domain/entities/investment.dart';
import '../providers/investment_provider.dart';

class AddInvestmentPage extends ConsumerStatefulWidget {
  /// Pass existing investment for edit mode
  final Investment? existing;
  const AddInvestmentPage({super.key, this.existing});

  @override
  ConsumerState<AddInvestmentPage> createState() => _AddInvestmentPageState();
}

class _AddInvestmentPageState extends ConsumerState<AddInvestmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _dateFmt = DateFormat('dd MMM yyyy');

  late InvestmentType _type;
  late TextEditingController _name;
  late TextEditingController _invested;
  late TextEditingController _currentValue;
  late TextEditingController _interestRate;
  late TextEditingController _quantity;
  late TextEditingController _currentPrice;
  late TextEditingController _notes;
  late DateTime _startDate;
  DateTime? _maturityDate;
  bool _isSaving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? InvestmentType.mutualFund;
    _name = TextEditingController(text: e?.name ?? '');
    _invested = TextEditingController(
        text: e == null ? '' : e.investedAmount.toString());
    _currentValue =
        TextEditingController(text: e == null ? '' : e.currentValue.toString());
    _interestRate = TextEditingController(
        text: e?.interestRate == null ? '' : e!.interestRate.toString());
    _quantity = TextEditingController(
        text: e?.quantity == null ? '' : e!.quantity.toString());
    _currentPrice = TextEditingController(
        text: e?.currentPrice == null ? '' : e!.currentPrice.toString());
    _notes = TextEditingController(text: e?.notes ?? '');
    _startDate = e?.startDate ?? DateTime.now();
    _maturityDate = e?.maturityDate;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _invested,
      _currentValue,
      _interestRate,
      _quantity,
      _currentPrice,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_maturityDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _maturityDate = picked;
      }
    });
  }

  void _onQuantityOrPriceChanged() {
    // Auto-compute current value from quantity × current price
    final qty = double.tryParse(_quantity.text);
    final price = double.tryParse(_currentPrice.text);
    if (qty != null && price != null) {
      _currentValue.text = (qty * price).toStringAsFixed(2);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(investmentsProvider.notifier);
      final inv = notifier.buildNew(
        type: _type,
        name: _name.text.trim(),
        investedAmount: double.parse(_invested.text),
        currentValue: double.parse(_currentValue.text),
        startDate: _startDate,
        maturityDate: _maturityDate,
        interestRate: double.tryParse(_interestRate.text),
        quantity: double.tryParse(_quantity.text),
        currentPrice: double.tryParse(_currentPrice.text),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );

      if (_isEdit) {
        await notifier.update(
          widget.existing!.copyWith(
            type: _type,
            name: inv.name,
            investedAmount: inv.investedAmount,
            currentValue: inv.currentValue,
            startDate: inv.startDate,
            maturityDate: _maturityDate,
            clearMaturity: _maturityDate == null,
            interestRate: inv.interestRate,
            quantity: inv.quantity,
            currentPrice: inv.currentPrice,
            notes: inv.notes,
          ),
        );
      } else {
        await notifier.add(inv);
      }
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text(
          _isEdit ? 'Edit Investment' : 'Add Investment',
          style: TextStyle(
            fontSize: R.t(18),
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
        actions: [
          if (_isSaving)
            Padding(
              padding: EdgeInsets.only(right: R.md),
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(
                _isEdit ? 'Update' : 'Save',
                style: TextStyle(
                  fontSize: R.t(15),
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(R.s(16)),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Type selector ───────────────────────────────────────────
              _SectionLabel('Investment Type'),
              SizedBox(height: R.sm),
              Wrap(
                spacing: R.sm,
                runSpacing: R.sm,
                children: InvestmentType.values.map((t) {
                  final selected = t == _type;
                  return GestureDetector(
                    onTap: () => setState(() => _type = t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: EdgeInsets.symmetric(
                          horizontal: R.s(12), vertical: R.s(8)),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(R.s(10)),
                        border: Border.all(
                          color:
                              selected ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(t.emoji, style: TextStyle(fontSize: R.t(15))),
                          SizedBox(width: R.xs),
                          Text(
                            t.label,
                            style: TextStyle(
                              fontSize: R.t(12),
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: R.s(20)),

              // ── Name ────────────────────────────────────────────────────
              _SectionLabel('Name'),
              SizedBox(height: R.sm),
              _Field(
                controller: _name,
                hint: _nameHint(_type),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              SizedBox(height: R.s(16)),

              // ── Invested amount ──────────────────────────────────────────
              _SectionLabel(_type == InvestmentType.recurringDeposit
                  ? 'Monthly Amount (₹)'
                  : 'Invested Amount (₹)'),
              SizedBox(height: R.sm),
              _Field(
                controller: _invested,
                hint: '50000',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
                ],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (double.tryParse(v) == null) return 'Invalid number';
                  if (double.parse(v) <= 0) return 'Must be > 0';
                  return null;
                },
              ),
              SizedBox(height: R.s(16)),

              // ── Type-specific fields ─────────────────────────────────────
              if (_showQuantity(_type)) ...[
                _SectionLabel(_quantityLabel(_type)),
                SizedBox(height: R.sm),
                _Field(
                  controller: _quantity,
                  hint: _quantityHint(_type),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,4}'))
                  ],
                  onChanged: (_) => _onQuantityOrPriceChanged(),
                ),
                SizedBox(height: R.s(16)),
                _SectionLabel(_currentPriceLabel(_type)),
                SizedBox(height: R.sm),
                _Field(
                  controller: _currentPrice,
                  hint: _currentPriceHint(_type),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
                  ],
                  onChanged: (_) => _onQuantityOrPriceChanged(),
                ),
                SizedBox(height: R.s(16)),
              ],

              if (_showInterestRate(_type)) ...[
                _SectionLabel('Annual Interest Rate (%)'),
                SizedBox(height: R.sm),
                _Field(
                  controller: _interestRate,
                  hint: '7.50',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
                  ],
                ),
                SizedBox(height: R.s(16)),
              ],

              // ── Current value ────────────────────────────────────────────
              _SectionLabel('Current Value (₹)'),
              SizedBox(height: R.sm),
              _Field(
                controller: _currentValue,
                hint: '58000',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
                ],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (double.tryParse(v) == null) return 'Invalid number';
                  if (double.parse(v) < 0) return 'Must be ≥ 0';
                  return null;
                },
              ),
              SizedBox(height: R.s(16)),

              // ── Dates ────────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel('Start Date'),
                        SizedBox(height: R.sm),
                        _DateTile(
                          label: _dateFmt.format(_startDate),
                          onTap: () => _pickDate(isStart: true),
                        ),
                      ],
                    ),
                  ),
                  if (_showMaturityDate(_type)) ...[
                    SizedBox(width: R.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel('Maturity Date'),
                          SizedBox(height: R.sm),
                          _DateTile(
                            label: _maturityDate == null
                                ? 'Pick date'
                                : _dateFmt.format(_maturityDate!),
                            onTap: () => _pickDate(isStart: false),
                            isEmpty: _maturityDate == null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: R.s(16)),

              // ── Notes ────────────────────────────────────────────────────
              _SectionLabel('Notes (optional)'),
              SizedBox(height: R.sm),
              _Field(
                controller: _notes,
                hint: 'e.g. SIP of ₹5000/month',
                maxLines: 3,
              ),
              SizedBox(height: R.s(80)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  bool _showQuantity(InvestmentType t) =>
      t == InvestmentType.mutualFund ||
      t == InvestmentType.gold ||
      t == InvestmentType.stock;

  bool _showInterestRate(InvestmentType t) =>
      t == InvestmentType.fixedDeposit || t == InvestmentType.recurringDeposit;

  bool _showMaturityDate(InvestmentType t) =>
      t == InvestmentType.fixedDeposit || t == InvestmentType.recurringDeposit;

  String _nameHint(InvestmentType t) => switch (t) {
        InvestmentType.mutualFund => 'e.g. Axis Bluechip Fund',
        InvestmentType.fixedDeposit => 'e.g. SBI FD',
        InvestmentType.recurringDeposit => 'e.g. HDFC RD',
        InvestmentType.gold => 'e.g. Gold SGB 2023',
        InvestmentType.realEstate => 'e.g. Flat in Mumbai',
        InvestmentType.stock => 'e.g. HDFC Bank',
      };

  String _quantityLabel(InvestmentType t) => switch (t) {
        InvestmentType.gold => 'Weight (grams)',
        InvestmentType.stock => 'Shares',
        _ => 'Units held',
      };

  String _quantityHint(InvestmentType t) => switch (t) {
        InvestmentType.gold => '10.5',
        InvestmentType.stock => '50',
        _ => '150.25',
      };

  String _currentPriceLabel(InvestmentType t) => switch (t) {
        InvestmentType.gold => 'Current Gold Rate (₹/gram)',
        InvestmentType.stock => 'Current Price (₹/share)',
        _ => 'Current NAV (₹/unit)',
      };

  String _currentPriceHint(InvestmentType t) => switch (t) {
        InvestmentType.gold => '6800',
        InvestmentType.stock => '1480',
        _ => '385.50',
      };
}

// ── Shared Widgets ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: R.t(12),
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      maxLines: maxLines,
      onChanged: onChanged,
      style: TextStyle(
        fontSize: R.t(14),
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: R.t(14), color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            EdgeInsets.symmetric(horizontal: R.s(14), vertical: R.s(12)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(R.s(10)),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(R.s(10)),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(R.s(10)),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(R.s(10)),
          borderSide: const BorderSide(color: AppColors.expense),
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isEmpty;
  const _DateTile({
    required this.label,
    required this.onTap,
    this.isEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: R.s(14), vertical: R.s(12)),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(R.s(10)),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: R.s(16), color: AppColors.textTertiary),
            SizedBox(width: R.sm),
            Text(
              label,
              style: TextStyle(
                fontSize: R.t(13),
                color: isEmpty ? AppColors.textTertiary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
