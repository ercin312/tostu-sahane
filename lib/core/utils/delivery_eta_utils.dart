import '../../shared/domain/entities/branch.dart';
import '../../shared/domain/entities/order.dart';
import '../services/location_service.dart';

abstract final class DeliveryEtaUtils {
  /// Tahmini toplam teslimat süresi (dakika): hazırlık + yol.
  static int estimateTotalMinutes({
    required Branch branch,
    double? deliveryLat,
    double? deliveryLng,
  }) {
    final prep = branch.prepTimeMinutes;
    final travel = _travelMinutes(
      branchLat: branch.latitude,
      branchLng: branch.longitude,
      deliveryLat: deliveryLat,
      deliveryLng: deliveryLng,
    );
    return prep + travel;
  }

  static int _travelMinutes({
    required double branchLat,
    required double branchLng,
    double? deliveryLat,
    double? deliveryLng,
  }) {
    if (deliveryLat == null || deliveryLng == null) return 12;
    final km = LocationService.distanceKm(
      branchLat,
      branchLng,
      deliveryLat,
      deliveryLng,
    );
    return (km * 3 + 5).round().clamp(5, 45);
  }

  /// Sipariş durumuna göre kalan dakika.
  static int remainingMinutes({
    required Order order,
    required Branch branch,
  }) {
    if (order.status == OrderStatus.delivered) return 0;
    if (order.status == OrderStatus.cancelled) return 0;

    final total = order.estimatedDeliveryMinutes ??
        estimateTotalMinutes(
          branch: branch,
          deliveryLat: order.deliveryLatitude,
          deliveryLng: order.deliveryLongitude,
        );

    const statusProgress = {
      OrderStatus.received: 0.0,
      OrderStatus.preparing: 0.25,
      OrderStatus.waitingCourier: 0.5,
      OrderStatus.onTheWay: 0.75,
      OrderStatus.delivered: 1.0,
      OrderStatus.cancelled: 1.0,
    };

    final progress = statusProgress[order.status] ?? 0.0;
    final remaining = (total * (1 - progress)).round();
    return remaining.clamp(0, total);
  }

  /// Kurye konumundan teslimat adresine kalan dakika.
  static int? minutesFromCourierToDelivery(Order order) {
    final cLat = order.courierLatitude;
    final cLng = order.courierLongitude;
    final dLat = order.deliveryLatitude;
    final dLng = order.deliveryLongitude;
    if (cLat == null || cLng == null || dLat == null || dLng == null) {
      return null;
    }
    final km = LocationService.distanceKm(cLat, cLng, dLat, dLng);
    return (km * 3 + 2).round().clamp(1, 90);
  }
}
