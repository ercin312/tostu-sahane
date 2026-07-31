import 'package:flutter_test/flutter_test.dart';
import 'package:tostu_sahane/core/utils/format_utils.dart';
import 'package:tostu_sahane/shared/data/mappers/entity_mappers.dart';
import 'package:tostu_sahane/shared/data/models/api_models.dart';
import 'package:tostu_sahane/shared/domain/entities/order.dart';

void main() {
  test('UTC phone order instant formats as Turkey wall clock', () {
    // 20:15 UTC = 23:15 TR
    final utc = DateTime.parse('2026-07-25T20:15:00.000Z');
    expect(FormatUtils.dateTimeTr(utc), '25.07.2026 23:15');
  });

  test('mapper keeps UTC instant from Firestore Z timestamp', () {
    final model = OrderModel(
      id: 'order_1',
      orderNumber: 1,
      customerId: 'phone_555',
      customerName: 'Ali',
      branchId: 'branch_1',
      items: const [],
      totalAmount: 0,
      status: 'received',
      createdAt: '2026-07-25T20:15:00.000Z',
      address: 'Adres',
      paymentMethod: 'cashOnDelivery',
      orderSource: 'phone',
    );
    final order = EntityMappers.toOrder(model);
    expect(order.createdAt.isUtc, isTrue);
    expect(order.createdAt.toUtc().hour, 20);
    expect(FormatUtils.dateTimeTr(order.createdAt), '25.07.2026 23:15');
  });
}
