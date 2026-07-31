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

  final phone = Order(
    id: 'o_phone',
    orderNumber: 2,
    customerId: 'phone_1',
    customerName: 'Telefon',
    branchId: 'b1',
    items: const [
      CartItem(
        id: 'l1',
        productId: 'w_kasarli_sade',
        productNameKey: 'KAŞARLI',
        unitPrice: 180,
        quantity: 1,
      ),
    ],
    totalAmount: 180,
    status: OrderStatus.received,
    createdAt: DateTime.now(),
    address: 'Alanya',
    paymentMethod: PaymentMethod.cashOnDelivery,
    orderType: OrderType.delivery,
    orderSource: OrderSource.phone,
    customerPhone: '0555 111 2233',
  );

  test('empty phone draft does not auto-print', () {
    final emptyPhone = phone.copyWith(items: const [], totalAmount: 0);
    expect(
      PrintRoutingUtils.shouldAutoPrint(
        order: emptyPhone,
        role: UserRole.kitchenStaff,
        routing: routing,
      ),
      isFalse,
    );
  });

  test('failed phone order does not auto-print', () {
    final failed = phone.copyWith(
      phoneFailed: true,
      status: OrderStatus.cancelled,
      items: const [],
      totalAmount: 0,
      orderNote: 'Başarısız telefon siparişi',
    );
    expect(
      PrintRoutingUtils.shouldAutoPrint(
        order: failed,
        role: UserRole.branchManager,
        routing: routing,
      ),
      isFalse,
    );
  });

  test('phone order with recovery note does not auto-print', () {
    final recovered = phone.copyWith(
      orderNote: 'Otomatik kurtarma: ajan create_phone_order çağırmadı',
    );
    expect(
      PrintRoutingUtils.shouldAutoPrint(
        order: recovered,
        role: UserRole.kitchenStaff,
        routing: routing,
      ),
      isFalse,
    );
  });

  test('kitchen prints dine-in, cashier does not', () {
    expect(
      PrintRoutingUtils.shouldAutoPrint(
        order: dineIn,
        role: UserRole.kitchenStaff,
        routing: routing,
      ),
      isTrue,
    );
    expect(
      PrintRoutingUtils.shouldAutoPrint(
        order: dineIn,
        role: UserRole.branchManager,
        routing: routing,
      ),
      isFalse,
    );
  });

  test('dine-in kitchen print off when admin disables', () {
    expect(
      PrintRoutingUtils.shouldAutoPrint(
        order: dineIn,
        role: UserRole.kitchenStaff,
        routing: const PrintRoutingSettings(dineInAtKitchen: false),
      ),
      isFalse,
    );
  });

  test('phone order auto-prints even when delivery kitchen flag is off', () {
    expect(
      PrintRoutingUtils.shouldAutoPrint(
        order: phone,
        role: UserRole.kitchenStaff,
        routing: routing,
      ),
      isTrue,
    );
    expect(
      PrintRoutingUtils.shouldAutoPrint(
        order: phone,
        role: UserRole.branchManager,
        routing: routing,
      ),
      isTrue,
    );
    expect(
      PrintRoutingUtils.shouldAutoPrint(
        order: phone,
        role: UserRole.waiter,
        routing: routing,
      ),
      isTrue,
    );
  });

  test('phone order printer follows admin kitchen/cashier target', () {
    expect(
      PrintRoutingUtils.resolvePrinterName(
        role: UserRole.branchManager,
        routing: const PrintRoutingSettings(
          phoneOrderPrinter: PhoneOrderPrinterTarget.kitchen,
          kitchenPrinterName: 'Mutfak POS',
          cashierPrinterName: 'Kasa POS',
        ),
        localKitchenPrinter: 'Local Kitchen',
        localCashierPrinter: 'Local Cashier',
        order: phone,
      ),
      'Mutfak POS',
    );
    expect(
      PrintRoutingUtils.resolvePrinterName(
        role: UserRole.kitchenStaff,
        routing: const PrintRoutingSettings(
          phoneOrderPrinter: PhoneOrderPrinterTarget.cashier,
          kitchenPrinterName: 'Mutfak POS',
          cashierPrinterName: 'Kasa POS',
        ),
        localKitchenPrinter: 'Local Kitchen',
        localCashierPrinter: 'Local Cashier',
        order: phone,
      ),
      'Kasa POS',
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
