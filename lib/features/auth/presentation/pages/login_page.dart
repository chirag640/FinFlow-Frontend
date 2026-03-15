// Figma: Screen/CloudLogin
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../providers/cloud_auth_provider.dart';
import '../../../sync/presentation/providers/sync_provider.dart';
import '../../../../core/ui/error_feedback.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final cloudNotifier = ref.read(cloudAuthProvider.notifier);
    final user = await cloudNotifier.login(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );
    // Success → sync and then go to dashboard.
    if (user != null && mounted) {
      await ref.read(syncProvider.notifier).sync();
      if (mounted) context.go(AppRoutes.dashboard);
    }
  }

  void _showError(String msg) {
    showErrorSnackBar(context, msg);
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
              // Logo
              Container(
                width: R.s(52),
                height: R.s(52),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(R.s(14)),
                ),
                child: Center(
                  child: Text('₹',
                      style: TextStyle(
                          fontSize: R.t(26),
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
              const Gap(20),
              Text('Welcome back',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      )).animate().fadeIn(delay: 100.ms),
              const Gap(4),
              Text('Sign in to sync your finances across devices',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      )).animate().fadeIn(delay: 150.ms),
              const Gap(36),
              // Email/Password form
              Form(
                key: _formKey,
                child: Column(children: [
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration('Email', Icons.email_outlined),
                    validator: (v) => v == null || !v.contains('@')
                        ? 'Enter a valid email'
                        : null,
                  ),
                  const Gap(12),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _login(),
                    decoration: _inputDecoration(
                      'Password',
                      Icons.lock_outline_rounded,
                    ).copyWith(
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
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Enter password' : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgotPassword,
                      child: const Text('Forgot password?'),
                    ),
                  ),
                ]),
              ).animate().fadeIn(delay: 200.ms),
              const Gap(24),
              SizedBox(
                width: double.infinity,
                height: R.s(52),
                child: ElevatedButton(
                  onPressed: authState.isLoading ? null : _login,
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
                      : Text('Sign In',
                          style: TextStyle(
                              fontSize: R.t(16), fontWeight: FontWeight.w700)),
                ),
              ).animate().fadeIn(delay: 250.ms),
              const Gap(20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text("Don't have an account? ",
                    style: TextStyle(color: AppColors.textSecondary)),
                GestureDetector(
                  onTap: () => context.push(AppRoutes.register),
                  child: const Text('Sign up',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ),
              ]).animate().fadeIn(delay: 300.ms),
              const Gap(32),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) =>
      InputDecoration(
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

  Future<void> _forgotPassword() async {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    bool loading = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Forgot Password'),
          content: TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'you@example.com',
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: loading
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim();
                      if (!email.contains('@')) {
                        _showError('Enter a valid email');
                        return;
                      }
                      setState(() => loading = true);
                      final ok = await ref
                          .read(cloudAuthProvider.notifier)
                          .forgotPassword(email);
                      if (!mounted) return;
                      setState(() => loading = false);
                      Navigator.pop(ctx);
                      if (ok) {
                        _showError('Reset code sent if this email exists.');
                        await _showResetPasswordDialog(email);
                      }
                    },
              child: loading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send Code'),
            ),
          ],
        ),
      ),
    );

    emailCtrl.dispose();
  }

  Future<void> _showResetPasswordDialog(String email) async {
    final codeCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool loading = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Reset Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '6-digit code',
                ),
              ),
              const Gap(12),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: loading
                  ? null
                  : () async {
                      final code = codeCtrl.text.trim();
                      final password = passCtrl.text;
                      if (code.length != 6) {
                        _showError('Enter the 6-digit code');
                        return;
                      }
                      if (password.length < 8) {
                        _showError('Password must be 8+ characters');
                        return;
                      }
                      setState(() => loading = true);
                      final ok = await ref
                          .read(cloudAuthProvider.notifier)
                          .resetPassword(
                            email: email,
                            code: code,
                            newPassword: password,
                          );
                      if (!mounted) return;
                      setState(() => loading = false);
                      if (ok) {
                        Navigator.pop(ctx);
                        _showError(
                            'Password reset successful. Please sign in.');
                      }
                    },
              child: loading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Reset'),
            ),
          ],
        ),
      ),
    );

    codeCtrl.dispose();
    passCtrl.dispose();
  }
}
