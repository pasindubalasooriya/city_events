import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:city_events/event_card.dart';
import 'package:city_events/event_detail_screen.dart';
import 'package:city_events/models/app_event.dart';
import 'package:city_events/services/event_service.dart';
import 'package:city_events/services/location_service.dart';

/// Tab 1: the event feed.
///
/// Reads every event live from the Realtime Database, works out how far each
/// one is from the user, and lists them nearest first.
///
/// Stateful because three things change while it is on screen: the category
/// filter, the user position, and whether the location attempt failed.
///
/// On a phone the events are one list; on a tablet or wide window they become
/// a two-column grid (see _buildResults).
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final EventService _eventService = EventService();
  final LocationService _locationService = LocationService();

  /// The category currently filtered to, or null for "All".
  String? _selectedCategory;

  /// Where the user is, once the GPS has told us. Null until then, and null
  /// forever if the permission was refused.
  Position? _userPosition;

  /// The reason we have no location, if something went wrong. Shown in a
  /// banner above the list.
  LocationFailure? _locationFailure;

  bool _isLocating = true;

  /// The live stream of events.
  ///
  /// Held in a field and created once in initState rather than being built
  /// inside build(). build() runs on every setState - including every time a
  /// filter chip is tapped - and creating a new stream each time would tear
  /// down the Firebase listener and set it up again, making the list flicker
  /// back through its loading spinner.
  late final Stream<List<AppEvent>> _eventsStream;

  @override
  void initState() {
    super.initState();
    _eventsStream = _eventService.streamAllEvents();
    // Started here rather than in build(), which would re-ask for the location
    // on every rebuild. initState runs exactly once for this screen.
    _loadLocation();
  }

  /// Asks the GPS where we are.
  ///
  /// A failure is not fatal. The feed still works - it simply falls back to
  /// sorting by date and shows a banner explaining why distances are missing.
  /// The brief requires permission denial to be handled gracefully, and this
  /// is where that is decided.
  Future<void> _loadLocation() async {
    setState(() {
      _isLocating = true;
      _locationFailure = null;
    });

    try {
      final Position position = await _locationService.getCurrentPosition();
      if (!mounted) return;
      setState(() => _userPosition = position);
    } on LocationFailure catch (failure) {
      if (!mounted) return;
      setState(() => _locationFailure = failure);
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  /// How far an event is from the user, or null if we do not know.
  double? _distanceTo(AppEvent event) {
    final Position? me = _userPosition;
    if (me == null) return null;
    return LocationService.distanceInKm(
      me.latitude,
      me.longitude,
      event.lat,
      event.lng,
    );
  }

  /// Filters by category, then orders the list.
  ///
  /// Nearest first when we know where the user is - which is the whole point
  /// of asking for the location. Soonest first when we do not, because an
  /// arbitrary order would look broken.
  List<AppEvent> _prepare(List<AppEvent> events) {
    List<AppEvent> result = events;

    if (_selectedCategory != null) {
      result = result.where((e) => e.category == _selectedCategory).toList();
    } else {
      // Copied because the list from the stream is reused on every rebuild and
      // sorting in place would reorder the original.
      result = List<AppEvent>.of(result);
    }

    if (_userPosition != null) {
      result.sort((a, b) => _distanceTo(a)!.compareTo(_distanceTo(b)!));
    } else {
      result.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: Column(
        children: <Widget>[
          if (_locationFailure != null) _buildLocationBanner(),
          _buildCategoryChips(),
          Expanded(
            child: StreamBuilder<List<AppEvent>>(
              stream: _eventsStream,
              builder: (context, snapshot) {
                // A StreamBuilder has three cases to handle, and the marking
                // scheme asks for all of them. Order matters: check for an
                // error before assuming there is data.

                if (snapshot.hasError) {
                  return _buildError();
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final List<AppEvent> events =
                    _prepare(snapshot.data ?? <AppEvent>[]);

                // The fourth case, which is not an error: the request worked
                // and there is genuinely nothing to show.
                if (events.isEmpty) return _buildEmpty();

                return _buildResults(events);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Explains why distances are missing, and offers a way to fix it.
  ///
  /// Deliberately a banner above the list rather than a dialog or a blank
  /// screen: the app is still perfectly usable without location, so it should
  /// not be interrupted or hidden.
  Widget _buildLocationBanner() {
    final ThemeData theme = Theme.of(context);
    final LocationFailure failure = _locationFailure!;

    return Container(
      width: double.infinity,
      color: theme.colorScheme.secondaryContainer,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.location_off_outlined,
            size: 20,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              failure.message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // A permanently denied permission cannot be re-requested, so asking
          // again would do nothing. Send the user to settings instead.
          TextButton(
            onPressed: _isLocating
                ? null
                : failure.openSettings
                    ? _locationService.openSettings
                    : _loadLocation,
            child: Text(failure.openSettings ? 'Settings' : 'Retry'),
          ),
        ],
      ),
    );
  }

  /// The horizontal row of category filters above the list.
  Widget _buildCategoryChips() {
    return SizedBox(
      height: 56,
      child: ListView(
        // Horizontal so the six categories plus "All" scroll sideways instead
        // of wrapping onto a second row and eating vertical space.
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: <Widget>[
          _buildChip('All', null),
          for (final String category in eventCategories)
            _buildChip(category, category),
        ],
      ),
    );
  }

  /// One filter chip.
  ///
  /// Takes the label to show and the category it selects - null meaning "no
  /// filter". Gives back a FilterChip that knows whether it is the active one.
  Widget _buildChip(String label, String? category) {
    final bool isSelected = _selectedCategory == category;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: FilterChip(
          label: Text(label),
          selected: isSelected,
          // Tapping the already-selected chip clears the filter, which is what
          // people expect from a toggle.
          onSelected: (bool nowSelected) {
            setState(() => _selectedCategory = nowSelected ? category : null);
          },
        ),
      ),
    );
  }

  /// Screen width, in dp, at which the feed switches from a list to a grid.
  ///
  /// 600 is Material Design's line between a phone and a tablet. A phone held
  /// upright is roughly 360-420 wide, so it always gets the list.
  static const double _wideLayoutBreakpoint = 600;

  /// Chooses the list or the grid, depending on how much width there is.
  ///
  /// LayoutBuilder hands us the exact space this part of the screen has been
  /// given (the constraints) and lets us build something different for each
  /// size. It re-runs by itself when that space changes - turning a tablet,
  /// or dragging a browser window wider - so the switch happens live.
  Widget _buildResults(List<AppEvent> events) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _wideLayoutBreakpoint) {
          return _buildGrid(events);
        }
        return _buildList(events);
      },
    );
  }

  /// The single-column list of cards, for phones.
  ///
  /// ListView.builder creates cards only as they scroll into view, rather than
  /// building all of them up front. With eight events that hardly matters;
  /// with eight hundred it is the difference between a smooth list and a
  /// frozen one.
  Widget _buildList(List<AppEvent> events) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: events.length,
      itemBuilder: (context, index) => _buildCard(events[index]),
    );
  }

  /// The two-column grid of cards, for tablets and wide windows.
  ///
  /// On a wide screen a single column leaves each card stretched into a long
  /// thin strip with empty space either side. Two columns use the width and
  /// show twice as many events at once.
  ///
  /// GridView.builder is the grid version of ListView.builder: same lazy
  /// building, same card widget - only the arrangement changes.
  Widget _buildGrid(List<AppEvent> events) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        // A fixed height for every cell. A grid row must be one height, and
        // this fits the tallest card: photo, title, and all four info lines.
        mainAxisExtent: 330,
      ),
      itemCount: events.length,
      itemBuilder: (context, index) => _buildCard(events[index]),
    );
  }

  /// One event card, used by both the list and the grid.
  Widget _buildCard(AppEvent event) {
    final double? distance = _distanceTo(event);
    // The "discover-" prefix keeps this tag unique even when My Events shows
    // the same event in the other tab.
    final String heroTag = 'discover-${event.id}';

    return EventCard(
      event: event,
      distanceKm: distance,
      heroTag: heroTag,
      onTap: () => _openDetail(event, distance, heroTag),
    );
  }

  /// Opens the detail screen for one event.
  ///
  /// push() puts the new screen on top of this one; the back button pops it
  /// off again and we are back in the list exactly where we left it. The event
  /// is handed over through the constructor, which is how the detail screen
  /// knows what to show without asking the database.
  void _openDetail(AppEvent event, double? distance, String heroTag) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => EventDetailScreen(
          event: event,
          distanceKm: distance,
          heroTag: heroTag,
        ),
      ),
    );
  }

  /// Shown when the stream fails - usually no internet, or rules refusing.
  Widget _buildError() {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text('Could not load events', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Check your internet connection and try again.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Rebuilding the screen is enough to retry: the stream is still
            // connected underneath and Firebase reconnects by itself once the
            // network is back.
            FilledButton.tonal(
              onPressed: () => setState(() {}),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Shown when the load succeeded but there is nothing to list.
  Widget _buildEmpty() {
    final ThemeData theme = Theme.of(context);

    // The message changes depending on why it is empty, because "no events at
    // all" and "no Music events" need different advice.
    final String message = _selectedCategory == null
        ? 'No events yet. Be the first to post one from the Create tab.'
        : 'No $_selectedCategory events right now. Try another category.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.event_busy_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
