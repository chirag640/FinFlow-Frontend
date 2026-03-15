// Figma: Screen/CloudRegister
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../providers/cloud_auth_provider.dart';

import '../../../../core/ui/error_feedback.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});
  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final cloudNotifier = ref.read(cloudAuthProvider.notifier);
    await cloudNotifier.register(
      email: _emailCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      password: _passCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final authState = ref.watch(cloudAuthProvider);

    listenForProviderError(
      ref: ref,
      context: context,
      provider: cloudAuthProvider,
      errorSelector: (s) => s.error,
    );

    final screenWidth = MediaQuery.sizeOf(context).width;
    final hPad = screenWidth > 480 ? (screenWidth - 440) / 2 : 24.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
              hPad, 0, hPad, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Gap(16),
              Text('Create account',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      )).animate().fadeIn(),
              const Gap(4),
              Text('Back up and sync your finances to the cloud',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textSecondary))
                  .animate()
                  .fadeIn(delay: 80.ms),
              const Gap(32),
              Form(
                key: _formKey,
                child: Column(children: [
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDec('Email', Icons.email_outlined),
                    validator: (v) => v == null || !v.contains('@')
                        ? 'Enter a valid email'
                        : null,
                  ),
                  const Gap(12),
                  TextFormField(
                    controller: _usernameCtrl,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDec('Username',
                        Icons.person_outline_rounded),
                    validator: (v) {
                      if (v == null || v.trim().length < 3) {
                        return 'Min 3 characters';
                      }
                      if (!RegExp(r'^[a-z0-9_]+$').hasMatch(v.trim())) {
                        return 'Only lowercase letters, numbers, underscores';
                      }
                      return null;
                    },
                  ),
                  const Gap(12),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDec('Password (min 8 characters)',
                            Icons.lock_outline_rounded)
                        .copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.textTertiary,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => v == null || v.length < 8
                        ? 'Password must be 8+ characters'
                        : null,
                  ),
                  const Gap(12),
                  TextFormField(
                    controller: _confirmPassCtrl,
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _register(),
                    decoration: _inputDec(
                            'Confirm Password', Icons.lock_outline_rounded)
                        .copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.textTertiary,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (v) =>
                        v != _passCtrl.text ? 'Passwords do not match' : null,
                  ),
                ]),
              ).animate().fadeIn(delay: 200.ms),
              const Gap(8),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: R.xs),
                child: Text(
                  '🔒  Your data is end-to-end encrypted. We never sell your data.',
                  style: TextStyle(
                      fontSize: R.t(12), color: AppColors.textTertiary),
                ),
              ),
              const Gap(24),
              SizedBox(
                width: double.infinity,
                height: R.s(52),
                child: ElevatedButton(
                  onPressed: authState.isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(R.s(14))),
                    elevation: 0,
                  ),
                  child: authState.isLoading
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Create Account',
                          style: TextStyle(
                              fontSize: R.t(16), fontWeight: FontWeight.w700)),
                ),
              ).animate().fadeIn(delay: 300.ms),
              const Gap(20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('Already have an account? ',
                    style: TextStyle(color: AppColors.textSecondary)),
                GestureDetector(
                  onTap: () => context.pop(),
                  child: const Text('Sign in',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
              const Gap(32),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textTertiary, size: R.s(20)),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(R.s(12)),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(R.s(12)),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(R.s(12)),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      );
}
