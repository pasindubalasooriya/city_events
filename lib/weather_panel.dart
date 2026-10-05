import 'package:flutter/material.dart';

import 'package:city_events/models/weather_info.dart';
import 'package:city_events/services/weather_service.dart';

/// The weather box on the event detail screen.
///
/// It is its own widget, rather than part of the detail screen, for two
/// reasons. The weather loads separately from everything else, so it needs its
/// own loading and error states; and keeping its FutureBuilder in here means
/// the detail screen has no builders nested inside it at all.
class WeatherPanel extends StatefulWidget {
  final double lat;
  final double lng;

  /// Outdoor events get an extra line saying the weather matters.
  final bool isOutdoor;

  const WeatherPanel({
    super.key,
    required this.lat,
    required this.lng,
    required this.isOutdoor,
  });

  @override
  State<WeatherPanel> createState() => _WeatherPanelState();
}

class _WeatherPanelState extends State<WeatherPanel> {
  final WeatherService _weatherService = WeatherService();

  /// The request in progress, or finished.
  ///
  /// Started once in initState and kept here. If it were started inside
  /// build(), every rebuild of the screen would fire a new request to the API.
  late Future<WeatherInfo> _weatherFuture;

  @override
  void initState() {
    super.initState();
    _weatherFuture = _weatherService.fetchWeather(widget.lat, widget.lng);
  }

  /// Starts a fresh request. setState makes the FutureBuilder below notice the
  /// new Future and show its loading state again.
  void _retry() {
    setState(() {
      _weatherFuture = _weatherService.fetchWeather(widget.lat, widget.lng);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Weather at the venue now',
              style: theme.textTheme.titleSmall,
            ),
            if (widget.isOutdoor)
              Text(
                'This is an outdoor event, so it is worth checking.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 12),
            // A FutureBuilder rebuilds this part when the request finishes.
            // Like a StreamBuilder, but for one answer instead of many.
            FutureBuilder<WeatherInfo>(
              future: _weatherFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 56,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return _buildError(theme);
                }
                return _buildWeather(theme, snapshot.data!);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// The loaded state: icon, temperature, and the details beside it.
  Widget _buildWeather(ThemeData theme, WeatherInfo weather) {
    return Row(
      children: <Widget>[
        Image.network(
          weather.iconUrl,
          width: 56,
          height: 56,
          // If the icon itself fails to download, a plain cloud is better
          // than an error box inside an otherwise working panel.
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.cloud_outlined, size: 40),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${weather.temperature.round()}°C',
                style: theme.textTheme.headlineSmall,
              ),
              Text(
                // "moderate rain" -> "Moderate rain"
                weather.description[0].toUpperCase() +
                    weather.description.substring(1),
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                'Feels like ${weather.feelsLike.round()}°C  ·  '
                'Humidity ${weather.humidity}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The failed state. Only this box shows the problem; the event details
  /// around it are already on screen and keep working.
  Widget _buildError(ThemeData theme) {
    return Row(
      children: <Widget>[
        Icon(Icons.cloud_off, color: theme.colorScheme.error),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Weather unavailable. Check your connection.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        TextButton(onPressed: _retry, child: const Text('Retry')),
      ],
    );
  }
}
