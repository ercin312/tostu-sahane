import 'package:flutter_test/flutter_test.dart';
import 'package:tostu_sahane/core/analytics/admin_reports_analytics.dart';
import 'package:tostu_sahane/shared/domain/entities/branch.dart';
import 'package:tostu_sahane/shared/domain/entities/order.dart';

Order _order({
  required String id,
  required OrderStatus status,
  required DateTime createdAt,
  String branchId = 'branch_1',
  double total = 100,
  PaymentMethod payment = PaymentMethod.cashOnDelivery,
  List<CartItem> items = const [],
}) {
  return Order(
    id: id,
    orderNumber: 1000,
    customerId: 'c1',
    customerName: 'Test',
    branchId: branchId,
    items: items,
    totalAmount: total,
    status: status,
    createdAt: createdAt,
    address: 'Address',
    paymentMethod: payment,
    statusTimestamps: {OrderStatus.received: createdAt},
    rating: status == OrderStatus.delivered ? 5 : null,
    courierId: status == OrderStatus.delivered ? 'u2' : null,
  );
}

void main() {
  group('AdminReportsCalculator', () {
    test('computes KPIs and breakdowns for period', () {
      final now = DateTime.now();
      final orders = [
        _order(
          id: 'o1',
          status: OrderStatus.delivered,
          createdAt: now,
          total: 120,
          items: const [
            CartItem(
              id: 'i1',
              productId: 'p1',
              productNameKey: 'product_kasarli_tost_name',
              unitPrice: 60,
              quantity: 2,
            ),
          ],
        ).copyWith(
          statusTimestamps: {
            OrderStatus.received: now.subtract(const Duration(minutes: 40)),
            OrderStatus.delivered: now,
            OrderStatus.onTheWay: now.subtract(const Duration(minutes: 15)),
          },
        ),
        _order(
          id: 'o2',
          status: OrderStatus.cancelled,
          createdAt: now.subtract(const Duration(hours: 1)),
          total: 80,
        ),
        _order(
          id: 'o3',
          status: OrderStatus.preparing,
          createdAt: now.subtract(const Duration(minutes: 10)),
          total: 90,
          payment: PaymentMethod.onlineCard,
        ),
      ];

      final snapshot = AdminReportsCalculator.compute(
        orders: orders,
        branches: const [
          Branch(
            id: 'branch_1',
            name: 'Merkez',
            address: 'Adres',
            latitude: 41.0,
            longitude: 29.0,
            distanceKm: 1,
          ),
        ],
        period: AdminReportPeriod.today,
      );

      expect(snapshot.orderCount, 3);
      expect(snapshot.deliveredCount, 1);
      expect(snapshot.cancelledCount, 1);
      expect(snapshot.activeCount, 1);
      expect(snapshot.totalRevenue, 290);
      expect(snapshot.cancellationRate, closeTo(33.3, 0.1));
      expect(snapshot.topProducts, isNotEmpty);
      expect(snapshot.topProducts.first.quantity, 2);
      expect(snapshot.branchRankings.first.branchName, 'Merkez');
      expect(snapshot.paymentBreakdown.length, 2);
    });

    test('filters orders by custom date range', () {
      final start = DateTime(2026, 3, 10);
      final end = DateTime(2026, 3, 12);
      final orders = [
        _order(
          id: 'in-range',
          status: OrderStatus.delivered,
          createdAt: DateTime(2026, 3, 11, 14),
          total: 150,
        ),
        _order(
          id: 'before-range',
          status: OrderStatus.delivered,
          createdAt: DateTime(2026, 3, 9, 14),
          total: 50,
        ),
        _order(
          id: 'after-range',
          status: OrderStatus.delivered,
          createdAt: DateTime(2026, 3, 13, 10),
          total: 80,
        ),
      ];

      final snapshot = AdminReportsCalculator.compute(
        orders: orders,
        branches: const [
          Branch(
            id: 'branch_1',
            name: 'Merkez',
            address: 'Adres',
            latitude: 41.0,
            longitude: 29.0,
            distanceKm: 1,
          ),
        ],
        period: AdminReportPeriod.custom,
        customRange: AdminReportDateRange(start: start, end: end),
        now: DateTime(2026, 3, 18),
      );

      expect(snapshot.orderCount, 1);
      expect(snapshot.totalRevenue, 150);
      expect(snapshot.rangeStart, DateTime(2026, 3, 10));
      expect(snapshot.rangeEnd, DateTime(2026, 3, 12));
    });
  });
}
