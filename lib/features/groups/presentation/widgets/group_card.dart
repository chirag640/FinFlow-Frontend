import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive.dart';
import '../../domain/entities/group.dart';

class GroupCard extends StatelessWidget {
  final Group group;
  final double myNetBalance; // positive = owed to me, negative = I owe
  final int expenseCount;
  final double totalSpent;
  final bool compact;
  final VoidCallback onTap;

  const GroupCard({
    super.key,
    required this.group,
    required this.myNetBalance,
    required this.expenseCount,
    required this.totalSpent,
    this.compact = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colors = Theme.of(context).colorScheme;
    final hasBalance = myNetBalance.abs() > 0.01;
    final isOwed = myNetBalance > 0;
    final balanceColor = hasBalance
        ? (isOwed ? AppColors.income : colors.error)
        : AppColors.success;
    final balanceBg = hasBalance
        ? (isOwed
            ? AppColors.incomeLight
            : colors.errorContainer.withValues(alpha: 0.6))
        : AppColors.successLight;
    final balanceLabel =
        hasBalance ? (isOwed ? 'You get back' : 'You owe') : 'Settled';
    final cardPadding = compact ? R.s(10) : R.md;
    final avatarSize = compact ? R.s(40) : R.s(52);
    final gap = compact ? R.s(8) : R.s(14);

    return Container(
      margin: EdgeInsets.only(bottom: compact ? R.s(8) : R.s(12)),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(R.md),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Row(
              children: [
                Hero(
                  tag: 'group-avatar-${group.id}',
                  child: Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.primaryContainer,
                          colors.primaryContainer.withValues(alpha: 0.65),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(R.md),
                    ),
                    child: Center(
                      child: Text(
                        group.emoji,
                        style: TextStyle(fontSize: compact ? R.t(20) : R.t(26)),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: 'group-name-${group.id}',
                        child: Material(
                          type: MaterialType.transparency,
                          child: Text(
                            group.name,
                            style: TextStyle(
                              fontSize: compact ? R.t(14) : R.t(15),
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? R.s(1) : R.s(4)),
                      Text(
                        '${group.members.length} member${group.members.length == 1 ? '' : 's'} - $expenseCount expense${expenseCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: compact ? R.t(10) : R.t(12),
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: compact ? R.s(3) : R.s(6)),
                      Row(
                        children: [
                          _MemberAvatarStack(
                            handles:
                                group.members.map((m) => m.handle).toList(),
                          ),
                          SizedBox(width: compact ? R.s(6) : R.s(8)),
                          Expanded(
                            child: Text(
                              'Total spent ${CurrencyFormatter.format(totalSpent)}',
                              style: TextStyle(
                                fontSize: compact ? R.t(10) : R.t(11),
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: R.s(8)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? R.s(8) : R.s(10),
                        vertical: compact ? R.s(4) : R.s(5),
                      ),
                      decoration: BoxDecoration(
                        color: balanceBg,
                        borderRadius: BorderRadius.circular(R.s(20)),
                        border: Border.all(
                          color: balanceColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        balanceLabel,
                        style: TextStyle(
                          fontSize: compact ? R.t(9) : R.t(10),
                          fontWeight: FontWeight.w700,
                          color: balanceColor,
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? R.s(4) : R.s(6)),
                    Text(
                      hasBalance
                          ? CurrencyFormatter.format(myNetBalance.abs())
                          : CurrencyFormatter.format(0),
                      style: TextStyle(
                        fontSize: compact ? R.t(13) : R.t(14),
                        fontWeight: FontWeight.w800,
                        color: balanceColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: R.xs),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                  size: R.s(20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberAvatarStack extends StatelessWidget {
  final List<String> handles;

  const _MemberAvatarStack({required this.handles});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colors = Theme.of(context).colorScheme;
    final top = handles.take(3).toList();

    return SizedBox(
      width: top.isEmpty ? 0 : R.s(16) + (top.length - 1) * R.s(10),
      height: R.s(16),
      child: Stack(
        children: top.asMap().entries.map((entry) {
          final i = entry.key;
          final raw = entry.value;
          final normalized = raw.startsWith('@') ? raw.substring(1) : raw;
          final ch = normalized.isNotEmpty ? normalized[0].toUpperCase() : '?';
          return Positioned(
            left: i * R.s(10),
            child: Container(
              width: R.s(16),
              height: R.s(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primaryContainer,
                border: Border.all(color: colors.surface, width: 1.2),
              ),
              alignment: Alignment.center,
              child: Text(
                ch,
                style: TextStyle(
                  fontSize: R.t(9),
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
