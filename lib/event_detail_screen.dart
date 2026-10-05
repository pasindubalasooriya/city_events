import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:city_events/models/app_event.dart';
import 'package:city_events/rsvp_bar.dart';
import 'package:city_events/services/location_service.dart';
import 'package:city_events/weather_panel.dart';

/// The full page for one event - the "detail" half of master/detail.
///
/// Discover is the master: a list of many events. Tapping one pushes this
/// screen with that event passed in through the constructor. Because the event
/// arrives complete, this screen does not read the database at all.
///
/// Portrait stacks the photo above the details; landscape puts them side by
/// side (see build).
class EventDetailScreen extends StatelessWidget {
  final AppEvent event;

  /// How far away it is, if we know - handed over from Discover so we do not
  /// have to ask the GPS a second time.
  final double? distanceKm;

  /// Must match the tag on the card that was tapped, or the photo will not
  /// animate between the two screens.
  final String heroTag;

  const EventDetailScreen({
    super.key,
    required this.event,
    required this.heroTag,
    this.distanceKm,
  });

  /// Opens the event location in the phone's map app.
  ///
  /// A "geo:" link is Android's standard way of saying "show this point on a
  /// map", and Android offers it to whichever map app is installed. If that
  /// fails - for example in a web browser, which does not understand geo:
  /// links - we fall back to a Google Maps web address.
  Future<void> _openInMaps(BuildContext context) async {
    final String point = '${event.lat},${event.lng}';

    final Uri geoLink = Uri.parse(
      'geo:$point?q=$point(${Uri.encodeComponent(event.venueName)})',
    );
    final Uri webLink = Uri.https(
      'www.google.com',
      '/maps/search/',
      <String, String>{'api': '1', 'query': point},
    );

    bool opened = false;
    try {
      // externalApplication means "hand it to another app", not open it
      // inside ours.
      opened = await launchUrl(geoLink, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      opened = await launchUrl(webLink, mode: LaunchMode.externalApplication);
    }

    // context belongs to a screen that may have closed while we waited.
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open a map app.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event details')),
      // OrientationBuilder tells us whether the space we have is taller than
      // it is wide (portrait) or wider than it is tall (landscape), and
      // rebuilds by itself when the phone is turned.
      body: OrientationBuilder(
        builder: (context, orientation) {
          if (orientation == Orientation.landscape) {
            return _buildLandscape(context);
          }
          return _buildPortrait(context);
        },
      ),
    );
  }

  /// Upright phone: the photo across the top, the details scrolling below.
  Widget _buildPortrait(BuildContext context) {
    return ListView(
      children: <Widget>[
        // The same tag as the card that was tapped, so Flutter flies the
        // photo from the list into this position.
        Hero(tag: heroTag, child: _buildImage(context, height: 240)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: _buildBody(context),
        ),
      ],
    );
  }

  /// Sideways phone: the photo on the left, the details on the right.
  ///
  /// Sideways, the screen is short. A 240-high photo on top would fill most
  /// of it, and the title would start below the fold. Putting the two side by
  /// side keeps the photo in view while the details scroll next to it.
  ///
  /// Both layouts use the same _buildImage and _buildBody. Only the
  /// arrangement changes, so nothing is written twice.
  Widget _buildLandscape(BuildContext context) {
    return Row(
      // stretch makes both halves as tall as the screen, so the photo fills
      // the full height of the left side.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Expanded splits the width by flex: 2 parts photo, 3 parts details.
        Expanded(
          flex: 2,
          child: Hero(
            tag: heroTag,
            child: _buildImage(context, height: double.infinity),
          ),
        ),
        Expanded(
          flex: 3,
          // Only the details scroll. The photo stays where it is.
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[_buildBody(context)],
          ),
        ),
      ],
    );
  }

  /// The event photo.
  ///
  /// The height is passed in because the two layouts need different ones: a
  /// fixed strip in portrait, the full height of the left half in landscape
  /// (double.infinity means "as tall as the space allows").
  Widget _buildImage(BuildContext context, {required double height}) {
    final ThemeData theme = Theme.of(context);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Image.network(
        event.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.image_not_supported_outlined, size: 48),
        ),
      ),
    );
  }

  /// Everything except the photo: title, RSVP, facts, weather, map button.
  Widget _buildBody(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(event.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        _buildTags(theme),
        const SizedBox(height: 16),
        RsvpBar(eventId: event.id),
        const SizedBox(height: 16),
        _buildFacts(theme),
        const SizedBox(height: 16),
        Text('About', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(event.description, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 20),
        WeatherPanel(
          lat: event.lat,
          lng: event.lng,
          isOutdoor: event.isOutdoor,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => _openInMaps(context),
          icon: const Icon(Icons.map_outlined),
          label: const Text('Open in Maps'),
        ),
      ],
    );
  }

  /// The category and indoor/outdoor labels under the title.
  Widget _buildTags(ThemeData theme) {
    return Wrap(
      spacing: 8,
      children: <Widget>[
        Chip(label: Text(event.category)),
        Chip(
          avatar: Icon(
            event.isOutdoor ? Icons.park_outlined : Icons.home_outlined,
            size: 18,
          ),
          label: Text(event.isOutdoor ? 'Outdoor' : 'Indoor'),
        ),
      ],
    );
  }

  /// When, where, how far, and who is organising it.
  Widget _buildFacts(ThemeData theme) {
    final String when =
        DateFormat('EEEE d MMMM yyyy, h:mm a').format(event.date);

    return Column(
      children: <Widget>[
        _buildFact(theme, Icons.schedule, when),
        _buildFact(theme, Icons.place_outlined, event.venueName),
        if (distanceKm != null)
          _buildFact(
            theme,
            Icons.near_me_outlined,
            LocationService.describeDistance(distanceKm!),
          ),
        _buildFact(
          theme,
          Icons.person_outline,
          'Organised by ${event.ownerName}',
        ),
      ],
    );
  }

  /// One icon-and-text line in the facts block.
  Widget _buildFact(ThemeData theme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
