import 'package:flutter_test/flutter_test.dart';

import 'package:tostu_sahane/core/printing/print_routing_utils.dart';
import 'package:tostu_sahane/shared/domain/entities/order.dart';
import 'package:tostu_sahane/shared/domain/entities/print_routing_settings.dart';
import 'package:tostu_sahane/shared/domain/entities/user.dart';

void main() {
  const routing = PrintRoutingSettings(
    dineInAtKitchen: true,
    dineInAtCashier: false,
    deliveryAtKitchen: false,
    deliveryAtCashier: true,
  );

  final dineIn = Order(
    id: 'o1',
    orderNumber: 1,
    customerId: 'w1',
    customerName: 'Waiter',
    branchId: 'b1',
    items: const [],
    totalAmount: 10,
    status: OrderStatus.received,
    createdAt: DateTime.now(),
    address: 'Table 1',
    paymentMethod: PaymentMethod.cashOnDelivery,
    orderType: OrderType.dineIn,
    tableNumber: 1,
  );

  test('kitchen prints dine-in, cashier does not', () {
    expect(
      PrintRoutingUtils.shouldAutoPrint(
        order: dineIn,
        role: UserRole.kitchenStaff,
        routing: routing,
        dineInPrintingEnabled: true,
      ),
      isTrue,
    );
    expect(
      PrintRoutingUtils.shouldAutoPrint(
        order: dineIn,
        role: UserRole.branchManager,
        routing: routing,
        dineInPrintingEnabled: true,
      ),
      isFalse,
    );
  });

  test('admin printer name overrides local selection', () {
    expect(
      PrintRoutingUtils.resolvePrinterName(
        role: UserRole.kitchenStaff,
        routing: const PrintRoutingSettings(kitchenPrinterName: 'Mutfak POS'),
        localKitchenPrinter: 'Local A',
        localCashierPrinter: 'Local B',
      ),
      'Mutfak POS',
    );
  });
}
