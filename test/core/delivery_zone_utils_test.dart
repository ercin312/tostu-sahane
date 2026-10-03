import 'package:flutter_test/flutter_test.dart';

import 'package:tostu_sahane/core/utils/delivery_zone_utils.dart';
import 'package:tostu_sahane/shared/domain/entities/branch.dart';
import 'package:tostu_sahane/shared/domain/entities/geo_point.dart';

void main() {
  const branch = Branch(
    id: 'b1',
    name: 'Merkez',
    address: 'Adres',
    latitude: 36.54,
    longitude: 36.20,
    deliveryRadiusKm: 3,
  );

  test('radius zone includes the branch and excludes a far point', () {
    expect(DeliveryZoneUtils.isDeliverable(branch, 36.54, 36.20), isTrue);
    expect(DeliveryZoneUtils.isDeliverable(branch, 37.20, 36.20), isFalse);
  });

  test('polygon zone follows the corners saved from the map', () {
    final zoned = branch.copyWith(
      deliveryZoneMode: DeliveryZoneMode.polygon,
      deliveryPolygon: const [
        GeoPoint(latitude: 36.55, longitude: 36.19),
        GeoPoint(latitude: 36.55, longitude: 36.21),
        GeoPoint(latitude: 36.53, longitude: 36.21),
        GeoPoint(latitude: 36.53, longitude: 36.19),
      ],
    );

    expect(DeliveryZoneUtils.isDeliverable(zoned, 36.54, 36.20), isTrue);
    expect(DeliveryZoneUtils.isDeliverable(zoned, 36.60, 36.20), isFalse);
    expect(
      DeliveryZoneUtils.isDeliverable(
        zoned.copyWith(deliveryPolygon: const [
          GeoPoint(latitude: 36.55, longitude: 36.19),
          GeoPoint(latitude: 36.55, longitude: 36.21),
        ]),
        36.54,
        36.20,
      ),
      isFalse,
    );
  });
}
