import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../localization/locale_keys.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../../shared/domain/entities/order.dart';

List<Polyline> _routePolylines({
  required LatLng branch,
  required LatLng delivery,
  double? courierLat,
  double? courierLng,
  bool muted = false,
}) {
  final color = muted
      ? AppColors.primary.withValues(alpha: 0.55)
      : AppColors.primary;
  final width = muted ? 3.0 : 4.0;

  if (courierLat != null && courierLng != null) {
    final courier = LatLng(courierLat, courierLng);
    return [
      Polyline(
        points: [branch, courier],
        color: color,
        strokeWidth: width,
      ),
      Polyline(
        points: [courier, delivery],
        color: color.withValues(alpha: muted ? 1 : 0.85),
        strokeWidth: width,
      ),
    ];
  }

  return [
    Polyline(
      points: [branch, delivery],
      color: color,
      strokeWidth: width,
    ),
  ];
}

/// Google Maps olmayan platformlarda canlı teslimat haritası (OpenStreetMap).
class OsmTileMapView extends StatelessWidget {
  const OsmTileMapView({
    super.key,
    required this.branchLat,
    required this.branchLng,
    required this.deliveryLat,
    required this.deliveryLng,
    this.height = 320,
    this.courierLat,
    this.courierLng,
  });

  final double branchLat;
  final double branchLng;
  final double deliveryLat;
  final double deliveryLng;
  final double height;
  final double? courierLat;
  final double? courierLng;

  @override
  Widget build(BuildContext context) {
    final branch = LatLng(branchLat, branchLng);
    final delivery = LatLng(deliveryLat, deliveryLng);
    final cameraPoints = [branch, delivery];
    if (courierLat != null && courierLng != null) {
      cameraPoints.add(LatLng(courierLat!, courierLng!));
    }

    final markers = <Marker>[
      Marker(
        point: branch,
        width: 40,
        height: 40,
        child: const Icon(Icons.store, color: AppColors.primary, size: 32),
      ),
      Marker(
        point: delivery,
        width: 40,
        height: 40,
        child: const Icon(Icons.location_on, color: AppColors.success, size: 32),
      ),
      if (courierLat != null && courierLng != null)
        Marker(
          point: LatLng(courierLat!, courierLng!),
          width: 44,
          height: 44,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 6,
                ),
              ],
            ),
            child: const Icon(
              Icons.delivery_dining,
              color: AppColors.warning,
              size: 30,
            ),
          ),
        ),
    ];

    return _OsmMapFrame(
      key: ValueKey(
        '${branchLat.toStringAsFixed(5)}_'
        '${branchLng.toStringAsFixed(5)}_'
        '${deliveryLat.toStringAsFixed(5)}_'
        '${deliveryLng.toStringAsFixed(5)}_'
        '${courierLat?.toStringAsFixed(5) ?? 'na'}_'
        '${courierLng?.toStringAsFixed(5) ?? 'na'}',
      ),
      height: height,
      cameraPoints: cameraPoints,
      markers: markers,
      polylines: _routePolylines(
        branch: branch,
        delivery: delivery,
        courierLat: courierLat,
        courierLng: courierLng,
      ),
      overlays: [
        Positioned(
          left: AppSpacing.md,
          top: AppSpacing.md,
          child: _LegendChip(
            icon: Icons.store,
            label: LocaleKeys.courierMapBranch.tr(),
            color: AppColors.primary,
          ),
        ),
        Positioned(
          right: AppSpacing.md,
          bottom: AppSpacing.md,
          child: _LegendChip(
            icon: Icons.location_on,
            label: LocaleKeys.courierMapDestination.tr(),
            color: AppColors.success,
          ),
        ),
        if (courierLat != null && courierLng != null)
          Positioned(
            left: AppSpacing.md,
            bottom: AppSpacing.md,
            child: _LegendChip(
              icon: Icons.delivery_dining,
              label: LocaleKeys.courierMapCourier.tr(),
              color: AppColors.warning,
            ),
          ),
      ],
    );
  }
}

/// Yönetici kurye takibi: aktif teslimatlardaki tüm şube / kurye / adres noktaları.
class OsmActiveDeliveriesMapView extends StatelessWidget {
  const OsmActiveDeliveriesMapView({
    super.key,
    required this.orders,
    required this.branchById,
    this.height = 320,
  });

  final List<Order> orders;
  final Map<String, LatLng> branchById;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cameraPoints = <LatLng>[];
    final markers = <Marker>[];
    final polylines = <Polyline>[];
    final branchMarkerAdded = <String>{};

