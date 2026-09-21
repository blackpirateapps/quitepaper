import 'package:flutter/foundation.dart';

/// Represents geographic location metadata associated with a journal entry or note.
@immutable
class JournalLocation {
  const JournalLocation({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  /// Human-readable address (e.g., street, city, state, country).
  final String address;

  /// Latitude coordinate in decimal degrees.
  final double latitude;

  /// Longitude coordinate in decimal degrees.
  final double longitude;

  bool get isEmpty =>
      address.trim().isEmpty && latitude == 0.0 && longitude == 0.0;

  bool get isNotEmpty => !isEmpty;

  /// Returns the primary text to display to the user.
  String get displayString {
    if (address.trim().isNotEmpty) {
      return address.trim();
    }
    if (latitude != 0.0 || longitude != 0.0) {
      return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
    }
    return '';
  }

  /// Returns coordinates formatted as "lat, lng".
  String get coordinatesString {
    if (latitude != 0.0 || longitude != 0.0) {
      return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
    }
    return '';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalLocation &&
          runtimeType == other.runtimeType &&
          address == other.address &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => Object.hash(address, latitude, longitude);

  @override
  String toString() =>
      'JournalLocation(address: $address, lat: $latitude, lng: $longitude)';

  static const empty = JournalLocation(
    address: '',
    latitude: 0.0,
    longitude: 0.0,
  );
}
