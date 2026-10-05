// Tests for turning an OpenWeather reply into a WeatherInfo.
//
// This part can be tested automatically because it is plain Dart: no network,
// no Firebase, no screen. The sample below is a real reply from the API,
// trimmed, captured for Colombo on 21 September 2026.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:city_events/models/weather_info.dart';

void main() {
  const String sampleReply = '''
{
  "weather": [{"id": 501, "main": "Rain", "description": "moderate rain", "icon": "10d"}],
  "main": {"temp": 29.99, "feels_like": 36.99, "humidity": 78},
  "name": "Colombo",
  "cod": 200
}''';

  test('reads temperature, description, icon and humidity', () {
    final WeatherInfo weather = WeatherInfo.fromJson(
      jsonDecode(sampleReply) as Map<String, dynamic>,
    );

    expect(weather.temperature, 29.99);
    expect(weather.feelsLike, 36.99);
    expect(weather.description, 'moderate rain');
    expect(weather.iconCode, '10d');
    expect(weather.humidity, 78);
    expect(
      weather.iconUrl,
      'https://openweathermap.org/img/wn/10d@2x.png',
    );
  });

  test('accepts a whole-number temperature', () {
    // JSON has no separate int and double, so exactly 30 degrees arrives as
    // the integer 30. The model must not crash on that.
    final WeatherInfo weather = WeatherInfo.fromJson(<String, dynamic>{
      'weather': <dynamic>[
        <String, dynamic>{'description': 'clear sky', 'icon': '01d'},
      ],
      'main': <String, dynamic>{'temp': 30, 'feels_like': 33, 'humidity': 60},
    });

    expect(weather.temperature, 30.0);
  });
}
