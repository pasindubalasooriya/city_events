import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:city_events/app_shell.dart';
import 'package:city_events/login_screen.dart';
import 'package:city_events/services/auth_service.dart';

/// Decides whether to show the login screen or the app.
///
/// This is the only place in CityEvents that makes that decision. It listens
/// to the authentication stream, so signing in or out anywhere in the app
/// changes what is on screen here, with no navigation code needed. It is also
/// why the app remembers you after a restart: Firebase restores the previous
/// session and the stream reports it.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // The stream of "who is signed in", which fires on every change.
      stream: AuthService().authStateChanges(),
      builder: (context, snapshot) {
        // The snapshot is a small parcel describing the stream right now:
        // whether it is still connecting, and what the latest value was.

        // While Firebase is restoring the saved session we know nothing yet.
        // Showing a spinner here avoids the login screen flashing up for a
        // moment in front of a user who is already signed in.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // A value of null means nobody is signed in.
        final User? user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        return const AppShell();
      },
    );
  }
}
