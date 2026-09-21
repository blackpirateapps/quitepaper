import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'location_models.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// Service for acquiring device location, reverse geocoding to human-readable addresses,
/// and opening location in external map applications.
class LocationService {
  LocationService({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

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
          'User-Agent': 'QuitePaper/1.5.8 (https://github.com/blackpirateapps/quitepaper)',
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
