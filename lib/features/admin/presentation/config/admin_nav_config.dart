import 'package:flutter/material.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/localization/locale_keys.dart';

enum AdminNavBadge { remittances, reviews }

class AdminNavItem {
  const AdminNavItem({
    required this.route,
    required this.labelKey,
    required this.outlinedIcon,
    required this.filledIcon,
    this.mobileBottomNav = false,
    this.mobileToolsMenu = false,
    this.desktopRail = true,
    this.badge,
  });

  final String route;
  final String labelKey;
  final IconData outlinedIcon;
  final IconData filledIcon;
  final bool mobileBottomNav;
  final bool mobileToolsMenu;
  final bool desktopRail;
  final AdminNavBadge? badge;
}

/// Windows rail ve mobil alt menü + yönetim hub için tek kaynak.
abstract final class AdminNavConfig {
  static const items = <AdminNavItem>[
    AdminNavItem(
      route: RoutePaths.adminDashboard,
      labelKey: LocaleKeys.navDashboard,
      outlinedIcon: Icons.dashboard_outlined,
      filledIcon: Icons.dashboard,
      mobileBottomNav: true,
    ),
    AdminNavItem(
      route: RoutePaths.adminDineIn,
      labelKey: LocaleKeys.navDineInOrders,
      outlinedIcon: Icons.table_restaurant_outlined,
      filledIcon: Icons.table_restaurant,
      mobileBottomNav: true,
    ),
    AdminNavItem(
      route: RoutePaths.adminBranches,
      labelKey: LocaleKeys.navBranches,
      outlinedIcon: Icons.store_outlined,
      filledIcon: Icons.store,
      mobileBottomNav: true,
    ),
    AdminNavItem(
      route: RoutePaths.adminMenu,
      labelKey: LocaleKeys.navMenu,
      outlinedIcon: Icons.restaurant_menu_outlined,
      filledIcon: Icons.restaurant_menu,
      mobileBottomNav: true,
    ),
    AdminNavItem(
      route: RoutePaths.adminUsers,
      labelKey: LocaleKeys.navUsers,
      outlinedIcon: Icons.people_outline,
      filledIcon: Icons.people,
      mobileBottomNav: true,
    ),
    AdminNavItem(
      route: RoutePaths.adminReports,
      labelKey: LocaleKeys.navReports,
      outlinedIcon: Icons.bar_chart_outlined,
      filledIcon: Icons.bar_chart,
      mobileBottomNav: true,
    ),
    AdminNavItem(
      route: RoutePaths.adminCourierTracking,
      labelKey: LocaleKeys.navCourierTracking,
      outlinedIcon: Icons.map_outlined,
      filledIcon: Icons.map,
      mobileToolsMenu: true,
    ),
    AdminNavItem(
      route: RoutePaths.adminCashRemittances,
      labelKey: LocaleKeys.navCashRemittances,
      outlinedIcon: Icons.payments_outlined,
      filledIcon: Icons.payments,
      mobileToolsMenu: true,
      badge: AdminNavBadge.remittances,
    ),
    AdminNavItem(
      route: RoutePaths.adminPendingReviews,
      labelKey: LocaleKeys.navReviewApprovals,
      outlinedIcon: Icons.rate_review_outlined,
      filledIcon: Icons.rate_review,
      mobileToolsMenu: true,
      badge: AdminNavBadge.reviews,
    ),
    AdminNavItem(
      route: RoutePaths.adminWaiterSettings,
      labelKey: LocaleKeys.navWaiterSettings,
      outlinedIcon: Icons.room_service_outlined,
      filledIcon: Icons.room_service,
      mobileToolsMenu: true,
    ),
    AdminNavItem(
      route: RoutePaths.adminPaytrSettings,
      labelKey: LocaleKeys.navPaytrSettings,
      outlinedIcon: Icons.credit_card_outlined,
      filledIcon: Icons.credit_card,
      mobileToolsMenu: true,
    ),
    AdminNavItem(
      route: RoutePaths.adminPromotions,
      labelKey: LocaleKeys.navPromotions,
      outlinedIcon: Icons.local_offer_outlined,
      filledIcon: Icons.local_offer,
      mobileToolsMenu: true,
    ),
  ];

  static List<AdminNavItem> get desktopRailItems =>
      items.where((item) => item.desktopRail).toList();

  static List<AdminNavItem> get mobileBottomItems =>
      items.where((item) => item.mobileBottomNav).toList();

  static List<AdminNavItem> get mobileToolsItems =>
      items.where((item) => item.mobileToolsMenu).toList();

  static List<String> get mobileToolsRoutes =>
      mobileToolsItems.map((item) => item.route).toList();

  static List<String> get mobileBottomRoutes => [
        ...mobileBottomItems.map((item) => item.route),
        RoutePaths.adminTools,
      ];

  static List<String> get desktopRoutes =>
      desktopRailItems.map((item) => item.route).toList();

  static int indexForLocation(String location, {required bool desktop}) {
    final routes = desktop ? desktopRoutes : mobileBottomRoutes;
    if (!desktop) {
      for (final route in mobileToolsRoutes) {
        if (location.startsWith(route)) {
          return routes.length - 1;
        }
      }
    }
    for (var i = routes.length - 1; i >= 0; i--) {
      if (location.startsWith(routes[i])) return i;
    }
    return 0;
  }
}
