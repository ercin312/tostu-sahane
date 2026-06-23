import '../../shared/domain/entities/branch.dart';
import '../../shared/domain/entities/geo_point.dart';
import '../services/location_service.dart';

/// Teslimat bölgesi kontrolü (mesafe veya poligon).
abstract final class DeliveryZoneUtils {
  static const defaultRadiusKm = 3.0;

  /// Adres koordinatı şubenin teslimat bölgesinde mi?
  static bool isDeliverable(Branch branch, double lat, double lng) {
    return switch (branch.deliveryZoneMode) {
      DeliveryZoneMode.radius => isWithinRadius(
          branchLat: branch.latitude,
          branchLng: branch.longitude,
          pointLat: lat,
          pointLng: lng,
          radiusKm: branch.deliveryRadiusKm,
        ),
      DeliveryZoneMode.polygon => isPointInPolygon(
          lat: lat,
          lng: lng,
          polygon: branch.deliveryPolygon,
        ),
    };
  }

  /// Kuş uçuşu mesafe ≤ yarıçap (Yemek Sepeti yaklaşımı).
  static bool isWithinRadius({
    required double branchLat,
    required double branchLng,
    required double pointLat,
    required double pointLng,
    required double radiusKm,
  }) {
    if (radiusKm <= 0) return false;
    final distance = LocationService.distanceKm(
      branchLat,
      branchLng,
      pointLat,
      pointLng,
    );
    return distance <= radiusKm;
  }

  /// Ray-casting ile nokta poligon içinde mi?
  static bool isPointInPolygon({
    required double lat,
    required double lng,
    required List<GeoPoint> polygon,
  }) {
    if (polygon.length < 3) return false;

    var inside = false;
    var j = polygon.length - 1;
    for (var i = 0; i < polygon.length; i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;

      final intersect = ((yi > lat) != (yj > lat)) &&
          (lng < (xj - xi) * (lat - yi) / (yj - yi + 1e-12) + xi);
      if (intersect) inside = !inside;
      j = i;
    }
    return inside;
  }

  /// Konuma hizmet veren en yakın şubeyi bulur.
  static Branch? nearestDeliveringBranch(
    List<Branch> branches,
    double lat,
    double lng,
  ) {
    Branch? nearest;
    var minDistance = double.infinity;

    for (final branch in branches) {
      if (!isDeliverable(branch, lat, lng)) continue;
      final distance = LocationService.distanceKm(
        branch.latitude,
        branch.longitude,
        lat,
        lng,
      );
      if (distance < minDistance) {
        minDistance = distance;
        nearest = branch.copyWith(
          distanceKm: double.parse(distance.toStringAsFixed(1)),
        );
      }
    }
    return nearest;
  }
}
