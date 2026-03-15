import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/components/ds_button.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/budget.dart';
import '../../presentation/providers/budget_provider.dart';
import '../../../expenses/domain/entities/expense_category.dart';

class AddBudgetPage extends ConsumerStatefulWidget {
  const AddBudgetPage({super.key});

  @override
  ConsumerState<AddBudgetPage> createState() => _AddBudgetPageState();
}

class _AddBudgetPageState extends ConsumerState<AddBudgetPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  ExpenseCategory? _selectedCategory;
  bool _carryForward = false;
  bool _isLoading = false;

  // Exclude 'other' and income-like categories for budgeting
  static const _budgetableCategories = [
    ExpenseCategory.food,
    ExpenseCategory.transport,
    ExpenseCategory.shopping,
    ExpenseCategory.entertainment,
    ExpenseCategory.bills,
    ExpenseCategory.health,
    ExpenseCategory.education,
    ExpenseCategory.travel,
    ExpenseCategory.groceries,
    ExpenseCategory.rent,
    ExpenseCategory.subscriptions,
    ExpenseCategory.other,
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }
    final state = ref.read(budgetProvider);

    setState(() => _isLoading = true);
    final budget = Budget(
      id: const Uuid().v4(),
      categoryKey: _selectedCategory!.key,
      allocatedAmount: double.parse(_amountCtrl.text.trim()),
      month: state.month,
      year: state.year,
      carryForward: _carryForward,
    );
    await ref.read(budgetProvider.notifier).addBudget(budget);
    if (mounted) {
      setState(() => _isLoading = false);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
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
            'Add Budget Envelope',
            style: TextStyle(
              fontSize: R.t(17),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        body: SingleChildScrollView(
            padding: EdgeInsets.all(R.s(20)),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Amount input
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: R.s(20), vertical: R.s(12)),
                        decoration: BoxDecoration(
                          color: AppColors.primaryExtraLight,
                          borderRadius: BorderRadius.circular(R.md),
                        ),
                        child: TextFormField(
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          autofocus: true,
                          style: TextStyle(
                            fontSize: R.t(36),
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                          decoration: InputDecoration(
                            prefixText: '₹ ',
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
                      SizedBox(height: R.lg),

                      Text(
                        'Category',
                        style: TextStyle(
                          fontSize: R.t(13),
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: R.s(10)),

                      // Category grid
                      GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: R.s(10),
                          mainAxisSpacing: R.s(10),
                          childAspectRatio: 1.2,
                        ),
                        itemCount: _budgetableCategories.length,
                        itemBuilder: (_, i) {
                          final cat = _budgetableCategories[i];
                          final selected = _selectedCategory == cat;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedCategory = cat),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: selected
                                    ? cat.color.withValues(alpha: 0.15)
                                    : AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(R.s(12)),
                                border: Border.all(
                                  color:
                                      selected ? cat.color : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    cat.emoji,
                                    style: TextStyle(fontSize: R.t(22)),
                                  ),
                                  SizedBox(height: R.xs),
                                  Text(
                                    cat.label,
                                    style: TextStyle(
                                      fontSize: R.t(10),
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? cat.color
                                          : AppColors.textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: R.s(20)),

                      // Carry forward toggle
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: R.md, vertical: R.s(12)),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(R.s(14)),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Carry forward',
                                    style: TextStyle(
                                      fontSize: R.t(14),
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Unspent amount rolls over next month',
                                    style: TextStyle(
                                      fontSize: R.t(12),
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _carryForward,
                              onChanged: (v) =>
                                  setState(() => _carryForward = v),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: R.xl),

                      DSButton(
                        label: 'Create Envelope',
                        onPressed: _save,
                        isLoading: _isLoading,
                        fullWidth: true,
                      ),
                    ],
                  ),
                ),
              ),
            )));
  }
}
