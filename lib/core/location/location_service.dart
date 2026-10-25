import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../version/app_version_provider.dart';
import 'location_models.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  final versionInfo = ref.watch(appVersionInfoProvider);
  return LocationService(appVersion: versionInfo.version);
});

/// Service for acquiring device location, reverse geocoding to human-readable addresses,
/// and opening location in external map applications.
class LocationService {
  LocationService({http.Client? httpClient, this._appVersion = '1.6.2'})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  final String _appVersion;

  /// Fetches the current location coordinates and human-readable address.
  /// Throws descriptive exceptions on permission denial or service disabled so the UI
  /// can present appropriate user guidance.
  Future<JournalLocation> fetchCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationPermissionDeniedException('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionDeniedException(
        'Location permissions are permanently denied. Please enable them in system settings.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 12),
      ),
    );

    final address = await reverseGeocode(position.latitude, position.longitude);

    return JournalLocation(
      address: address,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  /// Forward-geocodes a free-text [query] into candidate places using the
  /// device-native geocoder (on Android, `Geocoder.getFromLocationName`). No
  /// external service is added and no location permission is required — only
  /// network connectivity. Returns readable [JournalLocation]s WITHOUT
  /// coordinates (lat/lng = 0); resolve the chosen one with [geocodeCoordinates]
  /// on pick. Returns an empty list when nothing matches, the geocoder is
  /// unavailable (e.g. desktop), or [query] is blank. Never throws.
  Future<List<JournalLocation>> searchPlaces(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const <JournalLocation>[];
    try {
      final placemarks = await Geocoding().placemarkFromAddress(q);
      final seen = <String>{};
      final results = <JournalLocation>[];
      for (final p in placemarks) {
        final address = _formatPlacemark(p);
        if (address.isEmpty) continue;
        if (!seen.add(address.toLowerCase())) continue;
        results.add(JournalLocation(address: address, latitude: 0, longitude: 0));
      }
      return results;
    } catch (e) {
      debugPrint('[LocationService] Forward geocoding unavailable or failed: $e');
      return const <JournalLocation>[];
    }
  }

  /// Resolves coordinates for an already-chosen [address] via the native
  /// geocoder, returning a [JournalLocation] carrying lat/lng when found, or the
  /// coordinate-less input (lat/lng = 0) when resolution fails. Never throws, so
  /// a searched place is always usable even if coordinates can't be attached.
  Future<JournalLocation> geocodeCoordinates(String address) async {
    final a = address.trim();
    final fallback = JournalLocation(address: a, latitude: 0, longitude: 0);
    if (a.isEmpty) return fallback;
    try {
      final locations = await Geocoding().locationFromAddress(a);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        return JournalLocation(
          address: a,
          latitude: loc.latitude,
          longitude: loc.longitude,
        );
      }
    } catch (e) {
      debugPrint('[LocationService] Coordinate resolution failed: $e');
    }
    return fallback;
  }

  /// Joins the meaningful parts of a forward-geocoded [Placemark] into a single
  /// clean line, de-duplicating repeated tokens (Android often echoes the
  /// locality in `name`).
  String _formatPlacemark(Placemark p) {
    final parts = <String>[];
    final name = p.name?.trim();
    final street = p.street?.trim();
    final locality = (p.locality?.trim().isNotEmpty ?? false)
        ? p.locality!.trim()
        : p.subAdministrativeArea?.trim();
    final admin = p.administrativeArea?.trim();
    final country = p.country?.trim();

    if (name != null && name.isNotEmpty && name != locality && name != admin) {
      parts.add(name);
    } else if (street != null && street.isNotEmpty && street != locality) {
      parts.add(street);
    }
    if (locality != null && locality.isNotEmpty && !parts.contains(locality)) {
      parts.add(locality);
    }
    if (admin != null && admin.isNotEmpty && !parts.contains(admin)) {
      parts.add(admin);
    }
    if (country != null && country.isNotEmpty && !parts.contains(country)) {
      parts.add(country);
    }
    return parts.join(', ');
  }

  /// Reverse-geocodes latitude and longitude into a clean, human-readable address.
  /// Tries device-native geocoder first; if unavailable (e.g. Linux desktop or platform error),
  /// seamlessly falls back to OpenStreetMap Nominatim API, and ultimately coordinates string.
  Future<String> reverseGeocode(double latitude, double longitude) async {
    // 1. Try native platform geocoding (Android / iOS)
    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[];

        final street = p.street;
        if (street != null && street.trim().isNotEmpty) parts.add(street.trim());

        final city = p.locality ?? p.subAdministrativeArea;
        if (city != null && city.trim().isNotEmpty) parts.add(city.trim());

        final adminArea = p.administrativeArea;
        if (adminArea != null && adminArea.trim().isNotEmpty) parts.add(adminArea.trim());

        final country = p.country;
        if (country != null && country.trim().isNotEmpty) parts.add(country.trim());

        if (parts.isNotEmpty) {
          return parts.join(', ');
        }
      }
    } catch (e) {
      debugPrint('[LocationService] Native geocoding unavailable or failed: $e');
    }

    // 2. Fallback to OpenStreetMap Nominatim
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$latitude&lon=$longitude&format=json&zoom=18&addressdetails=1',
      );
      final response = await _httpClient.get(
        url,
        headers: {
          'User-Agent': 'QuitePaper/$_appVersion (https://github.com/blackpirateapps/quitepaper)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.trim().isNotEmpty) {
          // If address object has cleaner breakdown, use it
          final addr = data['address'] as Map<String, dynamic>?;
          if (addr != null) {
            final parts = <String>[];
            final road = addr['road'] ?? addr['pedestrian'] ?? addr['suburb'];
            final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'];
            final state = addr['state'];
            final country = addr['country'];

            if (road != null && road.toString().trim().isNotEmpty) parts.add(road.toString().trim());
            if (city != null && city.toString().trim().isNotEmpty) parts.add(city.toString().trim());
            if (state != null && state.toString().trim().isNotEmpty) parts.add(state.toString().trim());
            if (country != null && country.toString().trim().isNotEmpty) parts.add(country.toString().trim());

            if (parts.isNotEmpty) {
              return parts.join(', ');
            }
          }
          return displayName.trim();
        }
      }
    } catch (e) {
      debugPrint('[LocationService] OSM Nominatim reverse geocoding fallback error: $e');
    }

    // 3. Ultimate fallback: coordinate representation
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  /// Opens the given coordinates in external map applications using `geo:` URI,
  /// with automatic web fallback to Google Maps.
  Future<bool> openInMaps(double latitude, double longitude, {String? address}) async {
    final query = address != null && address.trim().isNotEmpty
        ? Uri.encodeComponent(address.trim())
        : '$latitude,$longitude';

    // 1. Try geo: URI
    final geoUri = Uri.parse('geo:$latitude,$longitude?q=$query');
    try {
      if (await canLaunchUrl(geoUri)) {
        final launched = await launchUrl(geoUri);
        if (launched) return true;
      }
    } catch (e) {
      debugPrint('[LocationService] Error launching geo URI: $e');
    }

    // 2. Web fallback (Google Maps Search)
    final webUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    try {
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[LocationService] Error launching web map: $e');
      return false;
    }
  }
}

class LocationPermissionDeniedException implements Exception {
  const LocationPermissionDeniedException(this.message);
  final String message;

  @override
  String toString() => message;
}
