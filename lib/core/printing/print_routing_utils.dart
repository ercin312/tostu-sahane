import '../../shared/domain/entities/order.dart';
import '../../shared/domain/entities/print_routing_settings.dart';
import '../../shared/domain/entities/user.dart';

abstract final class PrintRoutingUtils {
  /// Ops rollerinde telefon siparişi otomatik basılabilir.
  static bool isPhoneAutoPrintRole(UserRole role) {
    return switch (role) {
      UserRole.kitchenStaff ||
      UserRole.branchManager ||
      UserRole.branchStaff ||
      UserRole.waiter ||
      UserRole.superAdmin =>
        true,
      _ => false,
    };
  }

  static bool shouldAutoPrint({
    required Order order,
    required UserRole role,
    required PrintRoutingSettings routing,
  }) {
    // Başarısız telefon siparişi asla otomatik basılmaz.
    // İptal fişi: phoneCancelPrintPending ile özel basım.
    if (order.phoneFailed) return false;
    if (order.status == OrderStatus.cancelled) {
      return order.isPhoneOrder &&
          order.phoneCancelPrintPending &&
          isPhoneAutoPrintRole(role);
    }
    if (order.isPhoneOrder) {
      // Ürün geldikçe anında bas; boş taslak basma.
      if (order.items.isEmpty) return false;
      final note = order.orderNote?.toLowerCase() ?? '';
      if (note.contains('otomatik kurtarma') ||
          note.contains('başarısız telefon') ||
          note.contains('başarısız arama')) {
        return false;
      }
      return isPhoneAutoPrintRole(role);
    }

    if (order.isDineIn) {
      return switch (role) {
        UserRole.kitchenStaff => routing.dineInAtKitchen,
        UserRole.branchManager || UserRole.branchStaff =>
          routing.dineInAtCashier,
        _ => false,
      };
    }
    if (order.isDelivery) {
      return switch (role) {
        UserRole.kitchenStaff => routing.deliveryAtKitchen,
        UserRole.branchManager || UserRole.branchStaff =>
          routing.deliveryAtCashier,
        _ => false,
      };
    }
    return false;
  }

  static String? resolvePrinterName({
    required UserRole role,
    required PrintRoutingSettings routing,
    String? localKitchenPrinter,
    String? localCashierPrinter,
    Order? order,
  }) {
    // Telefon: yöneticinin seçtiği mutfak veya kasa yazıcısı.
    if (order?.isPhoneOrder == true) {
      if (routing.phoneOrderPrinter == PhoneOrderPrinterTarget.cashier) {
        final configured = routing.cashierPrinterName.trim();
        if (configured.isNotEmpty) return configured;
        return localCashierPrinter ?? localKitchenPrinter;
      }
      final configured = routing.kitchenPrinterName.trim();
      if (configured.isNotEmpty) return configured;
      return localKitchenPrinter ?? localCashierPrinter;
    }

    if (role == UserRole.kitchenStaff) {
      final configured = routing.kitchenPrinterName.trim();
      if (configured.isNotEmpty) return configured;
      return localKitchenPrinter;
    }
    if (role == UserRole.branchManager ||
        role == UserRole.branchStaff ||
        role == UserRole.superAdmin) {
      final configured = routing.cashierPrinterName.trim();
      if (configured.isNotEmpty) return configured;
      return localCashierPrinter;
    }
    if (role == UserRole.waiter) {
      final configured = routing.kitchenPrinterName.trim();
      if (configured.isNotEmpty) return configured;
      return localKitchenPrinter;
    }
    return null;
  }
}
