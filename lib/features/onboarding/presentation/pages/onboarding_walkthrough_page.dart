import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/router/app_router.dart';

class OnboardingWalkthroughPage extends ConsumerStatefulWidget {
  const OnboardingWalkthroughPage({super.key});

  @override
  ConsumerState<OnboardingWalkthroughPage> createState() =>
      _OnboardingWalkthroughPageState();
}

class _OnboardingWalkthroughPageState
    extends ConsumerState<OnboardingWalkthroughPage> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _completeAndExit({required bool isReplay}) async {
    await ref.read(settingsProvider.notifier).markOnboardingCompleted();
    if (!mounted) return;

    if (isReplay && context.canPop()) {
      context.pop();
      return;
    }

    context.go(AppRoutes.dashboard);
  }

  void _goNext() {
    if (_index >= _walkthroughSteps.length - 1) return;
    _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _goBack() {
    if (_index <= 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isReplay =
        GoRouterState.of(context).uri.queryParameters['replay'] == '1';
    final isLast = _index == _walkthroughSteps.length - 1;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            children: [
              Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: () => _completeAndExit(isReplay: isReplay),
                    child: Text(isReplay ? 'Close' : 'Skip'),
                  ),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _walkthroughSteps.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, i) {
                    final step = _walkthroughSteps[i];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            border: Border.all(
                              color: step.color.withValues(alpha: 0.28),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                step.color.withValues(alpha: 0.2),
                                step.color.withValues(alpha: 0.06),
                              ],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.lg),
                                ),
                                child: Icon(
                                  step.icon,
                                  color: step.color,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                step.title,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                step.description,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'What you can do here',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...step.points.map(
                          (point) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                    color: step.color,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    point,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_walkthroughSteps.length, (i) {
                  final selected = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: selected ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_index > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _goBack,
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: isLast
                          ? () => _completeAndExit(isReplay: isReplay)
                          : _goNext,
                      child: Text(isLast ? 'Finish Tour' : 'Next'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalkthroughStep {
  final String title;
  final String description;
  final List<String> points;
  final IconData icon;
  final Color color;

  const _WalkthroughStep({
    required this.title,
    required this.description,
    required this.points,
    required this.icon,
    required this.color,
  });
}

const List<_WalkthroughStep> _walkthroughSteps = [
  _WalkthroughStep(
    title: 'Track Money Daily',
    description:
        'Capture expenses quickly, keep categories clean, and stay current without waiting for cloud sync.',
    points: [
      'Add, edit, and review expenses with recurring support.',
      'Use monthly filters, search, and quick add flows.',
      'Stay productive even offline with local-first storage.',
    ],
    icon: Icons.receipt_long_rounded,
    color: AppColors.primary,
  ),
  _WalkthroughStep(
    title: 'Plan With Budgets',
    description:
        'Set category limits and detect pressure early so surprises become rare.',
    points: [
      'Create monthly budgets with progress visibility.',
      'Use carry-forward and copy-from-last-month shortcuts.',
      'Get budget-aware signals from dashboard summaries.',
    ],
    icon: Icons.account_balance_wallet_rounded,
    color: AppColors.warning,
  ),
  _WalkthroughStep(
    title: 'Split Group Expenses Clearly',
    description:
        'Manage shared spend, settle balances, and keep transparent records with audit support.',
    points: [
      'Track member-level shares for each group expense.',
      'Settle dues and review settlement audit timelines.',
      'Raise and resolve disputes with owner controls.',
    ],
    icon: Icons.group_rounded,
    color: AppColors.accent,
  ),
  _WalkthroughStep(
    title: 'Sync And Protect Data',
    description:
        'Use cloud sync for continuity while keeping device-level privacy and control.',
    points: [
      'Sync data across devices with conflict management.',
      'Enable privacy mode to mask values across the app.',
      'Use PIN and optional biometric unlock for local security.',
    ],
    icon: Icons.cloud_done_rounded,
    color: AppColors.success,
  ),
];
