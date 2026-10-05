import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:city_events/app_theme.dart';
import 'package:city_events/auth_gate.dart';
import 'package:city_events/firebase_options.dart';

/// The entry point of the whole application.
///
/// It is async because Firebase has to be connected before the app starts. No
/// Firebase call - signing in, reading the database - works until
/// initializeApp() has finished, so we wait for it here, once.
void main() async {
  // Flutter normally sets up its engine bindings inside runApp(). Because we
  // want to use a plugin before runApp(), we have to set them up ourselves
  // first, or the call below has nothing to talk to.
  WidgetsFlutterBinding.ensureInitialized();

  // DefaultFirebaseOptions.currentPlatform picks the right set of identifiers
  // for whatever we are running on - the Android app or the web app - from the
  // firebase_options.dart file the FlutterFire CLI generated.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const CityEventsApp());
}

/// The root widget of CityEvents.
///
/// Its only job is to configure MaterialApp: the app title, the light and dark
/// themes, and which screen to show first. It is a StatelessWidget because
/// nothing here ever changes while the app is running.
class CityEventsApp extends StatelessWidget {
  const CityEventsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CityEvents',

      // Hides the red "DEBUG" ribbon in the corner. Purely so screenshots for
      // the report look like a finished app.
      debugShowCheckedModeBanner: false,

      // We hand MaterialApp both themes and let it choose. ThemeMode.system
      // means "follow whatever the phone is set to" - so when the user turns
      // on dark mode in Android settings, the app switches with no toggle and
      // no code of ours running.
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,

      // Not a fixed screen: AuthGate works out whether to show the login screen
      // or the app, and keeps watching in case that changes.
      home: const AuthGate(),
    );
  }
}
