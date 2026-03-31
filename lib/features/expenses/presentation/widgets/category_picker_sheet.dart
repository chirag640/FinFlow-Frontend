import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/utils/responsive.dart';
import '../../domain/entities/expense_category.dart';

class CategoryPickerSheet extends StatelessWidget {
  final ExpenseCategory selected;
  final ValueChanged<ExpenseCategory> onSelected;

  const CategoryPickerSheet({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.8,
      builder: (context, scrollCtrl) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(R.s(20), R.xs, R.s(20), R.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Category',
                  style: TextStyle(
                    fontSize: R.t(18),
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              controller: scrollCtrl,
              padding: EdgeInsets.symmetric(horizontal: R.s(20)),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: R.s(10),
                mainAxisSpacing: R.s(10),
                childAspectRatio: 1.1,
              ),
              itemCount: ExpenseCategory.values.length,
              itemBuilder: (context, i) {
                final cat = ExpenseCategory.values[i];
                final isSelected = cat == selected;

                return GestureDetector(
                  onTap: () {
                    onSelected(cat);
                    Navigator.of(context).pop();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? cat.color.withValues(alpha: 0.15)
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(R.s(14)),
                      border: Border.all(
                        color:
                            isSelected ? cat.color : colorScheme.outlineVariant,
                        width: isSelected ? R.s(2) : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          cat.emoji,
                          style: TextStyle(fontSize: R.t(28)),
                        ),
                        SizedBox(height: R.xs),
                        Text(
                          cat.label.split(' ').take(2).join(' '),
                          style: TextStyle(
                            fontSize: R.t(10),
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? cat.color
                                : colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                )
                    .animate(delay: Duration(milliseconds: 30 * i))
                    .fadeIn(duration: 250.ms)
                    .scale(begin: const Offset(0.9, 0.9), duration: 250.ms);
              },
            ),
          ),
        ],
      ),
    );
  }
}
