/// The current weather at one place, as the app needs it.
///
/// OpenWeather sends back a large JSON document. This class keeps only the
/// handful of values the detail screen actually shows, with names that make
/// sense in our code rather than the API's own.
class WeatherInfo {
  /// Degrees Celsius. Celsius only because we ask with units=metric; without
  /// that the API answers in Kelvin, and 30 degrees would arrive as 303.
  final double temperature;
  final double feelsLike;

  /// A short phrase such as "moderate rain".
  final String description;

  /// OpenWeather's code for the matching picture, e.g. "10d".
  final String iconCode;

  /// Percentage, 0 to 100.
  final int humidity;

  const WeatherInfo({
    required this.temperature,
    required this.feelsLike,
    required this.description,
    required this.iconCode,
    required this.humidity,
  });

  /// Where to download the picture for [iconCode]. The @2x version is sharp
  /// on high-density phone screens.
  String get iconUrl => 'https://openweathermap.org/img/wn/$iconCode@2x.png';

  /// Builds a WeatherInfo from the decoded JSON of one API response.
  ///
  /// The shape we read from, trimmed to the parts we use:
  ///
  ///     {
  ///       "weather": [ { "description": "moderate rain", "icon": "10d" } ],
  ///       "main": { "temp": 29.9, "feels_like": 36.9, "humidity": 78 }
  ///     }
  ///
  /// Note that "weather" is a list, so the description is weather[0], not
  /// weather. Getting that wrong is the most common mistake with this API.
  factory WeatherInfo.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> main = json['main'] as Map<String, dynamic>;
    final List<dynamic> conditions = json['weather'] as List<dynamic>;
    final Map<String, dynamic> first = conditions.first as Map<String, dynamic>;

    return WeatherInfo(
      // num, then converted, because JSON has no separate int and double: a
      // temperature of exactly 30 arrives as the integer 30.
      temperature: (main['temp'] as num).toDouble(),
      feelsLike: (main['feels_like'] as num).toDouble(),
      humidity: (main['humidity'] as num).toInt(),
      description: first['description'] as String,
      iconCode: first['icon'] as String,
    );
  }
}
