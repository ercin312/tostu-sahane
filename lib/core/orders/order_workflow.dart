import '../../shared/domain/entities/order.dart';
import '../../shared/domain/entities/user.dart';

enum OrderWorkflowAction {
  accept,
  markReady,
  reject,
  assignCourier,
  markDelivered,
}

abstract final class OrderWorkflow {
  static bool sameBranch(User user, Order order) {
    if (user.branchId == null) return false;
    return user.branchId == order.branchId;
  }

  static bool canPerform(User user, Order order, OrderWorkflowAction action) {
    return switch (user.role) {
      UserRole.superAdmin => _adminCan(action, order),
      UserRole.branchManager || UserRole.branchStaff =>
        sameBranch(user, order) && _branchCan(action, order),
      UserRole.courier => _courierCan(user, order, action),
      UserRole.kitchenStaff =>
        order.isDineIn && sameBranch(user, order) && _kitchenCan(action, order),
      UserRole.waiter => false,
      UserRole.customer => false,
    };
  }

  static OrderStatus? targetStatus(Order order, OrderWorkflowAction action) {
    return switch (action) {
      OrderWorkflowAction.accept =>
        order.status == OrderStatus.received ? OrderStatus.preparing : null,
      OrderWorkflowAction.markReady =>
        order.status == OrderStatus.preparing
            ? OrderStatus.waitingCourier
            : null,
      OrderWorkflowAction.reject =>
        order.canBranchReject ? OrderStatus.cancelled : null,
      OrderWorkflowAction.assignCourier =>
        order.status == OrderStatus.waitingCourier && order.courierId == null
            ? OrderStatus.onTheWay
            : null,
      OrderWorkflowAction.markDelivered =>
        order.status == OrderStatus.onTheWay ? OrderStatus.delivered : null,
    };
  }

  static bool _branchCan(OrderWorkflowAction action, Order order) {
    return switch (action) {
      OrderWorkflowAction.accept => order.status == OrderStatus.received,
      OrderWorkflowAction.markReady => order.status == OrderStatus.preparing,
      OrderWorkflowAction.reject => order.canBranchReject,
      _ => false,
    };
  }

  static bool _adminCan(OrderWorkflowAction action, Order order) {
    return switch (action) {
      OrderWorkflowAction.accept => order.status == OrderStatus.received,
      OrderWorkflowAction.markReady => order.status == OrderStatus.preparing,
      OrderWorkflowAction.reject => order.canBranchReject,
      _ => false,
    };
  }

  static bool _kitchenCan(OrderWorkflowAction action, Order order) {
    return switch (action) {
      OrderWorkflowAction.accept => order.status == OrderStatus.received,
      OrderWorkflowAction.markReady => order.status == OrderStatus.preparing,
      _ => false,
    };
  }

  static bool _courierCan(
    User user,
    Order order,
    OrderWorkflowAction action,
  ) {
    return switch (action) {
      OrderWorkflowAction.assignCourier =>
        order.status == OrderStatus.waitingCourier &&
            order.courierId == null &&
            (user.branchId == null || user.branchId == order.branchId),
      OrderWorkflowAction.markDelivered =>
        order.courierId == user.id && order.status == OrderStatus.onTheWay,
      _ => false,
    };
  }
}

bool userCanManageBranchOrders(User user, String branchId) {
  if (user.role == UserRole.superAdmin) return true;
  return (user.role == UserRole.branchManager ||
          user.role == UserRole.branchStaff) &&
      user.branchId == branchId;
}
