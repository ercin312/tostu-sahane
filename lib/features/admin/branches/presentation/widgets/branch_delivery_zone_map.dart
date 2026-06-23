import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as latlong;

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../shared/domain/entities/branch.dart';
import '../../../../../shared/domain/entities/geo_point.dart';

/// Admin: şube teslimat bölgesi harita editörü.
/// Mod 1 — Mesafe (Yemek Sepeti tarzı km yarıçapı)
/// Mod 2 — Haritada poligon çizimi
class BranchDeliveryZoneMap extends StatefulWidget {
  const BranchDeliveryZoneMap({
    super.key,
    required this.branch,
    required this.mode,
    required this.radiusKm,
    required this.polygon,
    required this.onModeChanged,
    required this.onRadiusChanged,
    required this.onPolygonChanged,
  });

  final Branch branch;
  final DeliveryZoneMode mode;
  final double radiusKm;
  final List<GeoPoint> polygon;
  final ValueChanged<DeliveryZoneMode> onModeChanged;
  final ValueChanged<double> onRadiusChanged;
  final ValueChanged<List<GeoPoint>> onPolygonChanged;

  /// Teslimat bölgesi editörü her platformda OSM kullanır (Windows ile aynı davranış).
  static bool get usesGoogleMap => false;

  @override
  State<BranchDeliveryZoneMap> createState() => _BranchDeliveryZoneMapState();
}

class _BranchDeliveryZoneMapState extends State<BranchDeliveryZoneMap> {
  gmaps.GoogleMapController? _mapController;

  gmaps.LatLng get _branchCenter =>
      gmaps.LatLng(widget.branch.latitude, widget.branch.longitude);

  List<gmaps.LatLng> get _polygonLatLngs =>
      widget.polygon
          .map((p) => gmaps.LatLng(p.latitude, p.longitude))
          .toList();

  void _onMapTap(gmaps.LatLng position) {
    if (widget.mode != DeliveryZoneMode.polygon) return;
    widget.onPolygonChanged([
      ...widget.polygon,
      GeoPoint(
        latitude: position.latitude,
        longitude: position.longitude,
      ),
    ]);
  }

  void _undoPoint() {
    if (widget.polygon.isEmpty) return;
    widget.onPolygonChanged(
      widget.polygon.sublist(0, widget.polygon.length - 1),
    );
  }

  void _clearPolygon() => widget.onPolygonChanged([]);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: SegmentedButton<DeliveryZoneMode>(
            segments: [
              ButtonSegment(
                value: DeliveryZoneMode.radius,
                icon: const Icon(Icons.radio_button_checked, size: 18),
                label: Text(LocaleKeys.adminZoneModeRadius.tr()),
              ),
              ButtonSegment(
                value: DeliveryZoneMode.polygon,
                icon: const Icon(Icons.pentagon_outlined, size: 18),
                label: Text(LocaleKeys.adminZoneModePolygon.tr()),
              ),
            ],
            selected: {widget.mode},
            onSelectionChanged: (s) => widget.onModeChanged(s.first),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (widget.mode == DeliveryZoneMode.radius) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Slider(
                    value: widget.radiusKm.clamp(0.5, 15.0),
                    min: 0.5,
                    max: 15,
                    divisions: 29,
                    label: LocaleKeys.adminZoneRadiusValue.tr(
                      namedArgs: {
                        'km': widget.radiusKm.toStringAsFixed(1),
                      },
                    ),
                    activeColor: AppColors.primary,
                    onChanged: widget.onRadiusChanged,
                  ),
                ),
                Text(
                  LocaleKeys.adminZoneRadiusValue.tr(
                    namedArgs: {'km': widget.radiusKm.toStringAsFixed(1)},
                  ),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              LocaleKeys.adminZoneRadiusHint.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    LocaleKeys.adminZonePolygonHint.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
                TextButton.icon(
                  onPressed:
                      widget.polygon.isEmpty ? null : _undoPoint,
                  icon: const Icon(Icons.undo, size: 18),
                  label: Text(LocaleKeys.adminZoneUndoPoint.tr()),
                ),
                TextButton.icon(
                  onPressed:
                      widget.polygon.isEmpty ? null : _clearPolygon,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: Text(LocaleKeys.commonRemove.tr()),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BranchDeliveryZoneMap.usesGoogleMap
                  ? _GoogleZoneMap(
                      branchCenter: _branchCenter,
                      mode: widget.mode,
                      radiusKm: widget.radiusKm,
                      polygon: _polygonLatLngs,
                      onTap: _onMapTap,
                      onMapCreated: (c) => _mapController = c,
                    )
                  : _OsmZoneMap(
                      branch: widget.branch,
                      mode: widget.mode,
                      radiusKm: widget.radiusKm,
                      polygon: widget.polygon,
                      onTap: (lat, lng) =>
                          _onMapTap(gmaps.LatLng(lat, lng)),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GoogleZoneMap extends StatelessWidget {
  const _GoogleZoneMap({
    required this.branchCenter,
    required this.mode,
    required this.radiusKm,
    required this.polygon,
    required this.onTap,
    required this.onMapCreated,
  });

  final gmaps.LatLng branchCenter;
  final DeliveryZoneMode mode;
  final double radiusKm;
  final List<gmaps.LatLng> polygon;
  final ValueChanged<gmaps.LatLng> onTap;
  final ValueChanged<gmaps.GoogleMapController> onMapCreated;

  @override
  Widget build(BuildContext context) {
    final circles = mode == DeliveryZoneMode.radius
        ? {
            gmaps.Circle(
              circleId: const gmaps.CircleId('delivery_zone'),
              center: branchCenter,
              radius: radiusKm * 1000,
              fillColor: AppColors.primary.withValues(alpha: 0.15),
              strokeColor: AppColors.primary,
              strokeWidth: 2,
            ),
          }
        : <gmaps.Circle>{};

    final polygons = mode == DeliveryZoneMode.polygon && polygon.length >= 3
        ? {
            gmaps.Polygon(
              polygonId: const gmaps.PolygonId('delivery_zone'),
              points: polygon,
              fillColor: AppColors.primary.withValues(alpha: 0.15),
              strokeColor: AppColors.primary,
              strokeWidth: 2,
            ),
          }
        : <gmaps.Polygon>{};

    final polylines = mode == DeliveryZoneMode.polygon && polygon.isNotEmpty
        ? {
            gmaps.Polyline(
              polylineId: const gmaps.PolylineId('drawing'),
              points: polygon.length >= 3 ? [...polygon, polygon.first] : polygon,
              color: AppColors.primary,
              width: 2,
            ),
          }
        : <gmaps.Polyline>{};

    final markers = {
      gmaps.Marker(
        markerId: const gmaps.MarkerId('branch'),
        position: branchCenter,
        icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
          gmaps.BitmapDescriptor.hueRose,
        ),
      ),
      ...polygon.asMap().entries.map(
            (e) => gmaps.Marker(
              markerId: gmaps.MarkerId('pt_${e.key}'),
              position: e.value,
              icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
                gmaps.BitmapDescriptor.hueOrange,
              ),
            ),
          ),
    };

    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(target: branchCenter, zoom: 13),
      onMapCreated: onMapCreated,
      onTap: mode == DeliveryZoneMode.polygon ? onTap : null,
      markers: markers,
      circles: circles,
      polygons: polygons,
      polylines: polylines,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
    );
  }
}

/// OpenStreetMap — Windows/masaüstü ve Google Maps olmayan platformlar.
class _OsmZoneMap extends StatefulWidget {
  const _OsmZoneMap({
    required this.branch,
    required this.mode,
    required this.radiusKm,
    required this.polygon,
    required this.onTap,
  });

