import 'package:flutter_test/flutter_test.dart';

import 'package:tostu_sahane/shared/domain/entities/order.dart';

Order _orderWithItems(List<CartItem> items, {bool isTableAddon = false}) {
  return Order(
    id: 'o1',
    orderNumber: 1,
    customerId: 'c1',
    customerName: 'Test',
    branchId: 'b1',
    items: items,
    totalAmount: 10,
    status: OrderStatus.preparing,
    createdAt: DateTime(2026, 1, 1),
    address: 'addr',
    paymentMethod: PaymentMethod.cashOnDelivery,
    orderType: OrderType.dineIn,
    isTableAddon: isTableAddon,
  );
}

void main() {
  test('hasKitchenItems is false for drink-only extras', () {
    final order = _orderWithItems(
      const [
        CartItem(
          id: '1',
          productId: 'extra_ayran',
          productNameKey: 'Ayran',
          unitPrice: 5,
          quantity: 2,
        ),
      ],
      isTableAddon: true,
    );
    expect(order.hasKitchenItems, isFalse);
  });

  test('hasKitchenItems is true when food item present', () {
    final order = _orderWithItems(
      const [
        CartItem(
          id: '1',
          productId: 'extra_ayran',
          productNameKey: 'Ayran',
          unitPrice: 5,
          quantity: 1,
        ),
        CartItem(
          id: '2',
          productId: 'ts_1',
          productNameKey: 'Tost',
          unitPrice: 50,
          quantity: 1,
        ),
      ],
      isTableAddon: true,
    );
    expect(order.hasKitchenItems, isTrue);
  });
}
