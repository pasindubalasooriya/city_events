import 'package:flutter/material.dart';

import 'package:city_events/event_card.dart';
import 'package:city_events/event_detail_screen.dart';
import 'package:city_events/event_form_screen.dart';
import 'package:city_events/models/app_event.dart';
import 'package:city_events/services/auth_service.dart';
import 'package:city_events/services/event_service.dart';

/// Tab 2: the events this user created, with Edit and Delete.
///
/// This is where the Update and Delete halves of CRUD happen through the UI.
/// Only your own events are listed here, and the security rules back that up:
/// even if someone forced an edit on another person's event, Firebase would
/// refuse it.
class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  final EventService _eventService = EventService();

  /// Created once, for the same reason as on Discover: build() can run many
  /// times, and a new stream each time would restart the Firebase listener.
  late final Stream<List<AppEvent>> _myEventsStream;

  @override
  void initState() {
    super.initState();
    final String uid = AuthService().currentUser?.uid ?? '';
    _myEventsStream = _eventService.streamMyEvents(uid);
  }

  /// Opens the form with this event already filled in.
  void _edit(AppEvent event) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => EventFormScreen(existingEvent: event),
      ),
    );
  }

  /// Opens the full detail page, the same one Discover uses.
  void _openDetail(AppEvent event, String heroTag) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) =>
            EventDetailScreen(event: event, heroTag: heroTag),
      ),
    );
  }

  /// Asks for confirmation, then deletes.
  ///
  /// Deleting cannot be undone, so it never happens on a single tap.
  /// showDialog returns whatever the dialog passes to Navigator.pop - true for
  /// Delete, false for Cancel - and null if the user taps outside it. Only a
  /// definite true goes ahead.
  Future<void> _confirmDelete(AppEvent event) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('Delete this event?'),
        content: Text(
          '"${event.title}" will be removed for everyone. This cannot be '
          'undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            // The error colour marks this as the destructive choice.
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _eventService.deleteEvent(event.id);
      if (!mounted) return;
      // No need to remove it from the list ourselves: the stream notices the
      // deletion and rebuilds the list without it.
      _showMessage('Event deleted.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not delete the event. Please try again.');
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Events')),
      body: StreamBuilder<List<AppEvent>>(
        stream: _myEventsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildMessage(
              Icons.cloud_off,
              'Could not load your events. Check your connection.',
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<AppEvent> events = snapshot.data ?? <AppEvent>[];
          if (events.isEmpty) {
            return _buildMessage(
              Icons.event_note_outlined,
              'You have not posted any events yet. Use the Create tab to '
              'post one.',
            );
          }
          return _buildList(events);
        },
      ),
    );
  }

  /// The list of your events, each with Edit and Delete underneath.
  Widget _buildList(List<AppEvent> events) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final AppEvent event = events[index];
        // "mine-" keeps this tag different from the same event's card on
        // Discover, which is alive in the other tab at the same time.
        final String heroTag = 'mine-${event.id}';

        return EventCard(
          event: event,
          heroTag: heroTag,
          onTap: () => _openDetail(event, heroTag),
          footer: _buildActions(event),
        );
      },
    );
  }

  /// The Edit and Delete buttons along the bottom of a card.
  Widget _buildActions(AppEvent event) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          TextButton.icon(
            onPressed: () => _edit(event),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit'),
          ),
          TextButton.icon(
            onPressed: () => _confirmDelete(event),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  /// A centred icon and sentence, for the empty and error states.
  Widget _buildMessage(IconData icon, String text) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              text,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
