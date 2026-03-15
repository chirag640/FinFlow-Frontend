// Figma: Screen/Investments
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/components/ds_empty_state.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/ui/error_feedback.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive.dart';
import '../../domain/entities/investment.dart';
import '../providers/investment_provider.dart';

class InvestmentsPage extends ConsumerStatefulWidget {
  const InvestmentsPage({super.key});

  @override
  ConsumerState<InvestmentsPage> createState() => _InvestmentsPageState();
}

class _InvestmentsPageState extends ConsumerState<InvestmentsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    (label: 'All', type: null),
    (label: 'MF', type: InvestmentType.mutualFund),
    (label: 'FD', type: InvestmentType.fixedDeposit),
    (label: 'RD', type: InvestmentType.recurringDeposit),
    (label: 'Gold', type: InvestmentType.gold),
    (label: 'Stocks', type: InvestmentType.stock),
    (label: 'Property', type: InvestmentType.realEstate),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    listenForProviderError<InvestmentsState>(
      ref: ref,
      context: context,
      provider: investmentsProvider,
      errorSelector: (s) => s.error,
    );
    final state = ref.watch(investmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text(
          'Investments',
          style: TextStyle(
            fontSize: R.t(18),
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(R.s(48)),
          child: Column(
            children: [
              const Divider(height: 1, color: AppColors.border),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textTertiary,
                indicatorColor: AppColors.primary,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle:
                    TextStyle(fontSize: R.t(12), fontWeight: FontWeight.w700),
                unselectedLabelStyle:
                    TextStyle(fontSize: R.t(12), fontWeight: FontWeight.w500),
                tabs: _tabs
                    .map((t) => Tab(
                          text: t.type == null
                              ? 'All'
                              : '${t.type!.emoji} ${t.label}',
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.addInvestment),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Portfolio summary card
          if (state.investments.isNotEmpty)
            _PortfolioSummaryCard(state: state)
                .animate()
                .fadeIn(duration: 350.ms)
                .slideY(begin: 0.05, end: 0),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabs.map((tab) {
                final list = tab.type == null
                    ? state.investments
                    : state.byType(tab.type!);
                return _InvestmentList(
                  investments: list,
                  emptyType: tab.type,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Portfolio Summary Card ────────────────────────────────────────────────────
class _PortfolioSummaryCard extends StatelessWidget {
  final InvestmentsState state;
  const _PortfolioSummaryCard({required this.state});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final gainIcon = state.isProfit ? '↑' : '↓';

    return Container(
      margin: EdgeInsets.all(R.s(16)),
      padding: EdgeInsets.all(R.s(18)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(R.s(16)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Portfolio Value',
            style: TextStyle(
              fontSize: R.t(12),
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: R.xs),
          Text(
            CurrencyFormatter.format(state.totalCurrentValue,
                showDecimals: true),
            style: TextStyle(
              fontSize: R.t(28),
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          SizedBox(height: R.s(14)),
          Row(
            children: [
              _SummaryPill(
                label: 'Invested',
                value: CurrencyFormatter.format(state.totalInvested),
                color: Colors.white.withValues(alpha: 0.2),
              ),
              SizedBox(width: R.sm),
              _SummaryPill(
                label:
                    '$gainIcon ${state.totalGainLossPercent.abs().toStringAsFixed(1)}%',
                value: CurrencyFormatter.format(state.totalGainLoss.abs()),
                color: state.isProfit
                    ? const Color(0xFF10B981).withValues(alpha: 0.25)
                    : const Color(0xFFEF4444).withValues(alpha: 0.25),
                valueColor: state.isProfit
                    ? const Color(0xFF6EE7B7)
                    : const Color(0xFFFCA5A5),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: R.sm, vertical: R.xs),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(R.s(20)),
                ),
                child: Text(
                  '${state.investments.length} holdings',
                  style: TextStyle(
                    fontSize: R.t(11),
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color? valueColor;
  const _SummaryPill({
    required this.label,
    required this.value,
    required this.color,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: R.sm, vertical: R.s(5)),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(R.s(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: R.t(10),
                color: Colors.white.withValues(alpha: 0.8),
              )),
          Text(
            value,
            style: TextStyle(
              fontSize: R.t(12),
              fontWeight: FontWeight.w700,
              color: valueColor ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Investment List ───────────────────────────────────────────────────────────
class _InvestmentList extends ConsumerWidget {
  final List<Investment> investments;
  final InvestmentType? emptyType;
  const _InvestmentList({required this.investments, this.emptyType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    R.init(context);
    if (investments.isEmpty) {
      return DSEmptyState(
        emoji: emptyType?.emoji ?? '💼',
        title: emptyType == null
            ? 'No investments yet'
            : 'No ${emptyType!.label} entries',
        subtitle: 'Tap + Add to track your first investment.',
        actionLabel: 'Add Investment',
        onAction: () => context.push(AppRoutes.addInvestment),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(R.s(16), R.s(8), R.s(16), R.s(100)),
      itemCount: investments.length,
      itemBuilder: (_, i) => _InvestmentCard(
        investment: investments[i],
        index: i,
      ),
    );
  }
}

// ── Investment Card ───────────────────────────────────────────────────────────
class _InvestmentCard extends ConsumerWidget {
  final Investment investment;
  final int index;
  const _InvestmentCard({required this.investment, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    R.init(context);
    final inv = investment;
    final gainColor = inv.isProfit ? AppColors.income : AppColors.expense;
    final gainBg =
        inv.isProfit ? AppColors.incomeLight : const Color(0xFFFEE2E2);

    return Dismissible(
      key: Key(inv.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: R.s(20)),
        decoration: BoxDecoration(
          color: AppColors.expense,
          borderRadius: BorderRadius.circular(R.s(14)),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 22),
      ),
      confirmDismiss: (_) async => await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Investment'),
          content: Text('Remove "${inv.name}" from your portfolio?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete',
                    style: TextStyle(color: AppColors.expense))),
          ],
        ),
      ),
      onDismissed: (_) {
        ref.read(investmentsProvider.notifier).delete(inv.id);
        showSuccessSnackBar(context, '${inv.name} removed');
      },
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.addInvestment, extra: inv),
        child: Container(
          margin: EdgeInsets.only(bottom: R.s(10)),
          padding: EdgeInsets.all(R.s(14)),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(R.s(14)),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              // Type emoji badge
              Container(
                width: R.s(44),
                height: R.s(44),
                decoration: BoxDecoration(
                  color: AppColors.primaryExtraLight,
                  borderRadius: BorderRadius.circular(R.s(12)),
                ),
                child: Center(
                  child:
                      Text(inv.type.emoji, style: TextStyle(fontSize: R.t(22))),
                ),
              ),
              SizedBox(width: R.s(12)),

              // Name + type
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inv.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: R.t(14),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: R.xs),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: R.s(6), vertical: R.s(2)),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(R.s(4)),
                          ),
                          child: Text(
                            inv.type.shortLabel,
                            style: TextStyle(
                              fontSize: R.t(10),
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                        if (inv.maturityDate != null) ...[
                          SizedBox(width: R.xs),
                          Text(
                            'Matures ${_shortDate(inv.maturityDate!)}',
                            style: TextStyle(
                              fontSize: R.t(10),
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Value + gain
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(inv.currentValue),
                    style: TextStyle(
                      fontSize: R.t(15),
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: R.xs),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: R.s(6), vertical: R.s(2)),
                    decoration: BoxDecoration(
                      color: gainBg,
                      borderRadius: BorderRadius.circular(R.s(6)),
                    ),
                    child: Text(
                      '${inv.isProfit ? '+' : ''}${inv.gainLossPercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: R.t(11),
                        fontWeight: FontWeight.w700,
                        color: gainColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate(delay: (index * 40).ms).fadeIn(duration: 300.ms).slideY(
              begin: 0.06,
              end: 0,
            ),
      ),
    );
  }

  String _shortDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}
