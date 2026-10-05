import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:city_events/models/app_event.dart';
import 'package:city_events/services/location_service.dart';

/// One event, drawn as a card in a list.
///
/// Used by Discover now and by My Events in Phase 7. It knows how to draw an
/// event and nothing else - what happens when it is tapped is decided by
/// whoever placed it, through [onTap].
class EventCard extends StatelessWidget {
  final AppEvent event;

  /// What to do when the card is tapped. Passed in rather than decided here,
  /// because Discover opens the detail screen while My Events will open the
  /// edit form.
  final VoidCallback? onTap;

  /// How far this event is from the user, in kilometres.
  ///
  /// Null when we do not know - the permission was denied, or the location is
  /// still being fetched. The card simply leaves the line out in that case,
  /// rather than showing a wrong or placeholder distance.
  final double? distanceKm;

  /// The tag that links this card's photo to the same photo on the detail
  /// screen, so Flutter can animate it flying from one to the other.
  ///
  /// Passed in rather than built from the event id alone, because two tabs
  /// can show the same event at once (Discover and My Events), and two photos
  /// on screen with the same tag is an error. Each list adds its own prefix.
  final String heroTag;

  /// Optional extra row at the bottom of the card. My Events uses it for the
  /// Edit and Delete buttons; Discover leaves it out, because you can only
  /// change events you own.
  final Widget? footer;

  const EventCard({
    super.key,
    required this.event,
    required this.heroTag,
    this.onTap,
    this.distanceKm,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      // Elevation, margin and corner radius all come from cardTheme in
      // app_theme.dart, so every card in the app matches without repeating
      // itself here.
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // InkWell inside the Card gives the Material ripple on tap. Wrapping
        // the Card in it instead would draw the ripple outside the rounded
        // corners.
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildImage(theme),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildDetails(theme),
            ),
            // An empty box when there is no footer, so Discover cards are
            // unchanged.
            footer ?? const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  /// The photo strip across the top of the card.
  ///
  /// Takes the theme for its placeholder colours; gives back a fixed-height
  /// image that handles both the loading and the failed cases.
  Widget _buildImage(ThemeData theme) {
    // Hero marks this photo as "the same thing" as the photo with the same tag
    // on the detail screen. When that screen opens, Flutter moves and resizes
    // the photo between the two positions instead of cutting between them.
    return Hero(
      tag: heroTag,
      child: _buildImageBox(theme),
    );
  }

  /// The fixed-size photo itself, with its loading and error states.
  Widget _buildImageBox(ThemeData theme) {
    return SizedBox(
      // A fixed height keeps every card the same size whatever the photo's
      // real proportions are, so the list does not look ragged.
      height: 160,
      width: double.infinity,
      child: Image.network(
        event.imageUrl,
        // cover fills the box and crops the overflow, rather than stretching
        // the photo out of shape.
        fit: BoxFit.cover,

        // Shown while the image downloads. Without this the card would sit
        // blank and look broken on a slow connection.
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child; // finished
          return Container(
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },

        // Shown if the URL is wrong or the device is offline. The marking
        // scheme asks for error states to be handled gracefully, and a broken
        // image icon on a grey panel is far better than a red crash box.
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.image_not_supported_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
        },
      ),
    );
  }

  /// The title, category, venue and date block under the photo.
  Widget _buildDetails(ThemeData theme) {
    // intl turns the stored millisecond number into something readable, in a
    // format that adapts to the device's locale.
    final String formattedDate =
        DateFormat('EEE, d MMM  h:mm a').format(event.date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                event.title,
                style: theme.textTheme.titleMedium,
                // A long title is cut off with "..." on one line instead of
                // pushing the rest of the card around.
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _buildCategoryChip(theme),
          ],
        ),
        const SizedBox(height: 6),
        _buildIconLine(theme, Icons.place_outlined, event.venueName),
        const SizedBox(height: 2),
        _buildIconLine(theme, Icons.schedule, formattedDate),
        // Only shown once the GPS has given us a position. This line is the
        // visible result of the sensor, and the reason the feed can claim to
        // be sorted by how near things are.
        // Updates by itself, because the list above is a live stream. On a
        // second phone, tapping "I'm going" changes this number here.
        if (event.attendeeCount > 0) ...<Widget>[
          const SizedBox(height: 2),
          _buildIconLine(
            theme,
            Icons.people_outline,
            '${event.attendeeCount} going',
          ),
        ],
        if (distanceKm != null) ...<Widget>[
          const SizedBox(height: 2),
          _buildIconLine(
            theme,
            Icons.near_me_outlined,
            LocationService.describeDistance(distanceKm!),
          ),
        ],
      ],
    );
  }

  /// The small coloured category label in the top-right of the card.
  Widget _buildCategoryChip(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        event.category,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }

  /// One line of small grey text with an icon in front of it.
  ///
  /// Used for the venue and the date, which look the same and would otherwise
  /// be written out twice.
  Widget _buildIconLine(ThemeData theme, IconData icon, String text) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
