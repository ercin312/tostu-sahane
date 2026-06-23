import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:tostu_sahane/core/widgets/osm_tile_map_view.dart';

void main() {
  group('fitOsmCamera', () {
    test('returns default Istanbul camera for empty points', () {
      final camera = fitOsmCamera([]);

      expect(camera.center.latitude, closeTo(41.0082, 0.0001));
      expect(camera.center.longitude, closeTo(28.9784, 0.0001));
      expect(camera.zoom, 12);
    });

    test('includes courier point in bounds calculation', () {
      final branch = LatLng(41.0, 29.0);
      final delivery = LatLng(41.02, 29.02);
      final courier = LatLng(41.01, 29.01);

      final withoutCourier = fitOsmCamera([branch, delivery]);
      final withCourier = fitOsmCamera([branch, delivery, courier]);

      expect(withCourier.center.latitude, closeTo(41.01, 0.001));
      expect(withCourier.center.longitude, closeTo(29.01, 0.001));
      expect(withCourier.zoom, withoutCourier.zoom);
    });
  });
}
