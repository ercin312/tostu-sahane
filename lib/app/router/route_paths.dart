abstract final class RoutePaths {
  static const splash = '/';
  static const authLogin = '/auth/login';
  static const authOtp = '/auth/otp';

  static const customerHome = '/customer/home';
  static const customerOrders = '/customer/orders';
  static const customerProfile = '/customer/profile';
  static const customerCart = '/customer/cart';
  static const customerCheckout = '/customer/checkout';
  static const customerPayment = '/customer/payment';
  static const customerPaytrPayment = '/customer/paytr-payment';
  static String customerPaymentWithAmount(double amount) =>
      '/customer/payment?amount=$amount';
  static String customerPaytrPaymentWithAmount(double amount) =>
      '/customer/paytr-payment?amount=$amount';
  static const customerAddresses = '/customer/addresses';
  static const customerFavorites = '/customer/favorites';
  static const customerSavedCards = '/customer/saved-cards';
  static String customerProduct(String id) => '/customer/product/$id';
  static String customerOrderTrack(String id) => '/customer/order/$id/track';

  static const branchDashboard = '/branch/dashboard';
  static const branchOrders = '/branch/orders';
  static const branchMenu = '/branch/menu';
  static const branchReports = '/branch/reports';
  static const branchCashRemittances = '/branch/cash-remittances';
  static const branchWaiter = '/branch/waiter';
  static String branchWaiterOrder(int tableNumber) =>
      '/branch/waiter/table/$tableNumber';
  static String branchWaiterBill(int tableNumber) =>
      '/branch/waiter/table/$tableNumber/bill';
  static const branchDineIn = '/branch/dine-in';
  static const branchCashier = '/branch/cashier';
  static const branchKitchen = '/branch/kitchen';
  static String branchCashierBill(int tableNumber) =>
      '/branch/cashier/table/$tableNumber/bill';

  static const courierTasks = '/courier/tasks';
  static const courierWallet = '/courier/wallet';
  static String courierOrderMap(String orderId) => '/courier/order/$orderId/map';

  static const adminDashboard = '/admin/dashboard';
  static const adminDineIn = '/admin/dine-in';
  static const adminCashier = '/admin/cashier';
  static String adminCashierBill(int tableNumber) =>
      '/admin/cashier/table/$tableNumber/bill';
  static const adminBranches = '/admin/branches';
  static const adminMenu = '/admin/menu';
  static String adminBranchDeliveryZone(String branchId) =>
      '/admin/branches/$branchId/delivery-zone';
  static const adminUsers = '/admin/users';
  static const adminReports = '/admin/reports';
  static const adminCourierTracking = '/admin/courier-tracking';
  static const adminCashRemittances = '/admin/cash-remittances';
  static const adminPendingReviews = '/admin/pending-reviews';
  static const adminWaiterSettings = '/admin/waiter-settings';
  static const adminPaytrSettings = '/admin/paytr-settings';
  static const adminPromotions = '/admin/promotions';
  static const adminTools = '/admin/tools';

  static String homeForRole(String roleName) {
    return switch (roleName) {
      'customer' => customerHome,
      'branchManager' => branchDashboard,
      'branchStaff' => branchDashboard,
      'waiter' => branchWaiter,
      'kitchenStaff' => branchKitchen,
      'courier' => courierTasks,
      'superAdmin' => adminDashboard,
      _ => authLogin,
    };
  }
}
