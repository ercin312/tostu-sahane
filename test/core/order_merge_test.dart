import 'package:flutter_test/flutter_test.dart';
import 'package:tostu_sahane/core/orders/order_merge.dart';
import 'package:tostu_sahane/core/utils/order_status_utils.dart';
import 'package:tostu_sahane/shared/domain/entities/order.dart';

Order _sample({
  OrderStatus status = OrderStatus.received,
  String? courierId,
  double? courierLat,
}) {
  return Order(
    id: 'order_1',
    orderNumber: 1001,
    customerId: 'customer_555',
    customerName: 'Test',
    branchId: 'branch_1',
    items: const [],
    totalAmount: 100,
    status: status,
    createdAt: DateTime(2026, 1, 1, 12),
    address: 'Test Address',
    paymentMethod: PaymentMethod.cashOnDelivery,
    statusTimestamps: {OrderStatus.received: DateTime(2026, 1, 1, 12)},
    courierId: courierId,
    courierLatitude: courierLat,
  );
}

void main() {
  group('OrderStatusUtils', () {
    test('fulfillment pipeline excludes cancelled', () {
      expect(
        OrderStatusUtils.fulfillmentPipeline,
        isNot(contains(OrderStatus.cancelled)),
      );
    });

    test('cancelled step index is not treated as past for active orders', () {
      expect(
        OrderStatusUtils.isPastFulfillmentStep(
          OrderStatus.cancelled,
          OrderStatus.onTheWay,
        ),
        isFalse,
      );
    });

    test('valid transitions follow workflow', () {
      expect(
        OrderStatusUtils.isValidTransition(
          OrderStatus.received,
          OrderStatus.preparing,
        ),
        isTrue,
      );
      expect(
        OrderStatusUtils.isValidTransition(
          OrderStatus.onTheWay,
          OrderStatus.delivered,
        ),
        isTrue,
      );
      expect(
        OrderStatusUtils.isValidTransition(
          OrderStatus.preparing,
          OrderStatus.delivered,
        ),
        isTrue,
      );
      expect(
        OrderStatusUtils.isValidTransition(
          OrderStatus.received,
          OrderStatus.delivered,
        ),
        isTrue,
      );
      expect(
        OrderStatusUtils.isValidTransition(
          OrderStatus.waitingCourier,
          OrderStatus.delivered,
        ),
        isFalse,
      );
    });
  });

  group('OrderMerge', () {
    test('rejects premature delivered status from remote', () {
      final local = _sample(status: OrderStatus.waitingCourier);
      final remote = local.copyWith(status: OrderStatus.delivered);

      final merged = OrderMerge.resolve(local, remote);

      expect(merged.status, OrderStatus.waitingCourier);
    });

    test('accepts valid delivered transition from remote', () {
      final local = _sample(status: OrderStatus.onTheWay, courierId: 'u2');
      final remote = local.withStatus(OrderStatus.delivered);

      final merged = OrderMerge.resolve(local, remote);

      expect(merged.status, OrderStatus.delivered);
    });

    test('keeps courier location when rejecting invalid status jump', () {
      final local = _sample(status: OrderStatus.waitingCourier);
      final remote = local.copyWith(
        status: OrderStatus.delivered,
        courierId: 'u2',
        courierLatitude: 41.0,
      );

      final merged = OrderMerge.resolve(local, remote);

      expect(merged.status, OrderStatus.waitingCourier);
      expect(merged.courierId, 'u2');
      expect(merged.courierLatitude, 41.0);
    });

    test('preserves remote preparation tags when local snapshot is stale', () {
      final local = _sample(status: OrderStatus.preparing).copyWith(
        orderType: OrderType.dineIn,
        tableNumber: 3,
      );
      final remote = local.copyWith(
        preparationTags: const ['spicy', 'less_cheese'],
      );

      final merged = OrderMerge.resolve(local, remote);

      expect(merged.preparationTags, ['spicy', 'less_cheese']);
    });

    test('accepts dine-in bill close from remote delivered status', () {
      final local = _sample(status: OrderStatus.preparing).copyWith(
        orderType: OrderType.dineIn,
        tableNumber: 7,
      );
      final remote = local.withStatus(OrderStatus.delivered);

      final merged = OrderMerge.resolve(local, remote);

      expect(merged.status, OrderStatus.delivered);
    });
  });
}
