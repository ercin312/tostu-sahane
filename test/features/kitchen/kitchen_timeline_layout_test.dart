import 'package:flutter_test/flutter_test.dart';

import 'package:tostu_sahane/features/kitchen/presentation/utils/kitchen_timeline_layout.dart';
import 'package:tostu_sahane/shared/domain/entities/order.dart';

Order _order(int index, DateTime createdAt) {
  return Order(
    id: 'o$index',
    orderNumber: index,
    customerId: 'c',
    customerName: 'Test',
    branchId: 'b1',
    items: const [],
    totalAmount: 10,
    status: OrderStatus.received,
    createdAt: createdAt,
    address: 'Table $index',
    paymentMethod: PaymentMethod.cashOnDelivery,
    orderType: OrderType.dineIn,
    tableNumber: index,
  );
}

List<Order> _newestFirst(int count) {
  final base = DateTime(2026, 1, 1, 12);
  return List.generate(
    count,
    (i) => _order(count - i, base.add(Duration(minutes: i))),
  );
}

void main() {
  test('1-2 orders stay in a single full-width lane', () {
    final one = _newestFirst(1);
    expect(
      KitchenTimelineLayout.distributeLanes(one, maxColumns: 3).length,
      1,
    );
    expect(
      KitchenTimelineLayout.distributeLanes(one, maxColumns: 3).first.length,
      1,
    );

    final two = _newestFirst(2);
    final lanes = KitchenTimelineLayout.distributeLanes(two, maxColumns: 3);
    expect(lanes.length, 1);
    expect(lanes.first.map((o) => o.orderNumber).toList(), [2, 1]);
  });

  test('3+ orders on wide screen: left(2) middle(3) right(rest)', () {
    final six = _newestFirst(6);
    final lanes = KitchenTimelineLayout.distributeLanes(six, maxColumns: 3);

    expect(lanes.length, 3);
    expect(lanes[0].map((o) => o.orderNumber).toList(), [6, 5]);
    expect(lanes[1].map((o) => o.orderNumber).toList(), [4, 3, 2]);
    expect(lanes[2].map((o) => o.orderNumber).toList(), [1]);
  });

  test('nine orders fill all three columns downward', () {
    final nine = _newestFirst(9);
    final lanes = KitchenTimelineLayout.distributeLanes(nine, maxColumns: 3);

    expect(lanes[0].length, 2);
    expect(lanes[1].length, 3);
    expect(lanes[2].length, 4);
    expect(lanes[0].first.orderNumber, 9);
    expect(lanes[2].last.orderNumber, 1);
  });

  test('two-column layout: left(2) then right(rest)', () {
    final five = _newestFirst(5);
    final lanes = KitchenTimelineLayout.distributeLanes(five, maxColumns: 2);

    expect(lanes.length, 2);
    expect(lanes[0].map((o) => o.orderNumber).toList(), [5, 4]);
    expect(lanes[1].map((o) => o.orderNumber).toList(), [3, 2, 1]);
  });
}
