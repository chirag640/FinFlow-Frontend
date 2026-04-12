import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/components/ds_async_state.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../providers/auth_provider.dart';
import '../widgets/pin_pad.dart';

class PinSetupPage extends ConsumerStatefulWidget {
  /// When [isChangingPin] is true the page starts with a "confirm current PIN"
  /// step before allowing the user to set a new one.
  final bool isChangingPin;
  const PinSetupPage({super.key, this.isChangingPin = false});

  @override
  ConsumerState<PinSetupPage> createState() => _PinSetupPageState();
}

enum _Step { verifyOld, enterNew, confirmNew }

class _PinSetupPageState extends ConsumerState<PinSetupPage> {
  late _Step _step;
  String _currentPin = ''; // what the user typed for «confirm current PIN»
  String _pin = ''; // the new PIN
  String _confirmPin = ''; // confirmation of new PIN
  String? _error;
  bool _isSubmitting = false;
  bool _isVerifyingCurrentPin = false;

  @override
  void initState() {
    super.initState();
    _step = widget.isChangingPin ? _Step.verifyOld : _Step.enterNew;
  }

  String get _active => switch (_step) {
        _Step.verifyOld => _currentPin,
        _Step.enterNew => _pin,
        _Step.confirmNew => _confirmPin,
      };

  void _onDigit(String digit) {
    if (_isSubmitting || _isVerifyingCurrentPin) return;
    if (_active.length >= 4) return;
    setState(() {
      _error = null;
      switch (_step) {
        case _Step.verifyOld:
          _currentPin += digit;
          if (_currentPin.length == 4) {
            Future.delayed(const Duration(milliseconds: 150), _verifyOld);
          }
        case _Step.enterNew:
          _pin += digit;
          if (_pin.length == 4) {
            Future.delayed(const Duration(milliseconds: 150), () {
              if (mounted) setState(() => _step = _Step.confirmNew);
            });
          }
        case _Step.confirmNew:
          _confirmPin += digit;
          if (_confirmPin.length == 4) _validateAndSave();
      }
    });
  }

  void _onDelete() {
    if (_isSubmitting || _isVerifyingCurrentPin) return;
    setState(() {
      _error = null;
      switch (_step) {
        case _Step.verifyOld:
          if (_currentPin.isNotEmpty) {
            _currentPin = _currentPin.substring(0, _currentPin.length - 1);
          }
        case _Step.enterNew:
          if (_pin.isNotEmpty) {
            _pin = _pin.substring(0, _pin.length - 1);
          }
        case _Step.confirmNew:
          if (_confirmPin.isNotEmpty) {
            _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
          }
      }
    });
  }

  Future<void> _verifyOld() async {
    setState(() {
      _isVerifyingCurrentPin = true;
      _error = null;
    });

    final valid =
        await ref.read(authStateProvider.notifier).verifyPin(_currentPin);
    if (!mounted) return;
    if (valid) {
      setState(() {
        _isVerifyingCurrentPin = false;
        _step = _Step.enterNew;
      });
    } else {
      final authError = ref.read(authStateProvider).error;
      setState(() {
        _isVerifyingCurrentPin = false;
        _error = authError ?? 'Incorrect PIN. Try again.';
        _currentPin = '';
      });
    }
  }

  Future<void> _validateAndSave() async {
    if (_pin != _confirmPin) {
      setState(() {
        _error = 'PINs don\'t match. Try again.';
        _confirmPin = '';
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _step = _Step.enterNew);
        });
      });
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await ref.read(authStateProvider.notifier).setupPin(_pin);
      if (mounted && widget.isChangingPin) {
        // Return to Settings with a success message.
        final messenger = ScaffoldMessenger.of(context);
        context.go(AppRoutes.settings);
        messenger.showSnackBar(
          const SnackBar(content: Text('PIN updated successfully ✓')),
        );
      }
      // For initial setup, router redirect handles navigation automatically.
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _step = _Step.enterNew;
        _confirmPin = '';
        _error = 'Unable to save PIN. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);

    final (title, subtitle, emoji) = switch (_step) {
      _Step.verifyOld => (
          'Confirm current PIN',
          'Enter your existing PIN to continue',
          '🔒'
        ),
      _Step.enterNew => (
          widget.isChangingPin ? 'Enter new PIN' : 'Create a PIN',
          'This PIN protects your financial data',
          '🔐'
        ),
      _Step.confirmNew => (
          'Confirm new PIN',
          'Enter the same PIN again to confirm',
          '🔐'
        ),
    };
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        leading: _step == _Step.confirmNew
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() {
                  _step = _Step.enterNew;
                  _confirmPin = '';
                  _error = null;
                }),
              )
            : (_step == _Step.enterNew && widget.isChangingPin
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : const SizedBox.shrink()),
        actions: const [],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Text(emoji, style: TextStyle(fontSize: R.t(56)))
                .animate(key: ValueKey(_step))
                .scale(
                  begin: const Offset(0.5, 0.5),
                  duration: 600.ms,
                  curve: Curves.elasticOut,
                ),
            SizedBox(height: R.lg),
            Text(
              title,
              style: TextStyle(
                fontSize: R.t(26),
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            )
                .animate(key: ValueKey('title_$_step'))
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.1, end: 0),
            SizedBox(height: R.sm),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: R.t(15),
                color: colorScheme.onSurfaceVariant,
              ),
            ).animate(key: ValueKey('sub_$_step')).fadeIn(duration: 300.ms),
            SizedBox(height: R.s(40)),
            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _active.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.symmetric(horizontal: R.s(10)),
                  width: R.s(16),
                  height: R.s(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        filled ? AppColors.primary : colorScheme.outlineVariant,
                    border: Border.all(
                      color: filled ? AppColors.primary : colorScheme.outline,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            if (_isSubmitting || _isVerifyingCurrentPin) ...[
              SizedBox(height: R.md),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: DSAsyncState.loading(
                  compact: true,
                  title:
                      _isVerifyingCurrentPin ? 'Verifying PIN' : 'Saving PIN',
                  message: _isVerifyingCurrentPin
                      ? 'Confirming your current PIN...'
                      : 'Securing your app...',
                ),
              ),
            ] else if (_error != null) ...[
              SizedBox(height: R.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: DSAsyncState.error(
                  compact: true,
                  title: 'PIN setup issue',
                  message: _error,
                ),
              ).animate().shakeX(hz: 3, amount: 4),
            ],
            const Spacer(flex: 3),
            PinPad(onDigit: _onDigit, onDelete: _onDelete),
            SizedBox(height: R.xl),
          ],
        ),
      ),
    );
  }
}
