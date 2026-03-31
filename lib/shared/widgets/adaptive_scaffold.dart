import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_colors.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/responsive.dart';
import 'connectivity_banner.dart';

class AdaptiveScaffold extends StatelessWidget {
  final Widget child;
  const AdaptiveScaffold({super.key, required this.child});

  static const List<_NavItem> _items = [
    _NavItem(
      icon: Icons.grid_view_rounded,
      activeIcon: Icons.grid_view_rounded,
      label: 'Dashboard',
      route: AppRoutes.dashboard,
    ),
    _NavItem(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      label: 'Expenses',
      route: AppRoutes.expenses,
    ),
    _NavItem(
      icon: Icons.group_outlined,
      activeIcon: Icons.group_rounded,
      label: 'Groups',
      route: AppRoutes.groups,
    ),
    _NavItem(
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet_rounded,
      label: 'Budgets',
      route: AppRoutes.budgets,
    ),
    _NavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'Settings',
      route: AppRoutes.settings,
    ),
  ];

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc.startsWith(AppRoutes.expenses)) return 1;
    if (loc.startsWith(AppRoutes.groups)) return 2;
    if (loc.startsWith(AppRoutes.budgets)) return 3;
    if (loc.startsWith(AppRoutes.settings)) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final screenSize = Responsive.of(context);
    final selectedIndex = _selectedIndex(context);
    final colors = Theme.of(context).colorScheme;

    if (screenSize == ScreenSize.mobile) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            const ConnectivityBanner(),
            Expanded(child: child),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (i) {
            context.go(_items[i].route);
          },
          destinations: _items
              .map(
                (item) => NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.activeIcon),
                  label: item.label,
                  tooltip: '', // empty = Flutter skips Tooltip widget entirely
                ),
              )
              .toList(),
        ),
      );
    }

    // Tablet / Desktop — NavigationRail
    final extended = screenSize == ScreenSize.desktop;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            selectedIndex: selectedIndex,
            onDestinationSelected: (i) => context.go(_items[i].route),
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            leading: Padding(
              padding: EdgeInsets.symmetric(vertical: R.md),
              child: Column(
                children: [
                  Container(
                    width: R.s(40),
                    height: R.s(40),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(R.s(12)),
                    ),
                    child: Center(
                      child: Text(
                        '₹',
                        style: TextStyle(
                          fontSize: R.t(22),
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (extended) ...[
                    SizedBox(height: R.sm),
                    Text(
                      'FinFlow',
                      style: TextStyle(
                        fontSize: R.t(16),
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            destinations: _items
                .map(
                  (item) => NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.activeIcon),
                    label: Text(item.label),
                  ),
                )
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                const ConnectivityBanner(),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}
