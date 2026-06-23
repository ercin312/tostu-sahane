import '../../shared/domain/entities/order.dart';
import '../../shared/domain/entities/print_routing_settings.dart';
import '../../shared/domain/entities/user.dart';

abstract final class PrintRoutingUtils {
  static bool shouldAutoPrint({
    required Order order,
    required UserRole role,
    required PrintRoutingSettings routing,
    required bool dineInPrintingEnabled,
  }) {
    if (order.isDineIn) {
      if (!dineInPrintingEnabled) return false;
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
  }) {
    if (role == UserRole.kitchenStaff) {
      final configured = routing.kitchenPrinterName.trim();
      if (configured.isNotEmpty) return configured;
      return localKitchenPrinter;
    }
    if (role == UserRole.branchManager || role == UserRole.branchStaff) {
      final configured = routing.cashierPrinterName.trim();
      if (configured.isNotEmpty) return configured;
      return localCashierPrinter;
    }
    return null;
  }
}
