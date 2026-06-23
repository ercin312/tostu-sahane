import 'package:flutter_test/flutter_test.dart';
import 'package:tostu_sahane/shared/data/datasources/mock_api_datasource.dart';
import 'package:tostu_sahane/shared/domain/entities/order.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MockApiDataSource order lifecycle', () {
    late MockApiDataSource api;

    setUp(() {
      api = MockApiDataSource();
    });

    test('place → accept → deliver flow', () async {
      final order = api.buildNewOrder(
        items: const [],
        totalAmount: 120,
        customerId: 'c1',
        customerName: 'Test',
        branchId: 'branch_1',
        address: 'Test Address',
        paymentMethod: PaymentMethod.cashOnDelivery,
      );
      await api.createOrder(order);

      final preparing =
          await api.updateOrderStatus(order.id, OrderStatus.preparing);
      expect(preparing.status, OrderStatus.preparing);

      final waiting = await api.updateOrderStatus(
        order.id,
        OrderStatus.waitingCourier,
      );
      expect(waiting.status, OrderStatus.waitingCourier);

      final onWay = await api.assignCourier(order.id, 'u2', 'Kurye');
      expect(onWay.status, OrderStatus.onTheWay);
      expect(onWay.courierId, 'u2');

      final delivered =
          await api.updateOrderStatus(order.id, OrderStatus.delivered);
      expect(delivered.status, OrderStatus.delivered);
      expect(delivered.deliveryDurationMinutes, isNotNull);
    });

    test('cached-only order can be updated after mock sync', () async {
      final order = api.buildNewOrder(
        items: const [],
        totalAmount: 90,
        customerId: 'c1',
        customerName: 'Test',
        branchId: 'branch_1',
        address: 'Test',
        paymentMethod: PaymentMethod.cashOnDelivery,
      );
      api.upsertOrder(order);

      final preparing = await api.updateOrderStatus(
        order.id,
        OrderStatus.preparing,
        actorId: 'u1',
        actorName: 'Manager',
      );
      expect(preparing.status, OrderStatus.preparing);
      expect(preparing.actorNameFor(OrderStatus.preparing), 'Manager');
    });

    test('cancel order', () async {
      final order = api.buildNewOrder(
        items: const [],
        totalAmount: 80,
        customerId: 'c1',
        customerName: 'Test',
        branchId: 'branch_1',
        address: 'Test',
        paymentMethod: PaymentMethod.cashOnDelivery,
      );
      await api.createOrder(order);
      final cancelled = await api.cancelOrder(order.id);
      expect(cancelled.status, OrderStatus.cancelled);
    });
  });
}
