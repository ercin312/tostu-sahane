import 'package:flutter_test/flutter_test.dart';
import 'package:tostu_sahane/core/orders/order_item_edits.dart';
import 'package:tostu_sahane/shared/domain/entities/order.dart';

Order _dineInOrder({required List<CartItem> items, double? total}) {
  return Order(
    id: 'order_1',
    orderNumber: 1,
    customerId: 'dine_in',
    customerName: 'Masa 1',
    branchId: 'b1',
    items: items,
    totalAmount: total ?? orderItemsTotal(items),
    status: OrderStatus.preparing,
    createdAt: DateTime(2026, 1, 1),
    address: 'Masa 1',
    paymentMethod: PaymentMethod.cashOnDelivery,
    orderType: OrderType.dineIn,
    tableNumber: 1,
  );
}

void main() {
  test('removes one unit and updates total', () {
    const item = CartItem(
      id: 'line_1',
      productId: 'p1',
      productNameKey: 'product.tost',
      unitPrice: 100,
      quantity: 2,
    );
    final order = _dineInOrder(items: const [item]);

    final updated = applyDineInOrderItemRemoval(
      order: order,
      cartItemId: 'line_1',
    );

    expect(updated.items.single.quantity, 1);
    expect(updated.totalAmount, 100);
    expect(updated.status, OrderStatus.preparing);
  });

  test('cancels order when last item removed', () {
    const item = CartItem(
      id: 'line_1',
      productId: 'p1',
      productNameKey: 'product.tost',
      unitPrice: 100,
      quantity: 1,
    );
    final order = _dineInOrder(items: const [item]);

    final updated = applyDineInOrderItemRemoval(
      order: order,
      cartItemId: 'line_1',
      actorId: 'w1',
      actorName: 'Garson',
    );

    expect(updated.items, isEmpty);
    expect(updated.status, OrderStatus.cancelled);
    expect(updated.statusActorNames[OrderStatus.cancelled], 'Garson');
  });
}
