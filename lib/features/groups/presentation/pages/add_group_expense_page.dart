import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/components/ds_button.dart';
import '../../../../core/design/components/ds_text_field.dart';
import '../../../../core/ui/error_feedback.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/group_expense.dart';
import '../providers/group_provider.dart';
import '../../domain/entities/group.dart';

class AddGroupExpensePage extends ConsumerStatefulWidget {
  final String groupId;
  const AddGroupExpensePage({super.key, required this.groupId});

  @override
  ConsumerState<AddGroupExpensePage> createState() =>
      _AddGroupExpensePageState();
}

class _AddGroupExpensePageState extends ConsumerState<AddGroupExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _paidByMemberId;
  SplitType _splitType = SplitType.equal;
  final Map<String, TextEditingController> _customControllers = {};
  bool _isLoading = false;

  Group get _group {
    final gs = ref.read(groupProvider);
    return gs.groups.firstWhere(
      (g) => g.id == widget.groupId,
      orElse: () => Group(
        id: widget.groupId,
        name: '',
        emoji: '👥',
        members: [],
        currentUserId: '',
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final group = _group;
      if (group.members.isNotEmpty) {
        setState(() {
          _paidByMemberId = group.currentUserId;
          for (final m in group.members) {
            _customControllers[m.id] = TextEditingController();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    for (final c in _customControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_paidByMemberId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select who paid')));
      return;
    }
    final group = _group;
    final amount = double.parse(_amountCtrl.text.trim());
    List<SplitShare> shares;

    if (_splitType == SplitType.equal) {
      final each = amount / group.members.length;
      shares = group.members
          .map((m) => SplitShare(memberId: m.id, amount: each))
          .toList();
    } else if (_splitType == SplitType.custom) {
      shares = group.members.map((m) {
        final v = double.tryParse(_customControllers[m.id]?.text ?? '0') ?? 0;
        return SplitShare(memberId: m.id, amount: v);
      }).toList();
      final total = shares.fold(0.0, (s, x) => s + x.amount);
      if ((total - amount).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Custom amounts must sum to total')));
        return;
      }
    } else if (_splitType == SplitType.percentage) {
      // percentage
      shares = group.members.map((m) {
        final pct = double.tryParse(_customControllers[m.id]?.text ?? '0') ?? 0;
        return SplitShare(memberId: m.id, amount: amount * pct / 100);
      }).toList();
      final totalPct = group.members.fold(
          0.0,
          (s, m) =>
              s +
              (double.tryParse(_customControllers[m.id]?.text ?? '0') ?? 0));
      if ((totalPct - 100).abs() > 0.1) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Percentages must sum to 100%')));
        return;
      }
    } else {
      // incomeRatio — split proportionally by each member's monthly income
      final incomes = group.members
          .map((m) =>
              double.tryParse(_customControllers[m.id]?.text ?? '0') ?? 0.0)
          .toList();
      final totalIncome = incomes.fold(0.0, (s, v) => s + v);
      if (totalIncome <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Enter monthly income for at least one member')));
        return;
      }
      shares = group.members.asMap().entries.map((e) {
        return SplitShare(
          memberId: e.value.id,
          amount: amount * incomes[e.key] / totalIncome,
        );
      }).toList();
    }

    setState(() => _isLoading = true);
    await ref.read(groupExpenseProvider(widget.groupId).notifier).addExpense(
          amount: amount,
          description: _descCtrl.text.trim(),
          paidByMemberId: _paidByMemberId!,
          splitType: _splitType,
          shares: shares,
          date: DateTime.now(),
        );
    if (mounted) {
      setState(() => _isLoading = false);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    listenForProviderError<GroupExpenseState>(
      ref: ref,
      context: context,
      provider: groupExpenseProvider(widget.groupId),
      errorSelector: (s) => s.error,
      onErrorShown: () {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      },
    );
    final group = _group;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Add Group Expense',
          style: TextStyle(
              fontSize: R.t(17),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(R.s(20)),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: R.s(20), vertical: R.s(12)),
                decoration: BoxDecoration(
                  color: AppColors.primaryExtraLight,
                  borderRadius: BorderRadius.circular(R.md),
                ),
                child: TextFormField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    fontSize: R.t(36),
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                  decoration: InputDecoration(
                    prefixText: '\u20b9 ',
                    prefixStyle: TextStyle(
                      fontSize: R.t(36),
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                    hintText: '0',
                    hintStyle: TextStyle(
                      fontSize: R.t(36),
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryLight,
                    ),
                    border: InputBorder.none,
                  ),
                  validator: Validators.amount,
                ),
              ),
              SizedBox(height: R.s(20)),

              // Description
              DSTextField(
                controller: _descCtrl,
                label: 'Description',
                hint: 'e.g., Dinner at restaurant',
                prefixIcon: const Icon(Icons.description_outlined),
              ),
              SizedBox(height: R.s(20)),

              // Paid By
              Text(
                'Paid By',
                style: TextStyle(
                    fontSize: R.t(13),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary),
              ),
              SizedBox(height: R.s(10)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: group.members.map((m) {
                  final selected = _paidByMemberId == m.id;
                  return GestureDetector(
                    onTap: () => setState(() => _paidByMemberId = m.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                          horizontal: R.md, vertical: R.sm),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(R.s(24)),
                        border: Border.all(
                          color:
                              selected ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      child: Text(
                        m.name,
                        style: TextStyle(
                          fontSize: R.t(13),
                          fontWeight: FontWeight.w600,
                          color:
                              selected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: R.s(20)),

              // Split Type
              Text(
                'How to Split',
                style: TextStyle(
                    fontSize: R.t(13),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary),
              ),
              SizedBox(height: R.s(10)),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(R.s(12)),
                ),
                child: Row(
                  children: SplitType.values.map((st) {
                    final selected = _splitType == st;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _splitType = st),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(vertical: R.s(10)),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(R.s(12)),
                          ),
                          child: Text(
                            st.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: R.t(13),
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Custom/Percentage inputs
              if (_splitType != SplitType.equal) ...[
                SizedBox(height: R.s(16)),
                if (_splitType == SplitType.incomeRatio)
                  Padding(
                    padding: EdgeInsets.only(bottom: R.s(8)),
                    child: Text(
                      'Enter each member\'s monthly income. Expense is split proportionally.',
                      style: TextStyle(
                          fontSize: R.t(12), color: AppColors.textTertiary),
                    ),
                  ),
                ...group.members.map((m) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: R.s(10)),
                    child: Row(
                      children: [
                        Container(
                          width: R.s(36),
                          height: R.s(36),
                          decoration: BoxDecoration(
                            color: AppColors.primaryExtraLight,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              m.name[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: R.t(14),
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: R.s(10)),
                        Expanded(
                          child: Text(
                            m.name,
                            style: TextStyle(
                              fontSize: R.t(14),
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: TextFormField(
                            controller: _customControllers[m.id],
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: R.t(15),
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              prefixText: (_splitType == SplitType.custom ||
                                      _splitType == SplitType.incomeRatio)
                                  ? '\u20b9 '
                                  : null,
                              suffixText: _splitType == SplitType.percentage
                                  ? '%'
                                  : null,
                              filled: true,
                              fillColor: AppColors.surfaceVariant,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(R.s(10)),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: R.s(12), vertical: R.s(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              SizedBox(height: R.s(32)),

              DSButton(
                label: 'Add Expense',
                onPressed: _save,
                isLoading: _isLoading,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on SplitType {
  String get label => switch (this) {
        SplitType.equal => 'Equal',
        SplitType.custom => 'Custom',
        SplitType.percentage => 'Percent',
        SplitType.incomeRatio => 'Income',
      };
}