    for (final order in orders) {
      final branch = branchById[order.branchId];
      if (branch == null) continue;

      cameraPoints.add(branch);

      if (!branchMarkerAdded.contains(order.branchId)) {
        branchMarkerAdded.add(order.branchId);
        markers.add(
          Marker(
            point: branch,
            width: 36,
            height: 36,
            child: const Icon(Icons.store, color: AppColors.primary, size: 28),
          ),
        );
      }

      final deliveryLat = order.deliveryLatitude ?? branch.latitude + 0.012;
      final deliveryLng = order.deliveryLongitude ?? branch.longitude + 0.008;
      final delivery = LatLng(deliveryLat, deliveryLng);
      cameraPoints.add(delivery);
      markers.add(
        Marker(
          point: delivery,
          width: 36,
          height: 36,
          child: const Icon(Icons.location_on, color: AppColors.success, size: 28),
        ),
      );

      final onTheWay = order.status == OrderStatus.onTheWay;
      final hasCourier =
          order.courierLatitude != null && order.courierLongitude != null;
      LatLng? courier;
      if (onTheWay && hasCourier) {
        courier = LatLng(order.courierLatitude!, order.courierLongitude!);
        cameraPoints.add(courier);
        markers.add(
          Marker(
            point: courier,
            width: 36,
            height: 36,
            child: const Icon(
              Icons.delivery_dining,
              color: AppColors.warning,
              size: 28,
            ),
          ),
        );
      }

      polylines.addAll(
        _routePolylines(
          branch: branch,
          delivery: delivery,
          courierLat: courier?.latitude,
          courierLng: courier?.longitude,
          muted: true,
        ),
      );
    }

    if (cameraPoints.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(child: Text(LocaleKeys.adminCourierTrackingEmpty.tr())),
      );
    }

    return _OsmMapFrame(
      height: height,
      cameraPoints: cameraPoints,
      markers: markers,
      polylines: polylines,
      overlays: [
        Positioned(
          left: AppSpacing.md,
          top: AppSpacing.md,
          child: _LegendChip(
            icon: Icons.store,
            label: LocaleKeys.courierMapBranch.tr(),
            color: AppColors.primary,
          ),
        ),
        Positioned(
          right: AppSpacing.md,
          bottom: AppSpacing.md,
          child: _LegendChip(
            icon: Icons.location_on,
            label: LocaleKeys.courierMapDestination.tr(),
            color: AppColors.success,
          ),
        ),
        Positioned(
          left: AppSpacing.md,
          bottom: AppSpacing.md,
          child: _LegendChip(
            icon: Icons.delivery_dining,
            label: LocaleKeys.courierMapCourier.tr(),
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }
}

class _OsmMapFrame extends StatefulWidget {
  const _OsmMapFrame({
    super.key,
    required this.height,
    required this.cameraPoints,
    required this.markers,
    required this.polylines,
    required this.overlays,
  });

  final double height;
  final List<LatLng> cameraPoints;
  final List<Marker> markers;
  final List<Polyline> polylines;
  final List<Widget> overlays;

  @override
  State<_OsmMapFrame> createState() => _OsmMapFrameState();
}

class _OsmMapFrameState extends State<_OsmMapFrame> {
  final _mapController = MapController();
  late OsmMapCamera _camera;

  @override
  void initState() {
    super.initState();
    _camera = fitOsmCamera(widget.cameraPoints);
  }

  @override
  void didUpdateWidget(covariant _OsmMapFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameCameraPoints(oldWidget.cameraPoints, widget.cameraPoints)) {
      _camera = fitOsmCamera(widget.cameraPoints);
      _mapController.move(_camera.center, _camera.zoom);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  bool _sameCameraPoints(List<LatLng> a, List<LatLng> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final pa = a[i];
      final pb = b[i];
      if ((pa.latitude - pb.latitude).abs() > 0.00001 ||
          (pa.longitude - pb.longitude).abs() > 0.00001) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _camera.center,
                  initialZoom: _camera.zoom,
                  minZoom: 5,
                  maxZoom: 19,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.tostusahane.tostu_sahane',
                  ),
                  if (widget.polylines.isNotEmpty)
                    PolylineLayer(polylines: widget.polylines),
                  MarkerLayer(markers: widget.markers),
                ],
              ),
            ),
            ...widget.overlays,
          ],
        ),
      ),
    );
  }
}

class OsmMapCamera {
  const OsmMapCamera({required this.center, required this.zoom});

  final LatLng center;
  final double zoom;
}

OsmMapCamera fitOsmCamera(List<LatLng> points) {
  if (points.isEmpty) {
    return const OsmMapCamera(center: LatLng(41.0082, 28.9784), zoom: 12);
  }

  var minLat = points.first.latitude;
  var maxLat = points.first.latitude;
  var minLng = points.first.longitude;
  var maxLng = points.first.longitude;

  for (final point in points.skip(1)) {
    minLat = math.min(minLat, point.latitude);
    maxLat = math.max(maxLat, point.latitude);
    minLng = math.min(minLng, point.longitude);
    maxLng = math.max(maxLng, point.longitude);
  }

  final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
  final latSpan = (maxLat - minLat).abs();
  final lngSpan = (maxLng - minLng).abs();
  final span = math.max(latSpan, lngSpan);

  final zoom = switch (span) {
    <= 0.0005 => 16.0,
    <= 0.002 => 15.0,
    <= 0.008 => 14.0,
    <= 0.02 => 13.0,
    <= 0.05 => 12.0,
    <= 0.12 => 11.0,
    _ => 10.0,
  };

  return OsmMapCamera(center: center, zoom: zoom);
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
