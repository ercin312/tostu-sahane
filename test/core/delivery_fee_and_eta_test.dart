import 'package:flutter_test/flutter_test.dart';

import 'package:tostu_sahane/core/utils/delivery_eta_utils.dart';
import 'package:tostu_sahane/core/utils/delivery_fee_utils.dart';
import 'package:tostu_sahane/shared/domain/entities/branch.dart';
import 'package:tostu_sahane/shared/domain/entities/order.dart';

void main() {
  const branch = Branch(
    id: 'b1',
    name: 'Test',
    address: 'Addr',
    latitude: 41.0,
    longitude: 29.0,
    baseDeliveryFee: 15,
    freeDeliveryMinOrder: 150,
    deliveryFeePerKm: 5,
    prepTimeMinutes: 15,
  );

  test('DeliveryFeeUtils free above minimum order', () {
    expect(
      DeliveryFeeUtils.calculate(branch: branch, subtotal: 200),
      0,
    );
  });

  test('DeliveryFeeUtils adds distance component', () {
    final fee = DeliveryFeeUtils.calculate(
      branch: branch,
      subtotal: 50,
      deliveryLat: 41.01,
      deliveryLng: 29.01,
    );
    expect(fee, greaterThan(15));
  });

  test('DeliveryEtaUtils estimates prep plus travel', () {
    final eta = DeliveryEtaUtils.estimateTotalMinutes(
      branch: branch,
      deliveryLat: 41.02,
      deliveryLng: 29.02,
    );
    expect(eta, greaterThan(branch.prepTimeMinutes));
  });

  test('DeliveryEtaUtils remaining decreases by status', () {
    final order = Order(
      id: 'o1',
      orderNumber: 1,
      customerId: 'c1',
      customerName: 'Test',
      branchId: 'b1',
      items: const [],
      totalAmount: 100,
      status: OrderStatus.onTheWay,
      createdAt: DateTime.now(),
      address: 'Addr',
      paymentMethod: PaymentMethod.cashOnDelivery,
      estimatedDeliveryMinutes: 40,
    );
    final remaining =
        DeliveryEtaUtils.remainingMinutes(order: order, branch: branch);
    expect(remaining, lessThan(40));
    expect(remaining, greaterThan(0));
  });
}
