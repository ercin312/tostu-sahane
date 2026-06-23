import '../../../shared/domain/entities/order.dart';

/// Açık masa oturumu: kapatılmamış iç siparişlerin toplamı.
class TableSession {
  const TableSession({
    required this.tableNumber,
    required this.openOrders,
  });

  final int tableNumber;
  final List<Order> openOrders;

  bool get isOpen => openOrders.isNotEmpty;

  double get totalAmount =>
      openOrders.fold(0, (sum, order) => sum + order.totalAmount);

  int get orderCount => openOrders.length;

  int get itemCount => openOrders.fold(
        0,
        (sum, order) =>
            sum + order.items.fold(0, (s, item) => s + item.quantity),
      );
}

bool isOpenDineInOrder(Order order) =>
    order.isDineIn && order.isActive;

List<TableSession> buildTableSessions({
  required int tableCount,
  required String branchId,
  required List<Order> orders,
}) {
  return List.generate(tableCount, (index) {
    final tableNumber = index + 1;
    final openOrders = orders
        .where(
          (o) =>
              o.branchId == branchId &&
              o.tableNumber == tableNumber &&
              isOpenDineInOrder(o),
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return TableSession(tableNumber: tableNumber, openOrders: openOrders);
  });
}
