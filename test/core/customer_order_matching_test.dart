import 'package:flutter_test/flutter_test.dart';
import 'package:tostu_sahane/core/utils/customer_order_matching.dart';
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
    );
  }

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

  test('delivered orders are not active', () {
    final delivered = sampleOrder(
      customerId: 'customer_5551234567',
      status: OrderStatus.delivered,
    );
    expect(delivered.isActive, isFalse);
  });
}
