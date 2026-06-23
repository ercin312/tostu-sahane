import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Google Maps anahtarı olmadığında OpenStreetMap — pinch zoom ve sürükleme destekli.
/// Ortada sabit pin; harita hareket ederek konum seçilir.
class OsmPinMapPicker extends StatefulWidget {
  const OsmPinMapPicker({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.onPositionChanged,
    this.onPositionChanging,
    this.initialZoom = 16,
  });

  final double latitude;
  final double longitude;
  final ValueChanged<({double lat, double lng})> onPositionChanged;
  final ValueChanged<({double lat, double lng})>? onPositionChanging;
  final double initialZoom;

  @override
  State<OsmPinMapPicker> createState() => _OsmPinMapPickerState();
}

class _OsmPinMapPickerState extends State<OsmPinMapPicker> {
  final _mapController = MapController();
  var _ignoreMapEvents = false;

  @override
  void initState() {
    super.initState();
    _mapController.mapEventStream.listen((event) {
      if (_ignoreMapEvents) return;
      if (event is MapEventMove) {
        final center = _mapController.camera.center;
        widget.onPositionChanging?.call(
          (lat: center.latitude, lng: center.longitude),
        );
      } else if (event is MapEventMoveEnd) {
        final center = _mapController.camera.center;
        widget.onPositionChanged(
          (lat: center.latitude, lng: center.longitude),
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant OsmPinMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _moveTo(widget.latitude, widget.longitude);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _moveTo(double lat, double lng) {
    _ignoreMapEvents = true;
    _mapController.move(
      LatLng(lat, lng),
      _mapController.camera.zoom,
    );
    _ignoreMapEvents = false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(widget.latitude, widget.longitude),
            initialZoom: widget.initialZoom,
            minZoom: 5,
            maxZoom: 19,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.tostusahane.tostu_sahane',
            ),
          ],
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
