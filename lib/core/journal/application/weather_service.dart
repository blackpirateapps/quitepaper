import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../domain/journal_weather.dart';

final weatherServiceProvider = Provider<WeatherService>((ref) {
  return WeatherService();
});

/// Service for fetching current weather conditions from Open-Meteo API.
/// Free, zero API key, privacy-friendly.
class WeatherService {
  WeatherService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Fetches current weather for the provided coordinates.
  Future<JournalWeather> fetchWeather(double latitude, double longitude) async {
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current=temperature_2m,weather_code,is_day&temperature_unit=celsius',
    );

    try {
      final response = await _httpClient.get(
        url,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'QuitePaper/1.6.4',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        throw WeatherFetchException(
          'Failed to fetch weather: HTTP ${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body);
      final current = data is Map<String, dynamic> ? data['current'] : null;
      if (current is! Map<String, dynamic>) {
        throw const WeatherFetchException('Malformed weather data received');
      }
      final temperature = current['temperature_2m'];
      final weatherCode = current['weather_code'];
      if (temperature is! num || !temperature.isFinite ||
          weatherCode is! num || !weatherCode.isFinite ||
          weatherCode < 0 || weatherCode != weatherCode.roundToDouble()) {
        throw const WeatherFetchException('Incomplete or invalid weather measurements');
      }
      final temp = temperature.toDouble();
      final code = weatherCode.toInt();
      final condition = JournalWeather.conditionForWmoCode(code);

      return JournalWeather(
        temperature: temp,
        condition: condition,
        code: code,
      );
    } catch (e) {
      if (e is WeatherFetchException) rethrow;
      if (e is FormatException) {
        throw const WeatherFetchException('Malformed weather data received');
      }
      debugPrint('[WeatherService] Error fetching weather: $e');
      throw WeatherFetchException('Could not connect to weather service: $e');
    }
  }
}

class WeatherFetchException implements Exception {
  const WeatherFetchException(this.message);
  final String message;

  @override
  String toString() => message;
}
