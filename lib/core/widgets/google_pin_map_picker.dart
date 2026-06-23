import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Yemek sipariş uygulamalarındaki gibi: ortada sabit pin, harita sürüklenir/zoom yapılır.
class GooglePinMapPicker extends StatefulWidget {
  const GooglePinMapPicker({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.onPositionChanged,
    this.onMapCreated,
    this.onPositionChanging,
    this.initialZoom = 16,
  });

  final double latitude;
  final double longitude;
  final ValueChanged<({double lat, double lng})> onPositionChanged;
  final ValueChanged<({double lat, double lng})>? onPositionChanging;
  final ValueChanged<GoogleMapController>? onMapCreated;
  final double initialZoom;

  @override
  State<GooglePinMapPicker> createState() => GooglePinMapPickerState();
}

class GooglePinMapPickerState extends State<GooglePinMapPicker> {
  GoogleMapController? _controller;
  var _ignoreCameraEvents = false;

  @override
  void didUpdateWidget(covariant GooglePinMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _moveCamera(widget.latitude, widget.longitude, animate: true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> moveTo(double lat, double lng, {bool animate = true}) async {
    await _moveCamera(lat, lng, animate: animate);
    widget.onPositionChanged((lat: lat, lng: lng));
  }

  Future<void> _moveCamera(double lat, double lng, {bool animate = true}) async {
    final controller = _controller;
    if (controller == null) return;

    _ignoreCameraEvents = true;
    final target = LatLng(lat, lng);
    if (animate) {
      await controller.animateCamera(CameraUpdate.newLatLng(target));
    } else {
      await controller.moveCamera(CameraUpdate.newLatLng(target));
    }
    _ignoreCameraEvents = false;
  }

  Future<LatLng?> _mapCenter() async {
    final controller = _controller;
    if (controller == null) return null;
    final region = await controller.getVisibleRegion();
    return LatLng(
      (region.northeast.latitude + region.southwest.latitude) / 2,
      (region.northeast.longitude + region.southwest.longitude) / 2,
    );
  }

  Future<void> _emitCenter({required bool finalUpdate}) async {
    if (_ignoreCameraEvents) return;
    final center = await _mapCenter();
    if (center == null || !mounted) return;
    final coords = (lat: center.latitude, lng: center.longitude);
    if (finalUpdate) {
      widget.onPositionChanged(coords);
    } else {
      widget.onPositionChanging?.call(coords);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(widget.latitude, widget.longitude),
            zoom: widget.initialZoom,
          ),
          onMapCreated: (controller) {
            _controller = controller;
            widget.onMapCreated?.call(controller);
          },
          onCameraMove: (_) => _emitCenter(finalUpdate: false),
          onCameraIdle: () => _emitCenter(finalUpdate: true),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
          zoomGesturesEnabled: true,
          scrollGesturesEnabled: true,
          rotateGesturesEnabled: true,
          tiltGesturesEnabled: true,
          compassEnabled: true,
          mapToolbarEnabled: false,
          markers: const {},
        ),
        const Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: 36),
            child: Icon(
              Icons.location_on,
              size: 44,
              color: AppColors.primary,
              shadows: [
                Shadow(color: Colors.white, blurRadius: 8),
              ],
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: AppSpacing.md,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${widget.latitude.toStringAsFixed(5)}, ${widget.longitude.toStringAsFixed(5)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
