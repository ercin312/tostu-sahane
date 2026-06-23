import 'package:flutter/material.dart';

import 'osm_tile_map_view.dart';

/// Şube → teslimat rotasını uygulama içinde gösterir (OpenStreetMap).
/// Dış navigasyon için [MapsNavigationUtils] kullanılır.
class LiveDeliveryMapView extends StatefulWidget {
  const LiveDeliveryMapView({
    super.key,
    required this.branchLat,
    required this.branchLng,
    required this.deliveryLat,
    required this.deliveryLng,
    this.height = 320,
    this.animateCourier = false,
    this.courierLat,
    this.courierLng,
  });

  final double branchLat;
  final double branchLng;
  final double deliveryLat;
  final double deliveryLng;
  final double height;
  final bool animateCourier;
  final double? courierLat;
  final double? courierLng;

  /// Uygulama içi harita her zaman OSM kullanır.
  static bool get usesSimulatedFallback => true;

  @override
  State<LiveDeliveryMapView> createState() => _LiveDeliveryMapViewState();
}

class _LiveDeliveryMapViewState extends State<LiveDeliveryMapView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _courierController;
  late final Animation<double> _courierProgress;

  @override
  void initState() {
    super.initState();
    _courierController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _courierProgress = CurvedAnimation(
      parent: _courierController,
      curve: Curves.linear,
    );
    _courierController.addListener(_onCourierAnimationTick);
    _syncCourierAnimation();
  }

  @override
  void didUpdateWidget(covariant LiveDeliveryMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncCourierAnimation();
  }

  @override
  void dispose() {
    _courierController
      ..removeListener(_onCourierAnimationTick)
      ..dispose();
    super.dispose();
  }

  void _onCourierAnimationTick() {
    if (_shouldAnimateCourier && mounted) {
      setState(() {});
    }
  }

  void _syncCourierAnimation() {
    if (_shouldAnimateCourier) {
      if (!_courierController.isAnimating) {
        _courierController.repeat();
      }
    } else if (_courierController.isAnimating) {
      _courierController.stop();
    }
  }

  bool get _hasMovedCourier {
    final lat = widget.courierLat;
    final lng = widget.courierLng;
    if (lat == null || lng == null) return false;
    const epsilon = 0.00005;
    return (lat - widget.branchLat).abs() > epsilon ||
        (lng - widget.branchLng).abs() > epsilon;
  }

  bool get _shouldAnimateCourier =>
      widget.animateCourier && !_hasMovedCourier;

  double? get _displayCourierLat {
    if (_hasMovedCourier) return widget.courierLat;
    if (!_shouldAnimateCourier) return null;
    return widget.branchLat +
        (widget.deliveryLat - widget.branchLat) * _courierProgress.value;
  }

  double? get _displayCourierLng {
    if (_hasMovedCourier) return widget.courierLng;
    if (!_shouldAnimateCourier) return null;
    return widget.branchLng +
        (widget.deliveryLng - widget.branchLng) * _courierProgress.value;
  }

  @override
  Widget build(BuildContext context) {
    return OsmTileMapView(
      branchLat: widget.branchLat,
      branchLng: widget.branchLng,
      deliveryLat: widget.deliveryLat,
      deliveryLng: widget.deliveryLng,
      height: widget.height,
      courierLat: _displayCourierLat,
      courierLng: _displayCourierLng,
    );
  }
}
