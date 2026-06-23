import '../../../../shared/domain/entities/order.dart';

/// Az siparişte tek şerit; 3+ siparişte sol → orta → sağ timeline.
abstract final class KitchenTimelineLayout {
  /// Tek şerit moduna geçmeden önceki minimum sipariş sayısı.
  static const multiColumnThreshold = 3;

  /// Sol sütunda en fazla kaç sipariş (en yeni üstte).
  static const leftColumnCapacity = 2;

  /// Orta sütunda en fazla kaç sipariş.
  static const middleColumnCapacity = 3;

  static int columnCountForWidth(double width) {
    if (width >= 1280) return 3;
    if (width >= 680) return 2;
    return 1;
  }

  /// [orders] en yeniden eskiye sıralı olmalı (createdAt desc).
  static List<List<Order>> distributeLanes(
    List<Order> orders, {
    required int maxColumns,
  }) {
    if (orders.isEmpty) return const [];

    if (orders.length < multiColumnThreshold || maxColumns <= 1) {
      return [List<Order>.of(orders)];
    }

    final columns = maxColumns.clamp(2, 3);

    if (columns == 2) {
      final left = orders.take(leftColumnCapacity).toList();
      final right = orders.skip(leftColumnCapacity).toList();
      return [
        if (left.isNotEmpty) left,
        if (right.isNotEmpty) right,
      ];
    }

    final left = orders.take(leftColumnCapacity).toList();
    final middle =
        orders.skip(leftColumnCapacity).take(middleColumnCapacity).toList();
    final right =
        orders.skip(leftColumnCapacity + middleColumnCapacity).toList();

    return [
      if (left.isNotEmpty) left,
      if (middle.isNotEmpty) middle,
      if (right.isNotEmpty) right,
    ];
  }
}
