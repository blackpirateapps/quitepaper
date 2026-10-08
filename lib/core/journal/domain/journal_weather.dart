import 'package:flutter/material.dart';

/// Represents weather metadata associated with a journal entry or note.
@immutable
class JournalWeather {
  const JournalWeather({
    required this.temperature,
    required this.condition,
    required this.code,
  });

  /// Temperature in degrees Celsius.
  final double temperature;

  /// Human-readable weather condition (e.g. "Clear sky", "Partly cloudy", "Rain").
  final String condition;

  /// WMO weather interpretation code.
  final int code;

  bool get isEmpty => condition.trim().isEmpty && temperature == 0.0 && code == 0;
  bool get isNotEmpty => !isEmpty;

  /// Formatted temperature string (e.g. "24°C").
  String get temperatureString => '${temperature.round()}°C';

  /// Formats weather for display (e.g. "24°C, Partly cloudy").
  String get displayString {
    if (condition.trim().isNotEmpty && temperature != 0.0) {
      final roundedTemp = temperature.round();
      return '$roundedTemp°C, ${condition.trim()}';
    }
    if (condition.trim().isNotEmpty) {
      return condition.trim();
    }
    if (temperature != 0.0) {
      return '${temperature.round()}°C';
    }
    return '';
  }

  /// Resolves an appropriate Material icon for the given WMO code.
  IconData get icon => iconForWmoCode(code);

  static IconData iconForWmoCode(int code) {
    if (code == 0) {
      return Icons.wb_sunny_rounded;
    } else if (code <= 3) {
      return Icons.cloud_queue_rounded;
    } else if (code == 45 || code == 48) {
      return Icons.foggy;
    } else if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      return Icons.water_drop_rounded;
    } else if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) {
      return Icons.ac_unit_rounded;
    } else if (code >= 95 && code <= 99) {
      return Icons.thunderstorm_rounded;
    }
    return Icons.wb_cloudy_rounded;
  }

  static String conditionForWmoCode(int code) {
    switch (code) {
      case 0:
        return 'Clear sky';
      case 1:
        return 'Mainly clear';
      case 2:
        return 'Partly cloudy';
      case 3:
        return 'Overcast';
      case 45:
        return 'Fog';
      case 48:
        return 'Depositing rime fog';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 56:
      case 57:
        return 'Freezing drizzle';
      case 61:
        return 'Slight rain';
      case 63:
        return 'Moderate rain';
      case 65:
        return 'Heavy rain';
      case 66:
      case 67:
        return 'Freezing rain';
      case 71:
      case 73:
      case 75:
        return 'Snow fall';
      case 77:
        return 'Snow grains';
      case 80:
      case 81:
      case 82:
        return 'Rain showers';
      case 85:
      case 86:
        return 'Snow showers';
      case 95:
        return 'Thunderstorm';
      case 96:
      case 99:
        return 'Thunderstorm with hail';
      default:
        return 'Cloudy';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalWeather &&
          runtimeType == other.runtimeType &&
          temperature == other.temperature &&
          condition == other.condition &&
          code == other.code;

  @override
  int get hashCode => Object.hash(temperature, condition, code);

  @override
  String toString() => 'JournalWeather($temperature°C, $condition, code: $code)';

  static const empty = JournalWeather(
    temperature: 0.0,
    condition: '',
    code: 0,
  );
}
