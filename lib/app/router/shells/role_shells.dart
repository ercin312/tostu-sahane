import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/locale_keys.dart';
import '../../../core/widgets/ops_cashier_switch_fab.dart';
import '../../../core/utils/platform_layout_utils.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../features/branch_manager/presentation/widgets/branch_order_alert_listener.dart';
import '../../../features/customer/product_detail/presentation/providers/product_reviews_provider.dart';
import '../../../shared/domain/entities/user.dart';
import '../../../shared/presentation/providers/cash_remittance_providers.dart';
import '../../../features/admin/presentation/config/admin_nav_config.dart';
import '../route_paths.dart';

class CustomerShell extends StatelessWidget {
  const CustomerShell({super.key, required this.child});

  final Widget child;

  static bool _isOrderTrackingPath(String location) {
    return RegExp(r'^/customer/order/[^/]+/track$').hasMatch(location);
  }

  static bool _shouldShowNav(String location) {
    return location == RoutePaths.customerHome ||
        location == RoutePaths.customerOrders ||
        location == RoutePaths.customerProfile ||
        _isOrderTrackingPath(location);
  }

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/customer/orders') ||
        _isOrderTrackingPath(location)) {
      return 1;
    }
    if (location.startsWith('/customer/profile')) return 2;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(RoutePaths.customerHome);
      case 1:
        context.go(RoutePaths.customerOrders);
      case 2:
        context.go(RoutePaths.customerProfile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final showNav = _shouldShowNav(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: showNav
          ? BottomNavigationBar(
              currentIndex: _selectedIndex(context),
              onTap: (index) => _onItemTapped(context, index),
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.home_outlined),
                  activeIcon: const Icon(Icons.home),
                  label: LocaleKeys.navHome.tr(),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.receipt_long_outlined),
                  activeIcon: const Icon(Icons.receipt_long),
                  label: LocaleKeys.navOrders.tr(),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.person_outline),
                  activeIcon: const Icon(Icons.person),
                  label: LocaleKeys.navProfile.tr(),
                ),
              ],
            )
          : null,
    );
  }
}

class BranchShell extends ConsumerWidget {
  const BranchShell({super.key, required this.child});

  final Widget child;

  bool _isWaiter(WidgetRef ref) =>
      ref.watch(authProvider)?.user.role == UserRole.waiter;

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/branch/orders')) return 1;
    if (location.startsWith(RoutePaths.branchDineIn)) return 2;
    if (location.startsWith('/branch/menu')) return 3;
    if (location.startsWith('/branch/reports')) return 4;
    if (location.startsWith(RoutePaths.branchCashRemittances)) return 5;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(RoutePaths.branchDashboard);
      case 1:
        context.go(RoutePaths.branchOrders);
      case 2:
        context.go(RoutePaths.branchDineIn);
      case 3:
        context.go(RoutePaths.branchMenu);
      case 4:
        context.go(RoutePaths.branchReports);
      case 5:
        context.go(RoutePaths.branchCashRemittances);
    }
  }

  List<NavigationRailDestination> _branchRailDestinations(
    WidgetRef ref,
    bool extended,
  ) {
    final pendingRemittances = ref.watch(branchPendingRemittanceCountProvider);
    return [
      NavigationRailDestination(
        icon: const Icon(Icons.dashboard_outlined),
        selectedIcon: const Icon(Icons.dashboard),
        label: Text(LocaleKeys.navDashboard.tr()),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.receipt_long_outlined),
        selectedIcon: const Icon(Icons.receipt_long),
        label: Text(LocaleKeys.navOrders.tr()),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.table_restaurant_outlined),
        selectedIcon: const Icon(Icons.table_restaurant),
        label: Text(LocaleKeys.navDineInOrders.tr()),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.restaurant_menu_outlined),
        selectedIcon: const Icon(Icons.restaurant_menu),
        label: Text(LocaleKeys.navMenu.tr()),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.bar_chart_outlined),
        selectedIcon: const Icon(Icons.bar_chart),
        label: Text(LocaleKeys.navReports.tr()),
      ),
      NavigationRailDestination(
        icon: Badge(
          isLabelVisible: pendingRemittances > 0,
          label: Text('$pendingRemittances'),
          child: const Icon(Icons.account_balance_wallet_outlined),
        ),
        selectedIcon: Badge(
          isLabelVisible: pendingRemittances > 0,
          label: Text('$pendingRemittances'),
          child: const Icon(Icons.account_balance_wallet),
        ),
        label: Text(LocaleKeys.navCashRemittances.tr()),
      ),
    ];
  }

  List<BottomNavigationBarItem> _branchBottomItems(WidgetRef ref) {
    final pendingRemittances = ref.watch(branchPendingRemittanceCountProvider);
    return [
      BottomNavigationBarItem(
        icon: const Icon(Icons.dashboard_outlined),
        activeIcon: const Icon(Icons.dashboard),
        label: LocaleKeys.navDashboard.tr(),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.receipt_long_outlined),
        activeIcon: const Icon(Icons.receipt_long),
        label: LocaleKeys.navOrders.tr(),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.table_restaurant_outlined),
        activeIcon: const Icon(Icons.table_restaurant),
        label: LocaleKeys.navDineInOrders.tr(),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.restaurant_menu_outlined),
        activeIcon: const Icon(Icons.restaurant_menu),
        label: LocaleKeys.navMenu.tr(),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.bar_chart_outlined),
        activeIcon: const Icon(Icons.bar_chart),
        label: LocaleKeys.navReports.tr(),
      ),
      BottomNavigationBarItem(
        icon: Badge(
          isLabelVisible: pendingRemittances > 0,
          label: Text('$pendingRemittances'),
          child: const Icon(Icons.account_balance_wallet_outlined),
        ),
        activeIcon: Badge(
          isLabelVisible: pendingRemittances > 0,
          label: Text('$pendingRemittances'),
          child: const Icon(Icons.account_balance_wallet),
        ),
        label: LocaleKeys.navCashRemittances.tr(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_isWaiter(ref)) {
      return BranchOrderAlertListener(child: child);
    }

    final index = _selectedIndex(context);

    return BranchOrderAlertListener(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (PlatformLayout.useDesktopLayout(context)) {
            final extended = constraints.maxWidth >= 1200;
            return Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    extended: extended,
                    selectedIndex: index,
                    onDestinationSelected: (i) => _onItemTapped(context, i),
                    labelType: extended
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
                    destinations: _branchRailDestinations(ref, extended),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: OpsCashierSwitchFab(child: child),
                  ),
                ],
              ),
            );
          }

          return Scaffold(
            body: OpsCashierSwitchFab(child: child),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: index,
              onTap: (i) => _onItemTapped(context, i),
              type: BottomNavigationBarType.fixed,
              items: _branchBottomItems(ref),
            ),
          );
        },
      ),
    );
  }
}

