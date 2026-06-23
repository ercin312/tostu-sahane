import 'package:url_launcher/url_launcher.dart';

/// Google Haritalar ile adres veya koordinata yönlendirme.
abstract final class MapsNavigationUtils {
  static Future<bool> openNavigation({
    required String address,
    double? latitude,
    double? longitude,
  }) async {
    final Uri uri;
    if (latitude != null && longitude != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=$latitude,$longitude'
        '&travelmode=driving',
      );
    } else {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=${Uri.encodeComponent(address)}'
        '&travelmode=driving',
      );
    }
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
