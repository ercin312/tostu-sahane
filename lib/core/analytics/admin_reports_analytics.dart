import '../../shared/domain/entities/branch.dart';
import '../../shared/domain/entities/order.dart';
import 'ops_analytics.dart';

enum AdminReportPeriod { today, last7Days, last30Days, custom }

/// Takvim günü (saat 00:00) — bitiş günü dahil.
class AdminReportDateRange {
  const AdminReportDateRange({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;

  static DateTime dayStart(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static AdminReportDateRange last7Days([DateTime? now]) {
    final today = dayStart(now ?? DateTime.now());
    return AdminReportDateRange(
      start: today.subtract(const Duration(days: 6)),
      end: today,
    );
  }

  AdminReportDateRange normalized() {
    final s = dayStart(start);
    var e = dayStart(end);
    if (e.isBefore(s)) e = s;
    return AdminReportDateRange(start: s, end: e);
  }

  int get dayCount => end.difference(start).inDays + 1;
}

class AdminReportResolvedRange {
  const AdminReportResolvedRange({
    required this.startInclusive,
    required this.endInclusive,
    required this.endExclusive,
  });

  final DateTime startInclusive;
  final DateTime endInclusive;
  final DateTime endExclusive;

  int get dayCount => endInclusive.difference(startInclusive).inDays + 1;
}

class DailyRevenuePoint {
  const DailyRevenuePoint({
    required this.date,
    required this.revenue,
    required this.orderCount,
  });

  final DateTime date;
  final double revenue;
  final int orderCount;
}

class StatusSlice {
  const StatusSlice({
    required this.status,
    required this.count,
    required this.share,
  });

  final OrderStatus status;
  final int count;
  final double share;
}

class PaymentSlice {
  const PaymentSlice({
    required this.method,
    required this.count,
    required this.revenue,
    required this.share,
  });

  final PaymentMethod method;
  final int count;
  final double revenue;
  final double share;
}

class BranchRanking {
  const BranchRanking({
    required this.branchId,
    required this.branchName,
    required this.revenue,
    required this.orderCount,
    required this.deliveredCount,
    required this.cancelledCount,
    required this.avgDeliveryMinutes,
  });

  final String branchId;
  final String branchName;
  final double revenue;
  final int orderCount;
  final int deliveredCount;
  final int cancelledCount;
  final int? avgDeliveryMinutes;

  double get cancelRate =>
      orderCount == 0 ? 0 : (cancelledCount / orderCount) * 100;
}

class ProductRanking {
  const ProductRanking({
    required this.productNameKey,
    required this.quantity,
    required this.revenue,
  });

  final String productNameKey;
  final int quantity;
  final double revenue;
}

class HourlyBucket {
  const HourlyBucket({
    required this.hour,
    required this.orderCount,
  });

  final int hour;
  final int orderCount;
}

class AdminReportSnapshot {
  const AdminReportSnapshot({
    required this.period,
    required this.rangeStart,
    required this.rangeEnd,
    required this.totalRevenue,
    required this.orderCount,
    required this.deliveredCount,
    required this.cancelledCount,
    required this.activeCount,
    required this.avgOrderValue,
    required this.cancellationRate,
    required this.avgDeliveryMinutes,
    required this.avgFulfillmentMinutes,
    required this.avgRating,
    required this.ratedOrderCount,
    required this.revenueTrend,
    required this.statusBreakdown,
    required this.paymentBreakdown,
    required this.branchRankings,
    required this.topProducts,
    required this.peakHours,
    required this.opsAnalytics,
  });

  final AdminReportPeriod period;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final double totalRevenue;
  final int orderCount;
  final int deliveredCount;
  final int cancelledCount;
  final int activeCount;
  final double avgOrderValue;
  final double cancellationRate;
  final int? avgDeliveryMinutes;
  final int? avgFulfillmentMinutes;
  final double? avgRating;
  final int ratedOrderCount;
  final List<DailyRevenuePoint> revenueTrend;
  final List<StatusSlice> statusBreakdown;
  final List<PaymentSlice> paymentBreakdown;
  final List<BranchRanking> branchRankings;
  final List<ProductRanking> topProducts;
  final List<HourlyBucket> peakHours;
  final OpsAnalytics opsAnalytics;
}

abstract final class AdminReportsCalculator {
  static AdminReportSnapshot compute({
    required List<Order> orders,
    required List<Branch> branches,
    required AdminReportPeriod period,
    AdminReportDateRange? customRange,
    String? branchIdFilter,
    DateTime? now,
  }) {
    final range = resolveRange(
      period: period,
      customRange: customRange,
      now: now,
    );
    final filtered = orders.where((o) {
      if (branchIdFilter != null && o.branchId != branchIdFilter) return false;
      return !o.createdAt.isBefore(range.startInclusive) &&
          o.createdAt.isBefore(range.endExclusive);
    }).toList();

    final delivered =
        filtered.where((o) => o.status == OrderStatus.delivered).toList();
    final cancelled =
        filtered.where((o) => o.status == OrderStatus.cancelled).toList();
    final active = filtered.where((o) => o.isActive).length;

    final totalRevenue =
        filtered.fold<double>(0, (sum, o) => sum + o.totalAmount);
    final orderCount = filtered.length;
    final avgOrderValue = orderCount == 0 ? 0 : totalRevenue / orderCount;
    final cancellationRate =
        orderCount == 0 ? 0 : (cancelled.length / orderCount) * 100;

    final deliveryDurations = delivered
        .map((o) => o.deliveryDurationMinutes)
        .whereType<int>()
        .toList();
    final fulfillmentDurations = delivered
        .map((o) => o.totalFulfillmentMinutes)
        .whereType<int>()
        .toList();

    final ratings = delivered
        .map((o) => o.rating)
        .whereType<int>()
        .toList();

    final branchNameById = {
      for (final branch in branches) branch.id: branch.name,
    };

    return AdminReportSnapshot(
      period: period,
      rangeStart: range.startInclusive,
      rangeEnd: range.endInclusive,
      totalRevenue: totalRevenue,
      orderCount: orderCount,
      deliveredCount: delivered.length,
      cancelledCount: cancelled.length,
      activeCount: active,
      avgOrderValue: avgOrderValue.toDouble(),
      cancellationRate: cancellationRate.toDouble(),
      avgDeliveryMinutes: _averageInt(deliveryDurations),
      avgFulfillmentMinutes: _averageInt(fulfillmentDurations),
      avgRating: ratings.isEmpty
          ? null
          : ratings.fold<int>(0, (s, r) => s + r) / ratings.length,
      ratedOrderCount: ratings.length,
      revenueTrend: _revenueTrend(filtered, range, period),
      statusBreakdown: _statusBreakdown(filtered),
      paymentBreakdown: _paymentBreakdown(filtered),
      branchRankings:
          _branchRankings(filtered, branchNameById, delivered),
      topProducts: _topProducts(filtered),
      peakHours: _peakHours(filtered),
      opsAnalytics: OpsAnalyticsCalculator.compute(
        orders: orders,
        branchId: branchIdFilter,
        since: range.startInclusive,
      ),
    );
  }

  static AdminReportResolvedRange resolveRange({
    required AdminReportPeriod period,
    AdminReportDateRange? customRange,
    DateTime? now,
  }) {
    final today = AdminReportDateRange.dayStart(now ?? DateTime.now());
    return switch (period) {
      AdminReportPeriod.today => AdminReportResolvedRange(
          startInclusive: today,
          endInclusive: today,
          endExclusive: today.add(const Duration(days: 1)),
        ),
      AdminReportPeriod.last7Days => AdminReportResolvedRange(
          startInclusive: today.subtract(const Duration(days: 6)),
          endInclusive: today,
          endExclusive: today.add(const Duration(days: 1)),
        ),
      AdminReportPeriod.last30Days => AdminReportResolvedRange(
          startInclusive: today.subtract(const Duration(days: 29)),
          endInclusive: today,
          endExclusive: today.add(const Duration(days: 1)),
        ),
      AdminReportPeriod.custom => () {
          final normalized =
              (customRange ?? AdminReportDateRange.last7Days(now)).normalized();
          return AdminReportResolvedRange(
            startInclusive: normalized.start,
            endInclusive: normalized.end,
            endExclusive:
                normalized.end.add(const Duration(days: 1)),
          );
        }(),
    };
  }

  static int? _averageInt(List<int> values) {
    if (values.isEmpty) return null;
    final sum = values.fold<int>(0, (s, v) => s + v);
    return (sum / values.length).round();
  }

  static List<DailyRevenuePoint> _revenueTrend(
    List<Order> orders,
    AdminReportResolvedRange range,
    AdminReportPeriod period,
  ) {
    final dayCount = range.dayCount;
    final chartDayCount = switch (period) {
      AdminReportPeriod.today => 1,
      AdminReportPeriod.last7Days => 7,
      AdminReportPeriod.last30Days => 7,
      AdminReportPeriod.custom => dayCount <= 31 ? dayCount : (dayCount / 7).ceil(),
    };

    if (period == AdminReportPeriod.custom && dayCount > 31) {
      return _weeklyRevenueTrend(orders, range, chartDayCount);
    }

    final points = <DailyRevenuePoint>[];
    for (var i = 0; i < chartDayCount; i++) {
      final day = range.startInclusive.add(Duration(days: i));
      final nextDay = day.add(const Duration(days: 1));
      final dayOrders = orders.where(
        (o) => !o.createdAt.isBefore(day) && o.createdAt.isBefore(nextDay),
      );
      points.add(
        DailyRevenuePoint(
          date: day,
          revenue: dayOrders.fold<double>(0, (s, o) => s + o.totalAmount),
          orderCount: dayOrders.length,
        ),
      );
    }
    return points;
  }

  static List<DailyRevenuePoint> _weeklyRevenueTrend(
    List<Order> orders,
    AdminReportResolvedRange range,
    int weekCount,
  ) {
    final points = <DailyRevenuePoint>[];
    for (var i = 0; i < weekCount; i++) {
      final weekStart = range.startInclusive.add(Duration(days: i * 7));
      final weekEnd = weekStart.add(const Duration(days: 7));
      final cappedEnd = weekEnd.isAfter(range.endExclusive)
          ? range.endExclusive
          : weekEnd;
      final weekOrders = orders.where(
        (o) =>
            !o.createdAt.isBefore(weekStart) &&
            o.createdAt.isBefore(cappedEnd),
      );
      points.add(
        DailyRevenuePoint(
          date: weekStart,
          revenue: weekOrders.fold<double>(0, (s, o) => s + o.totalAmount),
          orderCount: weekOrders.length,
        ),
      );
    }
    return points;
  }

  static List<StatusSlice> _statusBreakdown(List<Order> orders) {
    if (orders.isEmpty) return const [];
    final counts = <OrderStatus, int>{};
    for (final order in orders) {
      counts[order.status] = (counts[order.status] ?? 0) + 1;
    }
    return counts.entries
        .map(
          (e) => StatusSlice(
            status: e.key,
            count: e.value,
            share: e.value / orders.length,
          ),
        )
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
  }

  static List<PaymentSlice> _paymentBreakdown(List<Order> orders) {
    if (orders.isEmpty) return const [];
    final counts = <PaymentMethod, ({int count, double revenue})>{};
    for (final order in orders) {
      final current = counts[order.paymentMethod];
      counts[order.paymentMethod] = (
        count: (current?.count ?? 0) + 1,
        revenue: (current?.revenue ?? 0) + order.totalAmount,
      );
    }
    return counts.entries
        .map(
          (e) => PaymentSlice(
            method: e.key,
            count: e.value.count,
            revenue: e.value.revenue,
            share: e.value.count / orders.length,
          ),
        )
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
  }

  static List<BranchRanking> _branchRankings(
    List<Order> orders,
    Map<String, String> branchNames,
    List<Order> delivered,
  ) {
    final stats = <String, ({
      double revenue,
      int orders,
      int delivered,
      int cancelled,
      List<int> deliveryMinutes,
    })>{};

    for (final order in orders) {
      final current = stats[order.branchId];
      final deliveryMin = order.deliveryDurationMinutes;
      stats[order.branchId] = (
        revenue: (current?.revenue ?? 0) + order.totalAmount,
        orders: (current?.orders ?? 0) + 1,
        delivered: (current?.delivered ?? 0) +
            (order.status == OrderStatus.delivered ? 1 : 0),
        cancelled: (current?.cancelled ?? 0) +
            (order.status == OrderStatus.cancelled ? 1 : 0),
        deliveryMinutes: [
          ...?current?.deliveryMinutes,
          if (deliveryMin != null) deliveryMin,
        ],
      );
    }

    return stats.entries
        .map(
          (e) => BranchRanking(
            branchId: e.key,
            branchName: branchNames[e.key] ?? e.key,
            revenue: e.value.revenue,
            orderCount: e.value.orders,
            deliveredCount: e.value.delivered,
            cancelledCount: e.value.cancelled,
            avgDeliveryMinutes: _averageInt(e.value.deliveryMinutes),
          ),
        )
        .toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
  }

  static List<ProductRanking> _topProducts(List<Order> orders) {
    final stats = <String, ({int qty, double revenue})>{};
    for (final order in orders) {
      for (final item in order.items) {
        final current = stats[item.productNameKey];
        stats[item.productNameKey] = (
          qty: (current?.qty ?? 0) + item.quantity,
          revenue: (current?.revenue ?? 0) + item.totalPrice,
        );
      }
    }
    return stats.entries
        .map(
          (e) => ProductRanking(
            productNameKey: e.key,
            quantity: e.value.qty,
            revenue: e.value.revenue,
          ),
        )
        .toList()
      ..sort((a, b) => b.quantity.compareTo(a.quantity));
  }

  static List<HourlyBucket> _peakHours(List<Order> orders) {
    final counts = List<int>.filled(24, 0);
    for (final order in orders) {
      counts[order.createdAt.hour] += 1;
    }
    return List.generate(
      24,
      (hour) => HourlyBucket(hour: hour, orderCount: counts[hour]),
    );
  }
}
