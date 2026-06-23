import '../../shared/domain/entities/order.dart';
import '../../shared/domain/entities/user.dart';

class StaffOrderStat {
  const StaffOrderStat({
    required this.userId,
    required this.userName,
    required this.orderCount,
  });

  final String userId;
  final String userName;
  final int orderCount;
}

class CourierDeliveryStat {
  const CourierDeliveryStat({
    required this.courierId,
    required this.courierName,
    required this.todayDeliveries,
    required this.avgDeliveryMinutes,
    required this.minDeliveryMinutes,
    required this.maxDeliveryMinutes,
  });

  final String courierId;
  final String courierName;
  final int todayDeliveries;
  final int avgDeliveryMinutes;
  final int minDeliveryMinutes;
  final int maxDeliveryMinutes;
}

class OpsAnalytics {
  const OpsAnalytics({
    required this.staffStats,
    required this.courierStats,
  });

  final List<StaffOrderStat> staffStats;
  final List<CourierDeliveryStat> courierStats;
}

abstract final class OpsAnalyticsCalculator {
  static OpsAnalytics compute({
    required List<Order> orders,
    String? branchId,
    DateTime? since,
  }) {
    final filtered = orders.where((o) {
      if (branchId != null && o.branchId != branchId) return false;
      if (since != null && o.createdAt.isBefore(since)) return false;
      return true;
    }).toList();

    final staffCounts = <String, ({String name, int count})>{};
    for (final order in filtered) {
      for (final status in [
        OrderStatus.preparing,
        OrderStatus.waitingCourier,
        OrderStatus.cancelled,
      ]) {
        final actorId = order.statusActorIds[status];
        final actorName = order.statusActorNames[status];
        if (actorId == null || actorName == null) continue;
        final current = staffCounts[actorId];
        staffCounts[actorId] = (
          name: actorName,
          count: (current?.count ?? 0) + 1,
        );
      }
    }

    final staffStats = staffCounts.entries
        .map(
          (e) => StaffOrderStat(
            userId: e.key,
            userName: e.value.name,
            orderCount: e.value.count,
          ),
        )
        .toList()
      ..sort((a, b) => b.orderCount.compareTo(a.orderCount));

    final today = DateTime.now();
    final courierMap = <String, List<int>>{};
    final courierNames = <String, String>{};

    for (final order in filtered) {
      if (order.status != OrderStatus.delivered || order.courierId == null) {
        continue;
      }
      final deliveredAt = order.atStatus(OrderStatus.delivered);
      if (deliveredAt == null) continue;
      if (deliveredAt.year != today.year ||
          deliveredAt.month != today.month ||
          deliveredAt.day != today.day) {
        continue;
      }
      final minutes = order.deliveryDurationMinutes;
      if (minutes == null) continue;
      courierMap.putIfAbsent(order.courierId!, () => []).add(minutes);
      courierNames[order.courierId!] =
          order.courierName ?? order.courierId!;
    }

    final courierStats = courierMap.entries.map((e) {
      final durations = e.value;
      durations.sort();
      final sum = durations.fold<int>(0, (s, v) => s + v);
      return CourierDeliveryStat(
        courierId: e.key,
        courierName: courierNames[e.key] ?? e.key,
        todayDeliveries: durations.length,
        avgDeliveryMinutes: (sum / durations.length).round(),
        minDeliveryMinutes: durations.first,
        maxDeliveryMinutes: durations.last,
      );
    }).toList()
      ..sort((a, b) => b.todayDeliveries.compareTo(a.todayDeliveries));

    return OpsAnalytics(
      staffStats: staffStats,
      courierStats: courierStats,
    );
  }
}
