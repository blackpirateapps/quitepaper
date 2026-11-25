import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quitepaper/core/journal/application/weather_service.dart';

void main() {
  for (final payload in [
    '{}', '[]', 'invalid json', '{"current":null}', '{"current":[]}',
    '{"current":{}}',
    '{"current":{"weather_code":3}}',
    '{"current":{"temperature_2m":25}}',
    '{"current":{"temperature_2m":null,"weather_code":3}}',
    '{"current":{"temperature_2m":25,"weather_code":null}}',
    '{"current":{"temperature_2m":"25","weather_code":3}}',
    '{"current":{"temperature_2m":25,"weather_code":"3"}}',
    '{"current":{"temperature_2m":25,"weather_code":3.5}}',
    '{"current":{"temperature_2m":25,"weather_code":-1}}',
    '{"current":{"temperature_2m":1e999,"weather_code":3}}',
    '{"current":{"temperature_2m":25,"weather_code":1e999}}',
  ]) {
    test('rejects malformed or incomplete measurements: $payload', () async {
      final client = MockClient((_) async => http.Response(payload, 200));
      addTearDown(client.close);
      await expectLater(WeatherService(httpClient: client).fetchWeather(22.57, 88.36),
        throwsA(isA<WeatherFetchException>()));
    });
  }
  test('retains measured temperature and condition from a complete response', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['temperature_unit'], 'celsius');
      return http.Response('{"current":{"temperature_2m":28.5,"weather_code":3}}', 200);
    });
    addTearDown(client.close);
    final weather = await WeatherService(httpClient: client).fetchWeather(22.57, 88.36);
    expect(weather.temperature, 28.5);
    expect(weather.code, 3);
    expect(weather.condition, 'Overcast');
  });
  test('accepts real zero Celsius and clear-sky measurements', () async {
    final client = MockClient((_) async => http.Response(
      '{"current":{"temperature_2m":0,"weather_code":0}}', 200));
    addTearDown(client.close);
    final weather = await WeatherService(httpClient: client).fetchWeather(22.57, 88.36);
    expect(weather.temperature, 0);
    expect(weather.code, 0);
  });
  test('HTTP failures remain recoverable weather errors', () async {
    final client = MockClient((_) async => http.Response('Unavailable', 503));
    addTearDown(client.close);
    await expectLater(WeatherService(httpClient: client).fetchWeather(22.57, 88.36),
      throwsA(isA<WeatherFetchException>()));
  });
}
