import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:city_events/event_detail_screen.dart';
import 'package:city_events/models/app_event.dart';
import 'package:city_events/notification_switches.dart';
import 'package:city_events/services/auth_service.dart';
import 'package:city_events/services/event_service.dart';

/// Tab 4: who you are, what you are going to, and the way out.
///
/// Stateful only so the live list of events you are attending can be created
/// once, in initState. The notification switches are their own widget.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // A one-off read of who is signed in. That is enough here: if this ever
  // became null the whole screen would already have been replaced, because
  // AuthGate is watching the same thing as a stream further up the tree.
  final User? _user = AuthService().currentUser;

  late final Stream<List<AppEvent>> _attendingStream;

  @override
  void initState() {
    super.initState();
    _attendingStream =
        EventService().streamAttendingEvents(_user?.uid ?? '');
  }

  /// Opens the detail page for an event you are going to.
  void _openDetail(AppEvent event) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) =>
            EventDetailScreen(event: event, heroTag: 'profile-${event.id}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildIdentity(theme),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          Text('Events I am going to', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          _buildAttending(theme),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          const NotificationSwitches(),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            // Nothing follows this call on purpose. Signing out makes the auth
            // stream emit null, AuthGate rebuilds, and the login screen takes
            // over. Navigating here as well would fight with that.
            onPressed: () => AuthService().signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  /// The avatar, name and email block at the top of the screen.
  Widget _buildIdentity(ThemeData theme) {
    // displayName was saved when the account was created, so we can show a
    // name without a database read. The ?? fallbacks mean a missing value
    // shows something sensible instead of the word "null".
    final String name = _user?.displayName ?? 'No name on file';
    final String email = _user?.email ?? '';

    return Column(
      children: <Widget>[
        CircleAvatar(
          radius: 36,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            // The first letter of the name, as a simple stand-in for a photo.
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(name, style: theme.textTheme.titleLarge),
        Text(email, style: theme.textTheme.bodyMedium),
      ],
    );
  }

  /// The live list of events you have said you are going to.
  ///
  /// Tap "I'm going" on any event and it appears here straight away, because
  /// this list comes from the same live stream as everything else.
  Widget _buildAttending(ThemeData theme) {
    return StreamBuilder<List<AppEvent>>(
      stream: _attendingStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const ListTile(
            leading: Icon(Icons.cloud_off),
            title: Text('Could not load your events.'),
          );
        }

        final List<AppEvent> events = snapshot.data ?? <AppEvent>[];
        if (events.isEmpty) {
          return ListTile(
            leading: const Icon(Icons.event_available_outlined),
            title: const Text('Nothing yet'),
            subtitle: Text(
              'Open any event and tap "I\'m going".',
              style: theme.textTheme.bodySmall,
            ),
          );
        }

        // A Column rather than a ListView: this sits inside the page's
        // ListView already, and a scrolling list inside a scrolling list
        // fights over who handles the swipe.
        return Column(
          children: events.map((AppEvent event) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available),
              title: Text(event.title),
              subtitle: Text(
                '${DateFormat('EEE d MMM, h:mm a').format(event.date)}'
                '  ·  ${event.venueName}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openDetail(event),
            );
          }).toList(),
        );
      },
    );
  }
}
