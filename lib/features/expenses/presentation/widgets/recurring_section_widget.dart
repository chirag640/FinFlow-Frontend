// Figma: Component/RecurringSection
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../domain/entities/expense.dart';

class RecurringSectionWidget extends StatelessWidget {
  final bool isRecurring;
  final RecurringFrequency frequency;
  final ValueChanged<bool> onToggle;
  final ValueChanged<RecurringFrequency> onFrequency;
  final int delayMs;

  const RecurringSectionWidget({
    super.key,
    required this.isRecurring,
    required this.frequency,
    required this.onToggle,
    required this.onFrequency,
    this.delayMs = 275,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle row
        Container(
          padding: EdgeInsets.symmetric(horizontal: R.md, vertical: R.s(12)),
          decoration: BoxDecoration(
            color: isRecurring
                ? AppColors.primary.withValues(alpha: 0.08)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(R.s(14)),
            border: Border.all(
              color: isRecurring
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: R.s(36),
                height: R.s(36),
                decoration: BoxDecoration(
                  color: isRecurring
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.border,
                  borderRadius: BorderRadius.circular(R.s(10)),
                ),
                child: Center(
                  child: Icon(
                    Icons.repeat_rounded,
                    size: R.s(18),
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(width: R.s(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recurring',
                      style: TextStyle(
                        fontSize: R.t(14),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Repeat this automatically',
                      style: TextStyle(
                        fontSize: R.t(12),
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isRecurring,
                onChanged: onToggle,
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
        )
            .animate(delay: Duration(milliseconds: delayMs))
            .fadeIn(duration: 300.ms),

        // Frequency chips — visible only when recurring
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState: isRecurring
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Padding(
            padding: EdgeInsets.only(top: R.s(12)),
            child: Row(
              children: RecurringFrequency.values.map((f) {
                final selected = f == frequency;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: R.sm),
                    child: GestureDetector(
                      onTap: () => onFrequency(f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: EdgeInsets.symmetric(vertical: R.s(10)),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(R.s(10)),
                        ),
                        child: Text(
                          f.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: R.t(12),
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }
}
