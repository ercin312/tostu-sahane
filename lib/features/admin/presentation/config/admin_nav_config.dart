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
      labelKey: LocaleKeys.navOrders,
      outlinedIcon: Icons.receipt_long_outlined,
      filledIcon: Icons.receipt_long,
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
      route: RoutePaths.adminTools,
      labelKey: LocaleKeys.navAdminTools,
      outlinedIcon: Icons.admin_panel_settings_outlined,
      filledIcon: Icons.admin_panel_settings,
      desktopRail: true,
      mobileBottomNav: false,
    ),
    // Windows rail'de doğrudan görünsün (Yönetim araçları listesine de ekli)
    AdminNavItem(
      route: RoutePaths.adminPhoneAiTraining,
      labelKey: LocaleKeys.navPhoneAiTraining,
      outlinedIcon: Icons.record_voice_over_outlined,
      filledIcon: Icons.record_voice_over,
      mobileToolsMenu: true,
      desktopRail: true,
    ),
    AdminNavItem(
      route: RoutePaths.adminCourierTracking,
      labelKey: LocaleKeys.navCourierTracking,
      outlinedIcon: Icons.map_outlined,
      filledIcon: Icons.map,
      mobileToolsMenu: true,
      desktopRail: false,
    ),
    AdminNavItem(
      route: RoutePaths.adminCashRemittances,
      labelKey: LocaleKeys.navCashRemittances,
      outlinedIcon: Icons.payments_outlined,
      filledIcon: Icons.payments,
      mobileToolsMenu: true,
      desktopRail: false,
      badge: AdminNavBadge.remittances,
    ),
    AdminNavItem(
      route: RoutePaths.adminPendingReviews,
      labelKey: LocaleKeys.navReviewApprovals,
      outlinedIcon: Icons.rate_review_outlined,
      filledIcon: Icons.rate_review,
      mobileToolsMenu: true,
      desktopRail: false,
      badge: AdminNavBadge.reviews,
    ),
    AdminNavItem(
      route: RoutePaths.adminWaiterSettings,
      labelKey: LocaleKeys.navWaiterSettings,
      outlinedIcon: Icons.room_service_outlined,
      filledIcon: Icons.room_service,
      mobileToolsMenu: true,
      desktopRail: false,
    ),
    AdminNavItem(
      route: RoutePaths.adminQrMenu,
      labelKey: LocaleKeys.navQrMenu,
      outlinedIcon: Icons.qr_code_2_outlined,
      filledIcon: Icons.qr_code_2,
      mobileToolsMenu: true,
      desktopRail: false,
    ),
    AdminNavItem(
      route: RoutePaths.adminPhoneCustomers,
      labelKey: LocaleKeys.navPhoneCustomers,
      outlinedIcon: Icons.contact_phone_outlined,
      filledIcon: Icons.contact_phone,
      mobileToolsMenu: true,
      desktopRail: false,
    ),
    AdminNavItem(
      route: RoutePaths.adminPhoneFailedOrders,
      labelKey: LocaleKeys.navPhoneFailedOrders,
      outlinedIcon: Icons.phone_missed_outlined,
      filledIcon: Icons.phone_missed,
      mobileToolsMenu: true,
      desktopRail: true,
    ),
    AdminNavItem(
      route: RoutePaths.adminPaytrSettings,
      labelKey: LocaleKeys.navPaytrSettings,
      outlinedIcon: Icons.credit_card_outlined,
      filledIcon: Icons.credit_card,
      mobileToolsMenu: true,
      desktopRail: false,
    ),
    AdminNavItem(
      route: RoutePaths.adminPromotions,
      labelKey: LocaleKeys.navPromotions,
      outlinedIcon: Icons.local_offer_outlined,
      filledIcon: Icons.local_offer,
      mobileToolsMenu: true,
      desktopRail: false,
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

    if (location.startsWith(RoutePaths.adminTools) ||
        mobileToolsRoutes.any(location.startsWith)) {
      final toolsIndex = routes.indexOf(RoutePaths.adminTools);
      if (toolsIndex >= 0) return toolsIndex;
      if (!desktop) return routes.length - 1;
    }

    for (var i = routes.length - 1; i >= 0; i--) {
      if (location.startsWith(routes[i])) return i;
    }
    return 0;
  }
}
