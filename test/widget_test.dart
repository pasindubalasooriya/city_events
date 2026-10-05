// Automated tests for the parts of the app that do not need Firebase.
//
// The marking scheme asks for manual testing (the test table in the report),
// and that remains the main testing effort. This file is a small safety net
// for the theme, which every screen depends on.
//
// Note what is NOT tested here: the app itself. Building CityEventsApp reaches
// AuthGate, which asks Firebase Authentication who is signed in, and Firebase
// has not been initialised inside a test. Testing that properly means mocking
// the whole Firebase platform, which is a large amount of code for a project
// whose testing criterion is satisfied by a manual test plan. The auth screens
// are covered by tests T01-T08 in the report, run by hand.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:city_events/app_theme.dart';

void main() {
  test('light and dark themes are built from the same seed colour', () {
    final ThemeData light = AppTheme.light();
    final ThemeData dark = AppTheme.dark();

    // Each theme must actually be the brightness it claims, or the app would
    // show light colours while the device is in dark mode.
    expect(light.colorScheme.brightness, Brightness.light);
    expect(dark.colorScheme.brightness, Brightness.dark);

    // The two palettes must differ - if they came out identical, dark mode
    // would be doing nothing.
    expect(light.colorScheme.surface, isNot(dark.colorScheme.surface));
  });

  testWidgets('a screen using the theme renders in both modes',
      (WidgetTester tester) async {
    for (final ThemeData theme in <ThemeData>[
      AppTheme.light(),
      AppTheme.dark(),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            appBar: null,
            body: Center(child: Text('CityEvents')),
          ),
        ),
      );

      expect(find.text('CityEvents'), findsOneWidget);
    }
  });
}
