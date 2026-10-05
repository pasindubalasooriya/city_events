import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:city_events/models/app_event.dart';
import 'package:city_events/services/auth_service.dart';
import 'package:city_events/services/notification_service.dart';

/// The "Notify me about" switches on the Profile screen.
///
/// One switch per event category. Each switch shows what the database says
/// and, when flipped, updates both the database and the real FCM topic
/// subscription. Its own widget so its live connection sits apart from the
/// Profile screen's other list.
class NotificationSwitches extends StatefulWidget {
  const NotificationSwitches({super.key});

  @override
  State<NotificationSwitches> createState() => _NotificationSwitchesState();
}

class _NotificationSwitchesState extends State<NotificationSwitches> {
  final NotificationService _service = NotificationService();
  final String _uid = AuthService().currentUser?.uid ?? '';

  late final Stream<Set<String>> _chosenStream;

  /// Null until we have checked. False means the user refused permission, so
  /// nothing they switch on here would ever arrive.
  bool? _permitted;

  @override
  void initState() {
    super.initState();
    _chosenStream = _service.streamChosenCategories(_uid);
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final bool permitted = await _service.isPermitted();
    if (!mounted) return;
    setState(() => _permitted = permitted);
  }

  /// Saves one switch. The switch itself redraws from the stream once the
  /// database has changed, the same way the RSVP button does.
  Future<void> _toggle(String category, bool enabled) async {
    try {
      await _service.setCategory(
        uid: _uid,
        category: category,
        enabled: enabled,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update that setting.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    // In a browser there are no push notifications, so rather than show
    // switches that do nothing, say so plainly.
    if (!NotificationService.isSupported) {
      return ListTile(
        leading: const Icon(Icons.notifications_off_outlined),
        title: const Text('Notifications'),
        subtitle: Text(
          'Available in the Android app.',
          style: theme.textTheme.bodySmall,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Notify me about new', style: theme.textTheme.titleMedium),
        if (_permitted == false) _buildPermissionWarning(theme),
        StreamBuilder<Set<String>>(
          stream: _chosenStream,
          builder: (context, snapshot) {
            // Until the first answer arrives, treat everything as off rather
            // than show a spinner in the middle of the page.
            final Set<String> chosen = snapshot.data ?? <String>{};

            return Column(
              children: eventCategories.map((String category) {
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('$category events'),
                  value: chosen.contains(category),
                  onChanged: (bool enabled) => _toggle(category, enabled),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  /// Shown when notifications are blocked for this app. Without it the user
  /// could switch categories on and wonder why nothing ever arrives.
  Widget _buildPermissionWarning(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.notifications_off_outlined,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Notifications are turned off for CityEvents, so none will '
              'arrive.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          TextButton(
            // The app's page in system settings, where notifications can be
            // switched back on. Geolocator already provides this shortcut.
            onPressed: Geolocator.openAppSettings,
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }
}