  final Branch branch;
  final DeliveryZoneMode mode;
  final double radiusKm;
  final List<GeoPoint> polygon;
  final void Function(double lat, double lng) onTap;

  @override
  State<_OsmZoneMap> createState() => _OsmZoneMapState();
}

class _OsmZoneMapState extends State<_OsmZoneMap> {
  final _mapController = MapController();

  latlong.LatLng get _center =>
      latlong.LatLng(widget.branch.latitude, widget.branch.longitude);

  List<latlong.LatLng> get _polygonPoints => widget.polygon
      .map((p) => latlong.LatLng(p.latitude, p.longitude))
      .toList();

  List<latlong.LatLng> _circleRing(latlong.LatLng center, double radiusKm) {
    const steps = 64;
    return List.generate(steps, (index) {
      final angle = 2 * math.pi * index / steps;
      return latlong.LatLng(
        center.latitude + kmToLatDelta(radiusKm) * math.cos(angle),
        center.longitude +
            kmToLngDelta(radiusKm, center.latitude) * math.sin(angle),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final polygonPoints = _polygonPoints;
    final zonePolygons = <Polygon>[];

    if (widget.mode == DeliveryZoneMode.radius) {
      zonePolygons.add(
        Polygon(
          points: _circleRing(_center, widget.radiusKm),
          color: AppColors.primary.withValues(alpha: 0.15),
          borderColor: AppColors.primary,
          borderStrokeWidth: 2,
        ),
      );
    } else if (polygonPoints.length >= 3) {
      zonePolygons.add(
        Polygon(
          points: polygonPoints,
          color: AppColors.primary.withValues(alpha: 0.15),
          borderColor: AppColors.primary,
          borderStrokeWidth: 2,
        ),
      );
    }

    final polylines = <Polyline>[];
    if (widget.mode == DeliveryZoneMode.polygon && polygonPoints.isNotEmpty) {
      polylines.add(
        Polyline(
          points: polygonPoints.length >= 3
              ? [...polygonPoints, polygonPoints.first]
              : polygonPoints,
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      );
    }

    final markers = <Marker>[
      Marker(
        point: _center,
        width: 36,
        height: 36,
        child: const Icon(
          Icons.store,
          color: AppColors.primary,
          size: 30,
        ),
      ),
      ...polygonPoints.asMap().entries.map(
            (entry) => Marker(
              point: entry.value,
              width: 20,
              height: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ),
    ];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: 13,
        minZoom: 5,
        maxZoom: 19,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
        onTap: widget.mode == DeliveryZoneMode.polygon
            ? (_, point) => widget.onTap(point.latitude, point.longitude)
            : null,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.tostusahane.tostu_sahane',
        ),
        if (zonePolygons.isNotEmpty) PolygonLayer(polygons: zonePolygons),
        if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
        MarkerLayer(markers: markers),
      ],
    );
  }
}

List<GeoPoint> defaultPolygonAroundBranch(Branch branch, {double delta = 0.012}) {
  return [
    GeoPoint(latitude: branch.latitude + delta, longitude: branch.longitude - delta),
    GeoPoint(latitude: branch.latitude + delta, longitude: branch.longitude + delta),
    GeoPoint(latitude: branch.latitude - delta, longitude: branch.longitude + delta),
    GeoPoint(latitude: branch.latitude - delta, longitude: branch.longitude - delta),
  ];
}

/// Mesafe modunda km → yaklaşık derece (enlem).
double kmToLatDelta(double km) => km / 111.0;

double kmToLngDelta(double km, double atLatitude) =>
    km / (111.0 * math.cos(atLatitude * math.pi / 180));
