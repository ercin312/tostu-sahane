import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/services/location_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/osm_pin_map_picker.dart';

class AddressMapPickerPage extends StatefulWidget {
  const AddressMapPickerPage({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  final double? initialLat;
  final double? initialLng;

  @override
  State<AddressMapPickerPage> createState() => _AddressMapPickerPageState();
}

class _AddressMapPickerPageState extends State<AddressMapPickerPage> {
  late double _lat;
  late double _lng;
  String? _address;
  var _locating = true;
  Timer? _geocodeDebounce;

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _lat = widget.initialLat ?? AppConstants.defaultMapLatitude;
    _lng = widget.initialLng ?? AppConstants.defaultMapLongitude;
    _initLocation();
  }

  Future<void> _initLocation() async {
    if (widget.initialLat != null && widget.initialLng != null) {
      await _reverseGeocode();
      if (mounted) setState(() => _locating = false);
      return;
    }

    final position = await LocationService.getCurrentPosition();
    if (position != null && mounted) {
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
      });
    }
    await _reverseGeocode();
    if (mounted) setState(() => _locating = false);
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _locating = true);
    final position = await LocationService.getCurrentPosition();
    if (position != null && mounted) {
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
      });
      await _reverseGeocode();
    }
    if (mounted) setState(() => _locating = false);
  }

  Future<void> _reverseGeocode() async {
    try {
      final places = await placemarkFromCoordinates(_lat, _lng);
      if (!mounted) return;
      if (places.isNotEmpty) {
        final p = places.first;
        setState(() {
          _address = [
            p.street,
            p.subLocality,
            p.locality,
            p.administrativeArea,
          ].where((e) => e != null && e.isNotEmpty).join(', ');
        });
      }
    } catch (_) {
      if (mounted) setState(() => _address = null);
    }
  }

  void _scheduleGeocode({bool immediate = false}) {
    _geocodeDebounce?.cancel();
    if (immediate) {
      _reverseGeocode();
      return;
    }
    _geocodeDebounce = Timer(const Duration(milliseconds: 400), _reverseGeocode);
  }

  void _onPositionChanged(double lat, double lng, {bool immediate = false}) {
    setState(() {
      _lat = lat;
      _lng = lng;
    });
    _scheduleGeocode(immediate: immediate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.addressMapPickerTitle.tr()),
        actions: [
          IconButton(
            tooltip: LocaleKeys.addressUseCurrentLocation.tr(),
            onPressed: _locating ? null : _goToCurrentLocation,
            icon: _locating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: OsmPinMapPicker(
              latitude: _lat,
              longitude: _lng,
              onPositionChanging: (pos) => _onPositionChanged(
                pos.lat,
                pos.lng,
              ),
              onPositionChanged: (pos) => _onPositionChanged(
                pos.lat,
                pos.lng,
                immediate: true,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            color: AppColors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  LocaleKeys.addressMapPickerHint.tr(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _address ?? LocaleKeys.addressMapPickerUnknown.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'latitude': _lat,
                      'longitude': _lng,
                      'address': _address ??
                          '${_lat.toStringAsFixed(5)}, ${_lng.toStringAsFixed(5)}',
                    });
                  },
                  child: Text(LocaleKeys.addressMapPickerConfirm.tr()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
