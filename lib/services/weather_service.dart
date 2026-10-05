import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:city_events/models/weather_info.dart';

/// Fetches the current weather from the OpenWeather API.
///
/// This is the app's one call to an outside web service, and it follows the
/// pattern from the "http package and API access" lecture: build the URL, send
/// a GET request, check the status code, decode the JSON body.
class WeatherService {
  /// The OpenWeather API key, supplied at build time.
  ///
  /// The key is kept out of the source code so it never reaches the public
  /// repository. It lives in secrets.json, which git ignores, and is passed in
  /// with: flutter run --dart-define-from-file=secrets.json
  ///
  /// It is still built into the installed app, so a determined person could
  /// pull it out. In production the call would go through a server instead.
  static const String _apiKey = String.fromEnvironment('OPENWEATHER_API_KEY');

  /// Gets the weather right now at a latitude and longitude.
  ///
  /// Throws if the network fails, the request takes more than 10 seconds, or
  /// the API answers with anything other than success. The weather panel
  /// catches that and shows a small error, so the rest of the screen is
  /// unaffected.
  Future<WeatherInfo> fetchWeather(double lat, double lng) async {
    // Without the key every request would fail with 401, so say why instead.
    // The weather panel shows its normal error and the rest of the app works.
    if (_apiKey.isEmpty) {
      throw Exception('No OpenWeather key. Run with --dart-define-from-file=secrets.json');
    }

    // Uri.https builds the address and safely encodes the query values.
    // Passing a plain String to http.get is the "String is not a subtype of
    // Uri" error from the lecture; the package only accepts a Uri.
    final Uri url = Uri.https(
      'api.openweathermap.org',
      '/data/2.5/weather',
      <String, String>{
        'lat': lat.toString(),
        'lon': lng.toString(),
        'appid': _apiKey,
        // Celsius instead of the default Kelvin.
        'units': 'metric',
      },
    );

    // await pauses this function, not the app. The screen keeps scrolling and
    // animating while we wait for the reply.
    final http.Response response =
        await http.get(url).timeout(const Duration(seconds: 10));

    // 200 means success. Anything else - 401 for a bad key, 429 for too many
    // requests, 5xx for a server problem - is treated as a failure.
    if (response.statusCode != 200) {
      throw Exception('Weather request failed (${response.statusCode})');
    }

    // The body is plain text. jsonDecode turns it into nested Maps and Lists,
    // and WeatherInfo.fromJson picks out what we need.
    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    return WeatherInfo.fromJson(json);
  }
}
