import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Raised when we cannot get a location, carrying a message fit to show the
/// user.
///
/// There are several distinct reasons GPS can fail, and the user can act on
/// each one differently - turn location on, grant the permission, or open
/// settings. Wrapping them in one type means screens catch one thing and show
/// [message], rather than each screen re-writing the same explanations.
class LocationFailure implements Exception {
  final String message;

  /// True when the user chose "Don't allow" permanently. Asking again does
  /// nothing in that case - Android silently refuses - so the UI offers a
  /// button to the system settings screen instead of a pointless Retry.
  final bool openSettings;

  const LocationFailure(this.message, {this.openSettings = false});
}

/// The GPS sensor.
///
/// Two jobs: getting where the user is now (for tagging a new event and for
/// sorting the feed), and measuring how far apart two points are.
class LocationService {
  /// Gets the device's current position.
  ///
  /// Walks the whole permission flow in order, because each step can fail for
  /// a different reason. Throws [LocationFailure] with an explanation the UI
  /// can show directly; never returns null and never crashes the caller.
  Future<Position> getCurrentPosition() async {
    // Step 1: is location switched on for the whole device? Permission is
    // irrelevant if the phone's location toggle is off - we would just sit
    // waiting for a fix that never comes.
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationFailure(
        'Location is turned off on this device. Switch it on and try again.',
      );
    }

    // Step 2: what permission do we currently hold?
    LocationPermission permission = await Geolocator.checkPermission();

    // Step 3: if we have not asked yet, ask now. This is what shows the
    // Android system dialog. Declaring the permission in AndroidManifest.xml
    // is not enough on its own - from Android 6 the user must agree at
    // runtime, every install.
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // Step 4: denied for this session. The user said no, but may say yes if
    // asked again later, so a Retry button is worth offering.
    if (permission == LocationPermission.denied) {
      throw const LocationFailure(
        'Location permission was denied, so events cannot be sorted by '
        'distance.',
      );
    }

    // Step 5: denied permanently. Android will no longer show the dialog at
    // all, so asking again is useless - the only route is the settings screen.
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        'Location permission is permanently denied. You can turn it back on '
        'in system settings.',
        openSettings: true,
      );
    }

    // Step 6: permission granted, so actually read the sensor. medium accuracy
    // is plenty for "how far away is this event" and gets a fix faster than
    // best, which matters because the user is waiting.
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          // Give up rather than hang forever if the device cannot get a fix -
          // indoors, or on an emulator with no location set.
          timeLimit: Duration(seconds: 20),
        ),
      );
    } on TimeoutException {
      // Step 7: no fresh fix arrived in time. The phone may still remember
      // where it was a few minutes ago, which is good enough for "how far is
      // this event". Only if there is nothing at all do we give up.
      final Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) return lastKnown;

      throw const LocationFailure(
        'Could not get a GPS fix. Try again, ideally outdoors or near a window.',
      );
    }
  }

  /// Opens the system settings page for this app, so the user can re-enable a
  /// permanently denied permission.
  Future<void> openSettings() => Geolocator.openAppSettings();

  /// The straight-line distance between two points, in kilometres.
  ///
  /// Geolocator does the maths with the Haversine formula, which accounts for
  /// the curvature of the earth. It returns metres, so we divide. This is
  /// "as the crow flies", not driving distance - fine for "how close is this
  /// event to me", which is all the feed needs.
  static double distanceInKm(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    final double metres = Geolocator.distanceBetween(
      startLat,
      startLng,
      endLat,
      endLng,
    );
    return metres / 1000;
  }

  /// Turns a distance in kilometres into short, readable text.
  ///
  /// Lives here so the event card and the detail screen word distances the
  /// same way, instead of each keeping its own copy.
  static String describeDistance(double km) {
    // Within 50 metres you are effectively at the venue. "0 m away" is
    // accurate but reads like a broken calculation, so say it in words.
    if (km < 0.05) return "You're here";
    // Under a kilometre reads better in metres, and nobody needs decimals for
    // "how far is this event".
    if (km < 1) return '${(km * 1000).round()} m away';
    if (km < 10) return '${km.toStringAsFixed(1)} km away';
    return '${km.round()} km away';
  }
}
