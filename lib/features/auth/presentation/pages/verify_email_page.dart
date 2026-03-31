// Figma: Screen/VerifyEmail
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../providers/cloud_auth_provider.dart';

class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  final List<TextEditingController> _digits =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focuses = List.generate(6, (_) => FocusNode());

  bool _verifying = false;
  int _resendCooldown = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    for (final c in _digits) {
      c.dispose();
    }
    for (final f in _focuses) {
      f.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  String get _code => _digits.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // Handle paste: distribute characters across fields
      final chars = value.replaceAll(RegExp(r'\D'), '').split('');
      for (var i = 0; i < chars.length && (index + i) < 6; i++) {
        _digits[index + i].text = chars[i];
      }
      final next = (index + chars.length).clamp(0, 5);
      _focuses[next].requestFocus();
      setState(() {});
      return;
    }

    if (value.isNotEmpty && index < 5) {
      _focuses[index + 1].requestFocus();
    }
    setState(() {});
  }

  void _onDigitKeyDown(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _digits[index].text.isEmpty &&
        index > 0) {
      _focuses[index - 1].requestFocus();
      _digits[index - 1].clear();
    }
  }

  Future<void> _verify() async {
    final code = _code;
    if (code.length < 6) {
      _showSnack('Enter the 6-digit code sent to your email', isError: true);
      return;
    }

    final cloudState = ref.read(cloudAuthProvider);
    final userId = cloudState.pendingVerificationUserId;
    if (userId == null) return;

    setState(() => _verifying = true);
    final cloudUser =
        await ref.read(cloudAuthProvider.notifier).verifyEmail(userId, code);
    if (!mounted) return;
    setState(() => _verifying = false);

    if (cloudUser != null) {
      _showSnack('Email verified! Welcome to FinFlow 🎉');
      context.go(AppRoutes.dashboard);
    }
    // Error shown by ref.listen below
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0) return;
    final cloudState = ref.read(cloudAuthProvider);
    final userId = cloudState.pendingVerificationUserId;
    if (userId == null) return;

    final ok = await ref.read(cloudAuthProvider.notifier).resendOtp(userId);
    if (!mounted) return;
    if (ok) {
      _showSnack('A new code has been sent to your email');
      _startResendTimer();
    }
  }

  void _startResendTimer() {
    setState(() => _resendCooldown = 60);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_resendCooldown > 0) {
          _resendCooldown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.isEmpty) return email;
    final visible = name.length > 2 ? name.substring(0, 2) : name[0];
    return '$visible${'*' * (name.length - visible.length)}@$domain';
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final cloudState = ref.watch(cloudAuthProvider);

    ref.listen(cloudAuthProvider, (_, next) {
      if (next.error != null) {
        _showSnack(next.error!, isError: true);
      }
    });

    final email = cloudState.pendingVerificationEmail ?? '';
    final maskedEmail = email.isNotEmpty ? _maskEmail(email) : 'your email';
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth > 480;
    final hPad = isWide ? (screenWidth - 440) / 2 : 24.0;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back_ios_rounded, color: colorScheme.onSurface),
          onPressed: () {
            // Clear pending verification state and go back to auth landing
            ref.read(cloudAuthProvider.notifier).logout();
            context.go(AppRoutes.authLanding);
          },
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
              const Gap(8),
              // Icon
              Container(
                width: R.s(64),
                height: R.s(64),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(R.s(18)),
                ),
                child: Center(
                  child: Icon(Icons.mark_email_unread_rounded,
                      size: R.s(32), color: AppColors.primary),
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scale(begin: const Offset(0.8, 0.8)),
              const Gap(20),
              Text(
                'Check your email',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
              ).animate().fadeIn(delay: 100.ms),
              const Gap(6),
              RichText(
                text: TextSpan(
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                  children: [
                    const TextSpan(text: 'We sent a 6-digit code to '),
                    TextSpan(
                      text: maskedEmail,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 150.ms),
              const Gap(36),
              // 6-digit OTP fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _buildDigitField(i)),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
              const Gap(36),
              // Verify button
              SizedBox(
                width: double.infinity,
                height: R.s(52),
                child: ElevatedButton(
                  onPressed:
                      (_verifying || cloudState.isLoading) ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(R.s(14))),
                    elevation: 0,
                  ),
                  child: (_verifying || cloudState.isLoading)
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('Verify Email',
                          style: TextStyle(
                              fontSize: R.t(16), fontWeight: FontWeight.w700)),
                ),
              ).animate().fadeIn(delay: 250.ms),
              const Gap(20),
              // Resend button
              Center(
                child: TextButton(
                  onPressed: _resendCooldown > 0 ? null : _resend,
                  child: _resendCooldown > 0
                      ? Text(
                          'Resend in ${_resendCooldown}s',
                          style: const TextStyle(color: AppColors.textTertiary),
                        )
                      : const Text(
                          "Didn't receive the code?  Resend",
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600),
                        ),
                ),
              ).animate().fadeIn(delay: 300.ms),
              const Gap(12),
              Center(
                child: Text(
                  'Check your spam folder if you don\'t see the email.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                  textAlign: TextAlign.center,
                ),
              ).animate().fadeIn(delay: 350.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDigitField(int index) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final fieldSize = ((screenWidth - 48 - 5 * 8) / 6).clamp(46.0, 58.0);

    return SizedBox(
      width: fieldSize,
      height: fieldSize,
      child: Focus(
        onKeyEvent: (_, e) {
          _onDigitKeyDown(index, e);
          return KeyEventResult.ignored;
        },
        child: TextFormField(
          controller: _digits[index],
          focusNode: _focuses[index],
          keyboardType: TextInputType.number,
          textInputAction:
              index == 5 ? TextInputAction.done : TextInputAction.next,
          autofillHints: const [AutofillHints.oneTimeCode],
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          maxLength: 6, // allow paste of full code into first field
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          cursorColor: AppColors.primary,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 24,
                height: 1.0,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
          decoration: InputDecoration(
            counterText: '',
            isDense: true,
            isCollapsed: true,
            contentPadding: EdgeInsets.symmetric(vertical: fieldSize * 0.28),
            filled: true,
            fillColor: _digits[index].text.isNotEmpty
                ? AppColors.primary.withValues(alpha: 0.08)
                : Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(R.s(12)),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(R.s(12)),
              borderSide: BorderSide(
                color: _digits[index].text.isNotEmpty
                    ? AppColors.primary
                    : AppColors.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(R.s(12)),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          onChanged: (v) => _onDigitChanged(index, v),
        ),
      ),
    );
  }
}
