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

  test('kitchen mark ready advances dine-in to ready not waitingCourier', () {
    final preparing = dineInOrder.copyWith(status: OrderStatus.preparing);
    expect(
      OrderWorkflow.targetStatus(preparing, OrderWorkflowAction.markReady),
      OrderStatus.ready,
    );

    final delivery = preparing.copyWith(orderType: OrderType.delivery);
    expect(
      OrderWorkflow.targetStatus(delivery, OrderWorkflowAction.markReady),
      OrderStatus.waitingCourier,
    );
  });

  test('courier cannot take dine-in orders even in legacy waitingCourier', () {
    const courier = User(
      id: 'u2',
      name: 'Kurye',
      role: UserRole.courier,
      branchId: 'branch_1',
    );
    final legacyDineIn = dineInOrder.copyWith(
      status: OrderStatus.waitingCourier,
    );
    expect(
      OrderWorkflow.canPerform(
        courier,
        legacyDineIn,
        OrderWorkflowAction.assignCourier,
      ),
      isFalse,
    );
  });

  test('branch accept is delivery-only', () {
    const manager = User(
      id: 'u1',
      name: 'Şube',
      role: UserRole.branchManager,
      branchId: 'branch_1',
    );
    final receivedDineIn = dineInOrder;
    expect(
      OrderWorkflow.canPerform(
        manager,
        receivedDineIn,
        OrderWorkflowAction.accept,
      ),
      isFalse,
    );
    expect(
      OrderWorkflow.canPerform(
        manager,
        receivedDineIn.copyWith(orderType: OrderType.delivery),
        OrderWorkflowAction.accept,
      ),
      isTrue,
    );
  });
}
