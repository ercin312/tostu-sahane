import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tostu_sahane/features/admin/branches/presentation/widgets/branch_delivery_zone_map.dart';
import 'package:tostu_sahane/shared/domain/entities/branch.dart';
import 'package:tostu_sahane/shared/domain/entities/geo_point.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tapping the map adds a delivery corner', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final points = <List<GeoPoint>>[];
    const branch = Branch(
      id: 'b1',
      name: 'Merkez',
      address: 'Adres',
      latitude: 36.54,
      longitude: 36.20,
    );

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('tr', 'TR')],
        path: 'unused',
        fallbackLocale: const Locale('tr', 'TR'),
        startLocale: const Locale('tr', 'TR'),
        assetLoader: const _TestAssetLoader(),
        child: MaterialApp(
          home: Scaffold(
            body: BranchDeliveryZoneMap(
              branch: branch,
              mode: DeliveryZoneMode.polygon,
              radiusKm: 3,
              polygon: const [],
              onModeChanged: (_) {},
              onRadiusChanged: (_) {},
              onPolygonChanged: points.add,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byType(FlutterMap));
    await tester.pump();

    expect(points, isNotEmpty);
    expect(points.last, hasLength(1));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('tapping inside an existing area still adds a corner', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final points = <List<GeoPoint>>[];
    const branch = Branch(
      id: 'b1',
      name: 'Merkez',
      address: 'Adres',
      latitude: 36.54,
      longitude: 36.20,
    );

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('tr', 'TR')],
        path: 'unused',
        fallbackLocale: const Locale('tr', 'TR'),
        startLocale: const Locale('tr', 'TR'),
        assetLoader: const _TestAssetLoader(),
        child: MaterialApp(
          home: Scaffold(
            body: BranchDeliveryZoneMap(
              branch: branch,
              mode: DeliveryZoneMode.polygon,
              radiusKm: 3,
              polygon: defaultPolygonAroundBranch(branch),
              onModeChanged: (_) {},
              onRadiusChanged: (_) {},
              onPolygonChanged: points.add,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byType(FlutterMap));
    await tester.pump();

    expect(points, isNotEmpty);
    expect(points.last.length, greaterThan(4));
    await tester.pump(const Duration(milliseconds: 300));
  });
}

class _TestAssetLoader extends AssetLoader {
  const _TestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return const {
      'admin_zone_mode_radius': 'Mesafe',
      'admin_zone_mode_polygon': 'Haritada ciz',
      'admin_zone_polygon_hint': 'Dokun',
      'admin_zone_undo_point': 'Geri',
      'common_remove': 'Sil',
    };
  }
}
