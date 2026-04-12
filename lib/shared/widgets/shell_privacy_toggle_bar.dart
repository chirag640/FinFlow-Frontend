import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/utils/responsive.dart';

class ShellPrivacyToggleBar extends ConsumerWidget {
  const ShellPrivacyToggleBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    R.init(context);
    final privacyEnabled =
        ref.watch(settingsProvider.select((s) => s.privacyModeEnabled));

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: R.md, vertical: R.s(6)),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            privacyEnabled
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            size: R.s(16),
          ),
          SizedBox(width: R.s(8)),
          Expanded(
            child: Text(
              privacyEnabled ? 'Privacy mode on' : 'Privacy mode off',
              style: TextStyle(
                fontSize: R.t(12),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch.adaptive(
            value: privacyEnabled,
            onChanged: (value) => ref
                .read(settingsProvider.notifier)
                .setPrivacyModeEnabled(value),
          ),
        ],
      ),
    );
  }
}
