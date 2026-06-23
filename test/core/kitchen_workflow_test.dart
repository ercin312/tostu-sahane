import 'package:flutter_test/flutter_test.dart';

import 'package:tostu_sahane/core/orders/order_workflow.dart';
import 'package:tostu_sahane/shared/domain/entities/order.dart';
import 'package:tostu_sahane/shared/domain/entities/user.dart';

void main() {
  const kitchenUser = User(
    id: 'k1',
    name: 'Mutfak',
    role: UserRole.kitchenStaff,
    branchId: 'branch_1',
  );

  final dineInOrder = Order(
    id: 'o1',
    orderNumber: 101,
    customerId: 'w1',
    customerName: 'Garson',
    branchId: 'branch_1',
    items: const [],
    totalAmount: 50,
    status: OrderStatus.received,
    createdAt: DateTime.now(),
    address: 'Masa 3',
    paymentMethod: PaymentMethod.cashOnDelivery,
    orderType: OrderType.dineIn,
    tableNumber: 3,
  );

  test('kitchen staff can accept dine-in orders only', () {
    expect(
      OrderWorkflow.canPerform(
        kitchenUser,
        dineInOrder,
        OrderWorkflowAction.accept,
      ),
      isTrue,
    );
    expect(
      OrderWorkflow.canPerform(
        kitchenUser,
        dineInOrder.copyWith(orderType: OrderType.delivery),
        OrderWorkflowAction.accept,
      ),
      isFalse,
    );
  });

  test('kitchen staff cannot reject or assign courier', () {
    expect(
      OrderWorkflow.canPerform(
        kitchenUser,
        dineInOrder,
        OrderWorkflowAction.reject,
      ),
      isFalse,
    );
    expect(
      OrderWorkflow.canPerform(
        kitchenUser,
        dineInOrder,
        OrderWorkflowAction.assignCourier,
      ),
      isFalse,
    );
  });
}
