import 'package:geocoding/geocoding.dart';

/// Best-effort reverse geocoding. Addresses are a convenience label only --
/// trips are fully usable without them -- so any failure (no network, no
/// geocoder on the device, coordinates over open water, etc.) just means no
/// label rather than a crash.
class GeocodingService {
  static final _geocoding = Geocoding();

  static Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;
      final place = placemarks.first;
      final parts = [
        if (place.street != null && place.street!.isNotEmpty) place.street,
        if (place.locality != null && place.locality!.isNotEmpty)
          place.locality,
      ];
      if (parts.isEmpty) return null;
      return parts.join(', ');
    } catch (_) {
      return null;
    }
  }
}
