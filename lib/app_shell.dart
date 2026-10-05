import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'package:city_events/discover_screen.dart';
import 'package:city_events/event_form_screen.dart';
import 'package:city_events/my_events_screen.dart';
import 'package:city_events/profile_screen.dart';
import 'package:city_events/services/auth_service.dart';
import 'package:city_events/services/notification_service.dart';

/// The signed-in app: four tabs and the bar (or rail) that switches between
/// them.
///
/// This is what AuthGate shows once somebody is signed in. It owns which tab
/// is selected, and - because it stays on screen the whole time someone is
/// signed in - it is also where push notifications are set up and where
/// messages arriving while the app is open get shown.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// Which tab is showing. 0 is Discover, matching the order of _tabs below.
  int _selectedIndex = 0;

  final NotificationService _notificationService = NotificationService();

  /// Our connection to the stream of foreground messages.
  ///
  /// Kept so it can be cancelled in dispose(). A subscription left open after
  /// its screen is gone keeps running and keeps calling a dead widget - the
  /// stream equivalent of forgetting to dispose a controller.
  StreamSubscription<RemoteMessage>? _messageSubscription;

  /// The four screens, built once and kept alive by the IndexedStack.
  ///
  /// This can be `static const` because none of the four takes a required
  /// argument. `const` means Flutter creates these widget objects a single
  /// time for the whole program rather than on every rebuild.
  static const List<Widget> _tabs = <Widget>[
    DiscoverScreen(),
    MyEventsScreen(),
    EventFormScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();

    if (NotificationService.isSupported) {
      final String uid = AuthService().currentUser?.uid ?? '';
      // Not awaited: asking for permission and saving the token should not
      // hold up the app appearing. It finishes in the background.
      _notificationService.setUp(uid);
      _messageSubscription =
          _notificationService.foregroundMessages.listen(_showMessage);
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  /// Shows a push notification that arrived while the app was open.
  ///
  /// Android does not do this for us in the foreground, so without this the
  /// message would silently vanish. A SnackBar is enough: short, visible, and
  /// gone by itself.
  void _showMessage(RemoteMessage message) {
    final String title = message.notification?.title ?? 'CityEvents';
    final String body = message.notification?.body ?? '';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Row(
          children: <Widget>[
            const Icon(Icons.notifications_active_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(body.isEmpty ? title : '$title\n$body'),
            ),
          ],
        ),
      ),
    );
  }

  /// Switches tab. Called with the index of whichever bar item was tapped.
  ///
  /// setState is what tells Flutter the value changed and the screen needs
  /// rebuilding - changing _selectedIndex on its own would do nothing visible.
  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  /// Width, in dp, at which the bottom bar becomes a side rail. The same
  /// phone/tablet line Discover uses for its grid.
  static const double _railBreakpoint = 600;

  @override
  Widget build(BuildContext context) {
    // MediaQuery gives the size of the whole screen. That is the right
    // question here because AppShell always fills the whole screen. (Discover
    // uses LayoutBuilder instead, because it cares about the space left for
    // its list, not the screen.)
    final bool isWide = MediaQuery.sizeOf(context).width >= _railBreakpoint;

    return Scaffold(
      // On a wide screen - a tablet, or a phone turned sideways - a bar along
      // the bottom wastes height, which is the one thing a sideways phone is
      // short of. So the tabs move to a rail down the left side instead.
      body: Row(
        children: <Widget>[
          if (isWide) _buildRail(),
          if (isWide) const VerticalDivider(width: 1),
          // Deliberately the LAST child of the Row. When the rail appears or
          // disappears, Flutter matches old and new children from both ends
          // of the list, and finds this one unchanged at the end. So the
          // IndexedStack - and every tab's scroll position, filter and
          // half-typed form - survives turning the phone.
          //
          // IndexedStack builds all four children and shows only the one at
          // [index]. The other three stay alive off-screen, so their state
          // survives a tab switch as well.
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _tabs,
            ),
          ),
        ],
      ),
      // null means "no bottom bar" - the rail is doing that job.
      bottomNavigationBar: isWide ? null : _buildBottomBar(),
    );
  }

  /// The bar along the bottom, for phones held upright.
  ///
  /// NavigationBar is Material 3's bottom navigation bar - the successor to
  /// BottomNavigationBar, which is the Material 2 version. Same idea: a fixed
  /// bar, four destinations, one always selected.
  Widget _buildBottomBar() {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onDestinationSelected,
      destinations: const <NavigationDestination>[
        // Each destination has an outlined icon for when it is not selected
        // and a filled one for when it is. That contrast is what makes the
        // current tab obvious at a glance.
        NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          selectedIcon: Icon(Icons.explore),
          label: 'Discover',
        ),
        NavigationDestination(
          icon: Icon(Icons.event_note_outlined),
          selectedIcon: Icon(Icons.event_note),
          label: 'My Events',
        ),
        NavigationDestination(
          icon: Icon(Icons.add_circle_outline),
          selectedIcon: Icon(Icons.add_circle),
          label: 'Create',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }

  /// The rail down the left side, for tablets and sideways phones.
  ///
  /// Material's partner to NavigationBar: the same four tabs, the same
  /// _selectedIndex and the same _onDestinationSelected, so switching between
  /// the two never loses which tab you were on.
  Widget _buildRail() {
    // SafeArea keeps the rail clear of the status bar and camera cutout,
    // because this Scaffold has no app bar above it to do that.
    return SafeArea(
      right: false,
      child: NavigationRail(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        // Show the words under every icon, not just the selected one.
        labelType: NavigationRailLabelType.all,
        // Centres the four tabs vertically, where a thumb reaches them.
        groupAlignment: 0,
        destinations: const <NavigationRailDestination>[
          NavigationRailDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: Text('Discover'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: Text('My Events'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: Text('Create'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: Text('Profile'),
          ),
        ],
      ),
    );
  }
}
