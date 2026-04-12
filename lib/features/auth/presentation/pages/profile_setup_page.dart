import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/components/ds_async_state.dart';
import '../../../../core/design/components/ds_button.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/app_user.dart';
import '../providers/auth_provider.dart';
import '../providers/cloud_auth_provider.dart';

class ProfileSetupPage extends ConsumerStatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  ConsumerState<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends ConsumerState<ProfileSetupPage> {
  final _nameCtrl = TextEditingController();
  final _incomeCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _incomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final name = _nameCtrl.text.trim();
    final income = double.parse(_incomeCtrl.text.replaceAll(',', ''));

    // 1. Sync profile to cloud
    final ok = await ref.read(cloudAuthProvider.notifier).updateProfile(
          name: name,
          monthlyBudget: income,
        );

    if (!ok || !mounted) {
      setState(() => _isLoading = false);
      return;
    }

    // 2. Mark profile complete locally — router will redirect to pin-setup
    final user = AppUser(
      name: name,
      monthlyIncome: income,
      createdAt: DateTime.now(),
    );
    await ref.read(authStateProvider.notifier).completeProfile(user);
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colorScheme = Theme.of(context).colorScheme;
    final cloudState = ref.watch(cloudAuthProvider);
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: R.lg, vertical: R.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tell us about yourself',
                  style: TextStyle(
                    fontSize: R.t(28),
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
                SizedBox(height: R.sm),
                Text(
                  'This helps us personalize your financial dashboard.',
                  style: TextStyle(
                    fontSize: R.t(15),
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ).animate(delay: 80.ms).fadeIn(duration: 400.ms),
                SizedBox(height: R.sm),
                if (_isLoading)
                  const DSAsyncState.loading(
                    compact: true,
                    title: 'Saving profile...',
                  )
                else if (cloudState.error != null)
                  DSAsyncState.error(
                    compact: true,
                    title: 'Profile update failed',
                    message: cloudState.error,
                  ),
                SizedBox(height: R.s(36)),
                // Name field
                Text(
                  'YOUR NAME',
                  style: TextStyle(
                    fontSize: R.t(11),
                    fontWeight: FontWeight.w700,
                    color: colorScheme.outline,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: R.sm),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  validator: Validators.name,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(
                    fontSize: R.t(18),
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Arjun Sharma',
                    filled: true,
                    fillColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(R.s(14)),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(R.s(14)),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: R.md,
                      vertical: R.md,
                    ),
                  ),
                )
                    .animate(delay: 150.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.1, end: 0),
                SizedBox(height: R.s(28)),
                // Income field
                Text(
                  'MONTHLY INCOME (${CurrencyFormatter.symbol()})',
                  style: TextStyle(
                    fontSize: R.t(11),
                    fontWeight: FontWeight.w700,
                    color: colorScheme.outline,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: R.sm),
                TextFormField(
                  controller: _incomeCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: Validators.amount,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _continue(),
                  style: TextStyle(
                    fontSize: R.t(18),
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. 50000',
                    prefixText: '${CurrencyFormatter.symbol()} ',
                    prefixStyle: TextStyle(
                      fontSize: R.t(18),
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    filled: true,
                    fillColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(R.s(14)),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(R.s(14)),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: R.md,
                      vertical: R.md,
                    ),
                    helperText:
                        'Used to calculate your savings rate. Not shared.',
                    helperStyle: TextStyle(
                      fontSize: R.t(12),
                      color: colorScheme.outline,
                    ),
                  ),
                )
                    .animate(delay: 200.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.1, end: 0),
                SizedBox(height: R.s(48)),
                DSButton(
                  label: 'Continue',
                  onPressed: _isLoading ? null : _continue,
                  isLoading: _isLoading,
                  trailingIcon: const Icon(Icons.arrow_forward_rounded),
                )
                    .animate(delay: 300.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.1, end: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