class CourierShell extends StatelessWidget {
  const CourierShell({super.key, required this.child});

  final Widget child;

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/courier/wallet')) return 1;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(RoutePaths.courierTasks);
      case 1:
        context.go(RoutePaths.courierWallet);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex(context),
        onTap: (index) => _onItemTapped(context, index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.delivery_dining_outlined),
            activeIcon: const Icon(Icons.delivery_dining),
            label: LocaleKeys.navTasks.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            activeIcon: const Icon(Icons.account_balance_wallet),
            label: LocaleKeys.navWallet.tr(),
          ),
        ],
      ),
    );
  }
}

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  int _selectedIndex(BuildContext context, {required bool desktop}) {
    return AdminNavConfig.indexForLocation(
      GoRouterState.of(context).uri.path,
      desktop: desktop,
    );
  }

  void _onItemTapped(BuildContext context, int index, {required bool desktop}) {
    final routes =
        desktop ? AdminNavConfig.desktopRoutes : AdminNavConfig.mobileBottomRoutes;
    if (index < 0 || index >= routes.length) return;
    context.go(routes[index]);
  }

  Widget _badgeIcon({
    required IconData outlined,
    required IconData filled,
    required int count,
  }) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      child: Icon(outlined),
    );
  }

  Widget _badgeSelectedIcon({
    required IconData outlined,
    required IconData filled,
    required int count,
  }) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      child: Icon(filled),
    );
  }

  Widget _navIcon(WidgetRef ref, AdminNavItem item, {required bool selected}) {
    final count = switch (item.badge) {
      AdminNavBadge.remittances =>
        ref.watch(adminPendingRemittanceCountProvider),
      AdminNavBadge.reviews => ref.watch(adminPendingReviewCountProvider),
      null => 0,
    };
    if (count > 0) {
      return selected
          ? _badgeSelectedIcon(
              outlined: item.outlinedIcon,
              filled: item.filledIcon,
              count: count,
            )
          : _badgeIcon(
              outlined: item.outlinedIcon,
              filled: item.filledIcon,
              count: count,
            );
    }
    return Icon(selected ? item.filledIcon : item.outlinedIcon);
  }

  List<NavigationRailDestination> _adminDesktopDestinations(
    WidgetRef ref,
  ) {
    return [
      for (final item in AdminNavConfig.desktopRailItems)
        NavigationRailDestination(
          icon: _navIcon(ref, item, selected: false),
          selectedIcon: _navIcon(ref, item, selected: true),
          label: Text(item.labelKey.tr()),
        ),
    ];
  }

  List<NavigationDestination> _bottomDestinations() => [
        for (final item in AdminNavConfig.mobileBottomItems)
          NavigationDestination(
            icon: Icon(item.outlinedIcon),
            selectedIcon: Icon(item.filledIcon),
            label: item.labelKey.tr(),
          ),
        NavigationDestination(
          icon: const Icon(Icons.more_horiz_outlined),
          selectedIcon: const Icon(Icons.more_horiz),
          label: LocaleKeys.navAdminTools.tr(),
        ),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useDesktop = PlatformLayout.useDesktopLayout(context);
    final index = _selectedIndex(context, desktop: useDesktop);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (useDesktop) {
          final extended = constraints.maxWidth >= 1280;
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  extended: extended,
                  minExtendedWidth: 200,
                  selectedIndex: index,
                  onDestinationSelected: (i) =>
                      _onItemTapped(context, i, desktop: true),
                  labelType: extended
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  destinations: _adminDesktopDestinations(ref),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: OpsCashierSwitchFab(child: child),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: OpsCashierSwitchFab(child: child),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) =>
                _onItemTapped(context, i, desktop: false),
            destinations: _bottomDestinations(),
          ),
        );
      },
    );
  }
}

class KitchenShell extends ConsumerWidget {
  const KitchenShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BranchOrderAlertListener(child: child);
  }
}
