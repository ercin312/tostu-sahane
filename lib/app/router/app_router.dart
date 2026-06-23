import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/otp_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/branch_manager/cash_remittance/presentation/pages/branch_cash_remittances_page.dart';
import '../../features/branch_manager/cashier/presentation/pages/branch_cashier_page.dart';
import '../../features/branch_manager/dine_in/presentation/pages/branch_dine_in_page.dart';
import '../../features/branch_manager/dashboard/presentation/pages/branch_dashboard_page.dart';
import '../../features/branch_manager/menu_quick_edit/presentation/pages/branch_menu_page.dart';
import '../../features/branch_manager/orders/presentation/pages/branch_orders_page.dart';
import '../../features/branch_manager/reports/presentation/pages/branch_reports_page.dart';
import '../../features/kitchen/presentation/pages/kitchen_display_page.dart';
import '../../features/waiter/presentation/pages/waiter_pages.dart';
import '../../features/waiter/presentation/pages/waiter_table_bill_page.dart';
import '../../features/courier/map/presentation/pages/courier_map_page.dart';
import '../../features/courier/tasks/presentation/pages/courier_tasks_page.dart';
import '../../features/courier/wallet/presentation/pages/courier_wallet_page.dart';
import '../../features/admin/branches/presentation/pages/admin_branch_delivery_zone_page.dart';
import '../../features/admin/branches/presentation/pages/admin_branches_page.dart';
import '../../features/admin/cash_remittance/presentation/pages/admin_cash_remittances_page.dart';
import '../../features/admin/dashboard/presentation/pages/admin_courier_tracking_page.dart';
import '../../features/admin/dine_in/presentation/pages/admin_dine_in_page.dart';
import '../../features/admin/dashboard/presentation/pages/admin_dashboard_page.dart';
import '../../features/admin/menu/presentation/pages/admin_menu_page.dart';
import '../../features/admin/reviews/presentation/pages/admin_pending_reviews_page.dart';
import '../../features/admin/reports/presentation/pages/admin_reports_page.dart';
import '../../features/admin/users/presentation/pages/admin_users_page.dart';
import '../../features/admin/waiter_settings/presentation/pages/admin_waiter_settings_page.dart';
import '../../features/admin/paytr_settings/presentation/pages/admin_paytr_settings_page.dart';
import '../../features/admin/promotions/presentation/pages/admin_promotions_page.dart';
import '../../features/admin/presentation/pages/admin_tools_page.dart';
import '../../features/customer/cart/presentation/pages/cart_page.dart';
import '../../features/customer/checkout/presentation/models/paytr_checkout_args.dart';
import '../../features/customer/checkout/presentation/pages/paytr_payment_page.dart';
import '../../features/customer/checkout/presentation/models/payment_page_args.dart';
import '../../features/customer/checkout/presentation/pages/payment_page.dart';
import '../../features/customer/checkout/presentation/pages/checkout_page.dart';
import '../../features/customer/home/presentation/pages/customer_home_page.dart';
import '../../features/customer/order_tracking/presentation/pages/order_tracking_page.dart';
import '../../features/customer/product_detail/presentation/pages/product_detail_page.dart';
import '../../features/customer/profile/presentation/pages/addresses_page.dart';
import '../../features/customer/profile/presentation/pages/favorites_page.dart';
import '../../features/customer/profile/presentation/pages/saved_cards_page.dart';
import '../../features/customer/profile/presentation/pages/customer_orders_page.dart';
import '../../features/customer/profile/presentation/pages/customer_profile_page.dart';
import '../../shared/presentation/providers/orders_provider.dart';
import 'guards/auth_guard.dart';
import 'route_paths.dart';
import 'shells/role_shells.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final customerShellKey = GlobalKey<NavigatorState>();
final branchShellKey = GlobalKey<NavigatorState>();
final kitchenShellKey = GlobalKey<NavigatorState>();
final courierShellKey = GlobalKey<NavigatorState>();
final adminShellKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter(Ref ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RoutePaths.splash,
    redirect: (context, state) => authRedirect(ref, state),
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: RoutePaths.authLogin,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: RoutePaths.authOtp,
        builder: (context, state) => const OtpPage(),
      ),
      ShellRoute(
        navigatorKey: customerShellKey,
        builder: (context, state, child) => CustomerShell(child: child),
        routes: [
          GoRoute(
            path: RoutePaths.customerHome,
            builder: (context, state) => const CustomerHomePage(),
          ),
          GoRoute(
            path: RoutePaths.customerOrders,
            builder: (context, state) => const CustomerOrdersPage(),
          ),
          GoRoute(
            path: RoutePaths.customerProfile,
            builder: (context, state) => const CustomerProfilePage(),
          ),
          GoRoute(
            path: RoutePaths.customerCart,
            builder: (context, state) => const CartPage(),
          ),
          GoRoute(
            path: RoutePaths.customerCheckout,
            builder: (context, state) => const CheckoutPage(),
          ),
          GoRoute(
            path: RoutePaths.customerPayment,
            builder: (context, state) {
              final extra = state.extra;
              if (extra is PaymentPageArgs) {
                return PaymentPage(
                  amount: extra.amount,
                  savedCard: extra.savedCard,
                );
              }
              final amount =
                  double.tryParse(state.uri.queryParameters['amount'] ?? '') ??
                      0;
              return PaymentPage(amount: amount);
            },
          ),
          GoRoute(
            path: RoutePaths.customerPaytrPayment,
            builder: (context, state) {
              final args = state.extra! as PaytrCheckoutArgs;
              return PaytrPaymentPage(
                amount: args.amount,
                email: args.email,
                customerName: args.customerName,
                phone: args.phone,
                address: args.address,
                basketSummary: args.basketSummary,
                items: args.items,
              );
            },
          ),
          GoRoute(
            path: RoutePaths.customerAddresses,
            builder: (context, state) => const AddressesPage(),
          ),
          GoRoute(
            path: RoutePaths.customerFavorites,
            builder: (context, state) => const FavoritesPage(),
          ),
          GoRoute(
            path: RoutePaths.customerSavedCards,
            builder: (context, state) => const SavedCardsPage(),
          ),
          GoRoute(
            path: '/customer/product/:id',
            builder: (context, state) => ProductDetailPage(
              productId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/customer/order/:id/track',
            builder: (context, state) => OrderTrackingPage(
              orderId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      ShellRoute(
        navigatorKey: branchShellKey,
        builder: (context, state, child) => BranchShell(child: child),
        routes: [
          GoRoute(
            path: RoutePaths.branchDashboard,
            builder: (context, state) => const BranchDashboardPage(),
          ),
          GoRoute(
            path: RoutePaths.branchOrders,
            builder: (context, state) => const BranchOrdersPage(),
          ),
          GoRoute(
            path: RoutePaths.branchMenu,
            builder: (context, state) => const BranchMenuPage(),
          ),
          GoRoute(
            path: RoutePaths.branchReports,
            builder: (context, state) => const BranchReportsPage(),
          ),
          GoRoute(
            path: RoutePaths.branchCashRemittances,
            builder: (context, state) => const BranchCashRemittancesPage(),
          ),
          GoRoute(
            path: RoutePaths.branchWaiter,
            builder: (context, state) => const WaiterTablePage(),
            routes: [
              GoRoute(
                path: 'table/:number',
                builder: (context, state) => WaiterOrderPage(
                  tableNumber: int.parse(state.pathParameters['number']!),
                ),
                routes: [
                  GoRoute(
                    path: 'bill',
                    builder: (context, state) {
                      final parentNumber = state.pathParameters['number']!;
                      return WaiterTableBillPage(
                        tableNumber: int.parse(parentNumber),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: RoutePaths.branchDineIn,
            builder: (context, state) => const BranchDineInPage(),
          ),
          GoRoute(
            path: RoutePaths.branchCashier,
            builder: (context, state) => BranchCashierPage(
              listProvider: branchDineInOrdersProvider,
              billPathBuilder: RoutePaths.branchCashierBill,
            ),
            routes: [
              GoRoute(
                path: 'table/:number/bill',
                builder: (context, state) {
                  final tableNumber =
                      int.parse(state.pathParameters['number']!);
                  return WaiterTableBillPage(
                    tableNumber: tableNumber,
                    cashierMode: true,
                    returnPath: RoutePaths.branchCashier,
                  );
                },
              ),
            ],
          ),
        ],
      ),
      ShellRoute(
        navigatorKey: kitchenShellKey,
        builder: (context, state, child) => KitchenShell(child: child),
        routes: [
          GoRoute(
            path: RoutePaths.branchKitchen,
            builder: (context, state) => const KitchenDisplayPage(),
          ),
        ],
      ),
      ShellRoute(
        navigatorKey: courierShellKey,
        builder: (context, state, child) => CourierShell(child: child),
        routes: [
          GoRoute(
            path: RoutePaths.courierTasks,
            builder: (context, state) => const CourierTasksPage(),
          ),
          GoRoute(
            path: RoutePaths.courierWallet,
            builder: (context, state) => const CourierWalletPage(),
          ),
          GoRoute(
            path: '/courier/order/:id/map',
            builder: (context, state) => CourierMapPage(
              orderId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      ShellRoute(
        navigatorKey: adminShellKey,
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: RoutePaths.adminDashboard,
            builder: (context, state) => const AdminDashboardPage(),
          ),
          GoRoute(
            path: RoutePaths.adminDineIn,
            builder: (context, state) => const AdminDineInPage(),
          ),
          GoRoute(
            path: RoutePaths.adminCashier,
            builder: (context, state) => BranchCashierPage(
              listProvider: dashboardDineInOrdersProvider,
              billPathBuilder: RoutePaths.adminCashierBill,
              showBranchName: true,
            ),
            routes: [
              GoRoute(
                path: 'table/:number/bill',
                builder: (context, state) {
                  final tableNumber =
                      int.parse(state.pathParameters['number']!);
                  return WaiterTableBillPage(
                    tableNumber: tableNumber,
                    cashierMode: true,
                    returnPath: RoutePaths.adminCashier,
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: RoutePaths.adminBranches,
            builder: (context, state) => const AdminBranchesPage(),
            routes: [
              GoRoute(
                path: ':branchId/delivery-zone',
                builder: (context, state) => AdminBranchDeliveryZonePage(
                  branchId: state.pathParameters['branchId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: RoutePaths.adminMenu,
            builder: (context, state) => const AdminMenuPage(),
          ),
          GoRoute(
            path: RoutePaths.adminUsers,
            builder: (context, state) => const AdminUsersPage(),
          ),
          GoRoute(
            path: RoutePaths.adminReports,
            builder: (context, state) => const AdminReportsPage(),
          ),
          GoRoute(
            path: RoutePaths.adminCourierTracking,
            builder: (context, state) => const AdminCourierTrackingPage(),
          ),
          GoRoute(
            path: RoutePaths.adminCashRemittances,
            builder: (context, state) => const AdminCashRemittancesPage(),
          ),
          GoRoute(
            path: RoutePaths.adminPendingReviews,
            builder: (context, state) => const AdminPendingReviewsPage(),
          ),
          GoRoute(
            path: RoutePaths.adminWaiterSettings,
            builder: (context, state) => const AdminWaiterSettingsPage(),
          ),
          GoRoute(
            path: RoutePaths.adminPaytrSettings,
            builder: (context, state) => const AdminPaytrSettingsPage(),
          ),
          GoRoute(
            path: RoutePaths.adminPromotions,
            builder: (context, state) => const AdminPromotionsPage(),
          ),
          GoRoute(
            path: RoutePaths.adminTools,
            builder: (context, state) => const AdminToolsPage(),
          ),
        ],
      ),
    ],
  );
}
