import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/components/ds_button.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/responsive.dart';

class AuthLandingPage extends StatelessWidget {
  const AuthLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLow,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: R.s(28)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 2),
                  // Logo mark
                  Container(
                    width: R.s(64),
                    height: R.s(64),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(R.s(18)),
                    ),
                    child: Center(
                      child: Text(
                        '₹',
                        style: TextStyle(
                          fontSize: R.t(32),
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ).animate().scale(
                        begin: const Offset(0.5, 0.5),
                        duration: 600.ms,
                        curve: Curves.elasticOut,
                      ),
                  SizedBox(height: R.xl),
                  // Headline
                  Text(
                    'FinFlow',
                    style: TextStyle(
                      fontSize: R.t(42),
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -1.5,
                      height: 1.1,
                    ),
                  ).animate(delay: 150.ms).fadeIn(duration: 500.ms).slideY(
                        begin: 0.3,
                        end: 0,
                        duration: 500.ms,
                        curve: Curves.easeOut,
                      ),
                  SizedBox(height: R.sm + R.xs),
                  Text(
                    'Your all-in-one\nfinancial operating system.',
                    style: TextStyle(
                      fontSize: R.t(20),
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  )
                      .animate(delay: 250.ms)
                      .fadeIn(duration: 500.ms)
                      .slideY(begin: 0.2, end: 0, duration: 500.ms),
                  const Spacer(flex: 3),
                  // Feature pills
                  Wrap(
                    spacing: R.sm,
                    runSpacing: R.sm,
                    children: [
                      _FeaturePill('💸 Expense Tracking'),
                      _FeaturePill('👥 Group Splits'),
                      _FeaturePill('🎯 Budget Envelopes'),
                      _FeaturePill('📊 Smart Analytics'),
                    ]
                        .animate(interval: 60.ms)
                        .fadeIn(delay: 400.ms, duration: 400.ms)
                        .slideX(begin: -0.1, end: 0),
                  ),
                  const Spacer(flex: 4),
                  // CTA
                  DSButton(
                    label: 'Create Account',
                    onPressed: () => context.push(AppRoutes.register),
                    trailingIcon: const Icon(Icons.arrow_forward_rounded),
                  )
                      .animate(delay: 600.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.2, end: 0),
                  SizedBox(height: R.sm + R.xs),
                  Center(
                    child: TextButton(
                      onPressed: () => context.push(AppRoutes.login),
                      child: RichText(
                        text: TextSpan(
                          text: 'Already have an account? ',
                          style: TextStyle(
                              fontSize: R.t(13),
                              color: AppColors.textSecondary),
                          children: const [
                            TextSpan(
                              text: 'Sign in',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate(delay: 700.ms).fadeIn(duration: 400.ms),
                  SizedBox(height: R.xs),
                  Center(
                    child: Text(
                      'Your data is encrypted and synced securely.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: R.t(12), color: AppColors.textTertiary),
                    ),
                  ).animate(delay: 750.ms).fadeIn(duration: 400.ms),
                  SizedBox(height: R.md),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final String label;
  const _FeaturePill(this.label);

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: R.sm + R.xs, vertical: R.s(7)),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: R.t(13),
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
