import 'package:geocoding/geocoding.dart';

class GeocodingService {
  const GeocodingService();

  Future<({double latitude, double longitude})?> resolveAddress(
    String address,
  ) async {
    try {
      final locations = await locationFromAddress(address);
      if (locations.isEmpty) return null;
      final location = locations.first;
      return (latitude: location.latitude, longitude: location.longitude);
    } catch (_) {
      return null;
    }
  }
}
