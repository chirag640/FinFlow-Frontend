import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/components/ds_dialog.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive.dart';
import '../../domain/entities/group_expense.dart';
import '../../domain/entities/group_member.dart';
import '../providers/group_provider.dart';
import '../providers/upi_id_provider.dart';

class DebtSummaryWidget extends ConsumerStatefulWidget {
  final List<SettleUpTransaction> settlements;
  final List<GroupMember> members;
  final String currentUserId;
  final String groupId;

  const DebtSummaryWidget({
    super.key,
    required this.settlements,
    required this.members,
    required this.currentUserId,
    required this.groupId,
  });

  @override
  ConsumerState<DebtSummaryWidget> createState() => _DebtSummaryWidgetState();
}

class _DebtSummaryWidgetState extends ConsumerState<DebtSummaryWidget> {
  // Tracks which settlements are in-flight: key = 'fromId_toId'
  final Set<String> _settling = {};

  String _name(String id) => widget.members
      .firstWhere((m) => m.id == id,
          orElse: () => GroupMember(id: id, name: 'Someone'))
      .handle;

  // ----- UPI helpers ---------------------------------------------------------

  Future<void> _launchUpi(
      SettleUpTransaction s, String toName, String upiId) async {
    final uri = Uri.parse(
      'upi://pay'
      '?pa=${Uri.encodeComponent(upiId)}'
      '&pn=${Uri.encodeComponent(toName)}'
      '&am=${s.amount.toStringAsFixed(2)}'
      '&cu=INR',
    );
    if (!await canLaunchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No UPI app found. Install GPay, PhonePe, or BHIM.'),
          ),
        );
      }
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _setUpiId(String memberId, String memberName) async {
    final currentUpi = ref.read(upiIdProvider)[memberId] ?? '';
    final newUpi = await DSInputDialog.show(
      context: context,
      title: 'UPI ID for $memberName',
      hintText: 'name@upi or 9876543210@paytm',
      labelText: 'UPI ID / VPA',
      initialValue: currentUpi,
      keyboardType: TextInputType.emailAddress,
      confirmLabel: 'Save',
    );

    if (newUpi == null) return;

    if (newUpi.isEmpty) {
      ref.read(upiIdProvider.notifier).remove(memberId);
    } else {
      ref.read(upiIdProvider.notifier).set(memberId, newUpi);
    }
  }

  Future<void> _settle(SettleUpTransaction s) async {
    final key = '${s.fromId}_${s.toId}';
    if (_settling.contains(key)) return;
    setState(() => _settling.add(key));
    try {
      await ref.read(groupExpenseProvider(widget.groupId).notifier).settleUp(
            fromMemberId: s.fromId,
            toMemberId: s.toId,
            amount: s.amount,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _settling.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colorScheme = Theme.of(context).colorScheme;
    final myDebts = widget.settlements
        .where((s) =>
            s.fromId == widget.currentUserId || s.toId == widget.currentUserId)
        .toList();

    if (myDebts.isEmpty) {
      return Container(
        padding: EdgeInsets.all(R.md),
        decoration: BoxDecoration(
          color: colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(R.s(14)),
        ),
        child: Row(
          children: [
            Icon(Icons.verified_rounded,
                size: R.s(20), color: colorScheme.tertiary),
            SizedBox(width: R.s(10)),
            Text(
              'All settled up!',
              style: TextStyle(
                fontSize: R.t(14),
                fontWeight: FontWeight.w600,
                color: colorScheme.onTertiaryContainer,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(R.s(14)),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(R.md, R.s(14), R.md, 0),
            child: Row(
              children: [
                Icon(Icons.swap_horiz_rounded,
                    size: R.s(18), color: colorScheme.primary),
                SizedBox(width: R.sm),
                Text(
                  'Settlements',
                  style: TextStyle(
                    fontSize: R.t(13),
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: 220.ms,
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: Container(
                    key: ValueKey('${widget.settlements.length}'),
                    padding: EdgeInsets.symmetric(
                      horizontal: R.sm,
                      vertical: R.s(3),
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(R.s(20)),
                    ),
                    child: Text(
                      '${widget.settlements.length} transactions',
                      style: TextStyle(
                        fontSize: R.t(11),
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: R.s(10)),
          ...myDebts.map((s) {
            final isOwing = s.fromId == widget.currentUserId;
            final settleKey = '${s.fromId}_${s.toId}';
            final isLoading = _settling.contains(settleKey);
            final creditorUpiId =
                isOwing ? ref.watch(upiIdProvider)[s.toId] : null;
            return AnimatedContainer(
              duration: 220.ms,
              curve: Curves.easeOut,
              margin: EdgeInsets.symmetric(horizontal: R.md, vertical: R.s(5)),
              padding:
                  EdgeInsets.symmetric(horizontal: R.s(2), vertical: R.s(3)),
              decoration: BoxDecoration(
                color: isLoading
                    ? colorScheme.primaryContainer.withValues(alpha: 0.35)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(R.s(10)),
              ),
              child: Row(
                children: [
                  // Avatar: tap to set UPI ID for the creditor
                  GestureDetector(
                    onTap:
                        isOwing ? () => _setUpiId(s.toId, _name(s.toId)) : null,
                    child: _Avatar(
                        name: isOwing ? _name(s.toId) : _name(s.fromId)),
                  ),
                  SizedBox(width: R.s(10)),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                            fontSize: R.t(13),
                            color: colorScheme.onSurfaceVariant),
                        children: [
                          TextSpan(
                              text: isOwing ? 'You owe ' : 'You get back '),
                          TextSpan(
                            text: isOwing ? _name(s.toId) : _name(s.fromId),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(s.amount),
                    style: TextStyle(
                      fontSize: R.t(14),
                      fontWeight: FontWeight.w700,
                      color: isOwing ? colorScheme.error : AppColors.income,
                    ),
                  ),
                  // Settle button (+ UPI pay icon) for debts I owe
                  if (isOwing) ...[
                    SizedBox(width: R.s(4)),
                    // UPI pay icon or "+UPI" prompt
                    AnimatedSwitcher(
                      duration: 180.ms,
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      ),
                      child: creditorUpiId != null
                          ? SizedBox(
                              key: ValueKey('upi-${s.toId}'),
                              width: R.s(32),
                              height: R.s(32),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                tooltip: 'Pay via UPI',
                                icon: Icon(Icons.payment_rounded,
                                    size: R.s(18), color: AppColors.primary),
                                onPressed: () =>
                                    _launchUpi(s, _name(s.toId), creditorUpiId),
                              ),
                            )
                          : SizedBox(
                              key: ValueKey('add-upi-${s.toId}'),
                              height: R.s(30),
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: R.s(4)),
                                  foregroundColor: colorScheme.onSurfaceVariant,
                                  textStyle: TextStyle(fontSize: R.t(11)),
                                ),
                                onPressed: () =>
                                    _setUpiId(s.toId, _name(s.toId)),
                                child: const Text('+ UPI'),
                              ),
                            ),
                    ),
                    SizedBox(
                      width: R.s(60),
                      height: R.s(30),
                      child: AnimatedSwitcher(
                        duration: 200.ms,
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child:
                              ScaleTransition(scale: animation, child: child),
                        ),
                        child: isLoading
                            ? Center(
                                key: ValueKey('loading-$settleKey'),
                                child: SizedBox(
                                  width: R.s(16),
                                  height: R.s(16),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              )
                            : TextButton(
                                key: ValueKey('cta-$settleKey'),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  foregroundColor: colorScheme.primary,
                                  textStyle: TextStyle(
                                    fontSize: R.t(12),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                onPressed: () => _settle(s),
                                child: const Text('Settle'),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ).animate().fadeIn(duration: 220.ms).slideX(begin: 0.03, end: 0);
          }),
          if (widget.settlements.any((s) =>
              s.fromId != widget.currentUserId &&
              s.toId != widget.currentUserId)) ...[
            Divider(height: 1, color: colorScheme.outlineVariant),
            Padding(
              padding: EdgeInsets.fromLTRB(R.md, R.s(10), R.md, R.s(4)),
              child: Text(
                'OTHERS',
                style: TextStyle(
                  fontSize: R.t(10),
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            ...widget.settlements
                .where((s) =>
                    s.fromId != widget.currentUserId &&
                    s.toId != widget.currentUserId)
                .map((s) => Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: R.md, vertical: R.s(6)),
                      child: Row(
                        children: [
                          _Avatar(name: _name(s.fromId)),
                          SizedBox(width: R.s(10)),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                    fontSize: R.t(12),
                                    color: colorScheme.onSurfaceVariant),
                                children: [
                                  TextSpan(
                                    text: _name(s.fromId),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const TextSpan(text: ' settles with '),
                                  TextSpan(
                                    text: _name(s.toId),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(s.amount),
                            style: TextStyle(
                              fontSize: R.t(13),
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )),
          ],
          SizedBox(height: R.s(12)),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: R.s(30),
      height: R.s(30),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          () {
            final trimmed = name.trim();
            final normalized =
                trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
            return normalized.isNotEmpty ? normalized[0].toUpperCase() : '?';
          }(),
          style: TextStyle(
            fontSize: R.t(12),
            fontWeight: FontWeight.w700,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
