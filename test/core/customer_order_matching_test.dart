import 'package:flutter_test/flutter_test.dart';
import 'package:tostu_sahane/core/utils/customer_order_matching.dart';
import 'package:tostu_sahane/core/utils/phone_digits.dart';
import 'package:tostu_sahane/features/auth/presentation/providers/auth_provider.dart';
import 'package:tostu_sahane/shared/domain/entities/order.dart';
import 'package:tostu_sahane/shared/domain/entities/user.dart';

void main() {
  AuthState auth({
    required String id,
    String phone = '',
    String? email,
  }) {
    return AuthState(
      user: User(id: id, name: 'Test', role: UserRole.customer),
      phone: phone,
      email: email,
    );
  }

  Order sampleOrder({
    required String customerId,
    OrderStatus status = OrderStatus.delivered,
    String? customerPhone,
  }) {
    return Order(
      id: 'o1',
      orderNumber: 1,
      customerId: customerId,
      customerName: 'Test',
      branchId: 'branch_1',
      items: const [],
      totalAmount: 100,
      status: status,
      createdAt: DateTime(2026, 1, 1),
      address: 'Addr',
      paymentMethod: PaymentMethod.cashOnDelivery,
      customerPhone: customerPhone,
    );
  }

  test('normalizeTrPhoneDigits strips +90 and leading 0', () {
    expect(normalizeTrPhoneDigits('+90 555 123 45 67'), '5551234567');
    expect(normalizeTrPhoneDigits('05551234567'), '5551234567');
    expect(normalizeTrPhoneDigits('5551234567'), '5551234567');
  });

  test('matches exact customer id', () {
    final session = auth(id: 'customer_5551234567', phone: '5551234567');
    expect(
      orderBelongsToCustomer(
        sampleOrder(customerId: 'customer_5551234567'),
        session,
      ),
      isTrue,
    );
  });

  test('matches legacy phone-formatted customer id', () {
    final session = auth(id: 'customer_5551234567', phone: '5551234567');
    expect(
      orderBelongsToCustomer(
        sampleOrder(customerId: 'customer_05551234567'),
        session,
      ),
      isTrue,
    );
  });

  test('matches customer_phone when customer_id differs', () {
    final session = auth(id: 'customer_5551234567', phone: '5551234567');
    final order = sampleOrder(
      customerId: 'legacy_id',
      customerPhone: '05551234567',
    );
    expect(orderBelongsToCustomer(order, session), isTrue);
  });

  test('matches phone_ customer_id from phone AI with +90 auth phone', () {
    final session = auth(id: 'customer_5551234567', phone: '+905551234567');
    final order = sampleOrder(
      customerId: 'phone_5551234567',
      customerPhone: '0555 123 4567',
    );
    expect(orderBelongsToCustomer(order, session), isTrue);
  });

  test('matches when auth phone has leading 0 and order uses display format', () {
    final session = auth(id: 'customer_xyz', phone: '05551234567');
    final order = sampleOrder(
      customerId: 'phone_5551234567',
      customerPhone: '0555 123 4567',
    );
    expect(orderBelongsToCustomer(order, session), isTrue);
  });

  test('onTheWay delivery order stays active for customer', () {
    final session = auth(id: 'customer_5551234567', phone: '5551234567');
    final onTheWay = sampleOrder(
      customerId: 'customer_5551234567',
      status: OrderStatus.onTheWay,
      customerPhone: '5551234567',
    );
    expect(orderBelongsToCustomer(onTheWay, session), isTrue);
    expect(onTheWay.isActive, isTrue);
  });

  test('delivered orders are not active', () {
    final delivered = sampleOrder(
      customerId: 'customer_5551234567',
      status: OrderStatus.delivered,
    );
    expect(delivered.isActive, isFalse);
  });
}
