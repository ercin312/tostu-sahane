import '../../shared/domain/entities/order.dart';

double orderItemsTotal(Iterable<CartItem> items) =>
    items.fold(0.0, (sum, item) => sum + item.totalPrice);

/// Açık iç siparişten tek satır veya adet düşürür; kalem kalmazsa siparişi iptal eder.
Order applyDineInOrderItemRemoval({
  required Order order,
  required String cartItemId,
  int quantity = 1,
  String? actorId,
  String? actorName,
}) {
  if (!order.isDineIn || !order.isActive) {
    throw StateError('order_not_editable');
  }
  if (quantity < 1) {
    throw ArgumentError.value(quantity, 'quantity', 'must be >= 1');
  }

  final index = order.items.indexWhere((item) => item.id == cartItemId);
  if (index < 0) {
    throw StateError('item_not_found');
  }

  final item = order.items[index];
  final updatedItems = List<CartItem>.from(order.items);
  if (item.quantity <= quantity) {
    updatedItems.removeAt(index);
  } else {
    updatedItems[index] = item.copyWith(quantity: item.quantity - quantity);
  }

  if (updatedItems.isEmpty) {
    return order
        .copyWith(items: const [], totalAmount: 0)
        .withStatus(
          OrderStatus.cancelled,
          actorId: actorId,
          actorName: actorName,
        );
  }

  return order.copyWith(
    items: updatedItems,
    totalAmount: orderItemsTotal(updatedItems),
  );
}
