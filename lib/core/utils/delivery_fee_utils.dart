import '../../shared/domain/entities/branch.dart';
import '../services/location_service.dart';

abstract final class DeliveryFeeUtils {
  static double calculate({
    required Branch branch,
    required double subtotal,
    double? deliveryLat,
    double? deliveryLng,
    double? freeDeliveryMinOrder,
  }) {
    final threshold = freeDeliveryMinOrder ?? branch.freeDeliveryMinOrder;
    if (subtotal >= threshold) return 0;

    var fee = branch.baseDeliveryFee;

    if (deliveryLat != null && deliveryLng != null) {
      final km = LocationService.distanceKm(
        branch.latitude,
        branch.longitude,
        deliveryLat,
        deliveryLng,
      );
      fee += km * branch.deliveryFeePerKm;
    }

    return double.parse(fee.toStringAsFixed(2));
  }

  static String freeDeliveryHint(double freeDeliveryMinOrder) =>
      '${freeDeliveryMinOrder.toStringAsFixed(0)} TL';
}
