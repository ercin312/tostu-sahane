import '../../domain/entities/courier_cash_remittance.dart';
import '../../domain/entities/courier_wallet.dart';
import '../../domain/entities/order.dart';
import 'app_repositories.dart';import 'courier_cash_remittance_repository.dart';

class CourierWalletRepository {
  CourierWalletRepository({
    required OrderRepository orders,
    required CourierCashRemittanceRepository remittances,
  })  : _orders = orders,
        _remittances = remittances;

  final OrderRepository _orders;
  final CourierCashRemittanceRepository _remittances;

  Future<List<Order>> _deliveredOrders(String courierId) async {
    final orders = await _orders.getOrders();
    return orders
        .where(
          (o) => o.courierId == courierId && o.status == OrderStatus.delivered,
        )
        .toList()
      ..sort(
        (a, b) => _deliveredAt(b).compareTo(_deliveredAt(a)),
      );
  }

  DateTime _deliveredAt(Order order) =>
      order.atStatus(OrderStatus.delivered) ?? order.createdAt;

  double _collectibleAmount(Order order) {
    if (order.paymentMethod == PaymentMethod.cashOnDelivery ||
        order.paymentMethod == PaymentMethod.cardOnDelivery) {
      return order.totalAmount;
    }
    return 0;
  }

  Future<CourierWalletSummary> getSummary(String courierId) async {
    final delivered = await _deliveredOrders(courierId);
    final remittanceList = await _remittances.getForCourier(courierId);
    final today = DateTime.now();

    final todayDeliveries =
        delivered.where((o) => _isSameDay(_deliveredAt(o), today));
    var todayCash = 0.0;
    var todayCard = 0.0;
    for (final order in todayDeliveries) {
      if (order.paymentMethod == PaymentMethod.cashOnDelivery) {
        todayCash += order.totalAmount;
      } else if (order.paymentMethod == PaymentMethod.cardOnDelivery) {
        todayCard += order.totalAmount;
      }
    }

    final cashHeld =
        delivered.fold<double>(0, (sum, o) => sum + _collectibleAmount(o));

    final approvedRemitted = remittanceList
        .where((r) => r.status == CourierCashRemittanceStatus.approved)
        .fold<double>(0, (sum, r) => sum + r.amount);

    final pendingRemitted = remittanceList
        .where((r) => r.status == CourierCashRemittanceStatus.pending)
        .fold<double>(0, (sum, r) => sum + r.amount);

    return CourierWalletSummary(
      todayDeliveries: todayDeliveries.length,
      todayCash: todayCash,
      todayCard: todayCard,
      availableBalance: cashHeld - approvedRemitted - pendingRemitted,
      pendingPayout: pendingRemitted,
      totalEarned: cashHeld,
      approvedRemitted: approvedRemitted,
    );
  }

  Future<List<CourierWalletEntry>> getHistory(String courierId) async {
    final delivered = await _deliveredOrders(courierId);
    final remittanceList = await _remittances.getForCourier(courierId);

    final deliveryEntries = delivered.map((order) {
      final kind = switch (order.paymentMethod) {
        PaymentMethod.cashOnDelivery => CourierWalletPaymentKind.cash,
        PaymentMethod.cardOnDelivery => CourierWalletPaymentKind.card,
        PaymentMethod.onlineCard => CourierWalletPaymentKind.online,
      };
      return CourierWalletEntry(
        id: 'delivery_${order.id}',
        type: CourierWalletEntryType.delivery,
        amount: order.totalAmount,
        createdAt: _deliveredAt(order),
        orderNumber: order.orderNumber,
        paymentKind: kind,
      );
    });

    final remittanceEntries = remittanceList.map(
      (r) => CourierWalletEntry(
        id: r.id,
        type: CourierWalletEntryType.payout,
        amount: r.amount,
        createdAt: r.requestedAt,
        paymentKind: CourierWalletPaymentKind.payout,
        remittanceStatus: r.status,
        note: r.status == CourierCashRemittanceStatus.rejected
            ? r.rejectionReason
            : r.courierNote,
      ),
    );

    final all = [...deliveryEntries, ...remittanceEntries]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  Future<CourierCashRemittance> requestRemittance({
    required String courierId,
    required String courierName,
    required String branchId,
    required double amount,
    String? courierNote,
  }) async {
    final summary = await getSummary(courierId);
    if (amount <= 0 || amount > summary.availableBalance) {
      throw CourierPayoutException('courier_payout_invalid_amount');
    }

    return _remittances.requestRemittance(
      courierId: courierId,
      courierName: courierName,
      branchId: branchId,
      amount: amount,
      courierNote: courierNote,
    );
  }

  Future<String> resolveCourierBranchId(String courierId) async {
    final orders = await _deliveredOrders(courierId);
    if (orders.isNotEmpty) return orders.first.branchId;
    final all = await _orders.getOrders();
    final active = all.where(
      (o) =>
          o.courierId == courierId &&
          o.status != OrderStatus.delivered &&
          o.status != OrderStatus.cancelled,
    );
    if (active.isNotEmpty) return active.first.branchId;
    return 'branch_1';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class CourierPayoutException implements Exception {
  const CourierPayoutException(this.messageKey);
  final String messageKey;
}
