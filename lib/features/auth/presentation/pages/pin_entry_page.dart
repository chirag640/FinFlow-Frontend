import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../../core/utils/responsive.dart';
import '../providers/auth_provider.dart';
import '../widgets/pin_pad.dart';

class PinEntryPage extends ConsumerStatefulWidget {
  const PinEntryPage({super.key});

  @override
  ConsumerState<PinEntryPage> createState() => _PinEntryPageState();
}

class _PinEntryPageState extends ConsumerState<PinEntryPage> {
  String _pin = '';
  bool _isShaking = false;
  String? _error;
  bool _biometricAvailable = false;
  bool _biometricInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkBiometric();
    });
  }

  Future<void> _checkBiometric() async {
    final settings = ref.read(settingsProvider);
    if (!settings.biometricEnabled) return;
    final available = await BiometricService.isAvailable();
    if (!mounted) return;
    setState(() => _biometricAvailable = available);
    if (available) {
      await _tryBiometric(isAutoAttempt: true);
    }
  }

  Future<void> _tryBiometric({bool isAutoAttempt = false}) async {
    if (_biometricInProgress) return;
    setState(() {
      _biometricInProgress = true;
      if (!isAutoAttempt) {
        _error = null;
      }
    });

    final result = await BiometricService.authenticateWithResult();
    if (!mounted) return;
    setState(() => _biometricInProgress = false);

    if (result.isSuccess) {
      ref.read(authStateProvider.notifier).unlockWithBiometric();
      context.go(AppRoutes.dashboard);
      return;
    }

    if (result.shouldDisableBiometricCta) {
      setState(() => _biometricAvailable = false);
    }

    if (result.isCanceled) return;

    setState(() {
      _error = result.userMessage ?? 'Biometric unlock failed. Please try PIN.';
    });
  }

  void _onDigit(String digit) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == 4) _verify();
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _verify() async {
    final valid = await ref.read(authStateProvider.notifier).verifyPin(_pin);
    if (!mounted) return;

    if (valid) {
      context.go(AppRoutes.dashboard);
    } else {
      final authError = ref.read(authStateProvider).error;
      setState(() {
        _pin = '';
        _isShaking = true;
        _error = authError ?? 'Incorrect PIN. Please try again.';
      });
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) setState(() => _isShaking = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final user = ref.watch(currentUserProvider);
    final colors = Theme.of(context).colorScheme;
    final surface = colors.surface;
    final textPrimary = colors.onSurface;
    final textSecondary = colors.onSurfaceVariant;
    final border = colors.outlineVariant;

    return Scaffold(
      backgroundColor: surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Text('👋', style: TextStyle(fontSize: R.t(52))),
            SizedBox(height: R.s(20)),
            Text(
              'Welcome back${user != null ? ',\n${user.name.split(' ').first}!' : '!'}',
              style: TextStyle(
                fontSize: R.t(26),
                fontWeight: FontWeight.w700,
                color: textPrimary,
                letterSpacing: -0.5,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: R.sm),
            Text(
              'Enter your PIN to continue',
              style: TextStyle(fontSize: R.t(15), color: textSecondary),
            ),
            SizedBox(height: R.s(40)),
            // PIN dots
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _pin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: EdgeInsets.symmetric(horizontal: R.s(10)),
                    width: R.s(16),
                    height: R.s(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isShaking
                          ? AppColors.error
                          : filled
                              ? AppColors.primary
                              : border,
                    ),
                  );
                }),
              ),
            ),
            if (_error != null) ...[
              SizedBox(height: R.md),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: R.t(13),
                  color: AppColors.error,
                  fontWeight: FontWeight.w500,
                ),
              ).animate(key: ValueKey(_error)).shakeX(hz: 3, amount: 4),
            ],
            const Spacer(flex: 3),
            PinPad(onDigit: _onDigit, onDelete: _onDelete),
            SizedBox(height: R.s(20)),
            // Biometric button
            if (_biometricAvailable)
              TextButton.icon(
                onPressed: _biometricInProgress ? null : () => _tryBiometric(),
                icon: _biometricInProgress
                    ? SizedBox(
                        width: R.s(20),
                        height: R.s(20),
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.fingerprint_rounded, size: R.s(22)),
                label: Text(
                  _biometricInProgress ? 'Checking...' : 'Use biometrics',
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: R.t(14),
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms),
            SizedBox(height: R.xl),
          ],
        ),
      ),
    );
  }
}
