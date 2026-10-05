import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Push notifications, through Firebase Cloud Messaging (FCM).
///
/// The app never sends a notification - it only receives them. Sending
/// requires a secret server credential, and anything built into an app can be
/// extracted by whoever installs it. So messages are sent by hand from the
/// Firebase Console, which is the part of the system that is allowed to hold
/// that credential.
///
/// Delivery works by topic. Each event category has one, e.g.
/// "category_food". Switching Food on in Profile subscribes this phone to that
/// topic; a message sent to the topic reaches every subscribed phone.
///
/// Android only. Push on the web needs a service worker and an extra key,
/// which earns nothing for this app, so on web every method quietly does
/// nothing and the Profile screen hides the switches.
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// The "users" branch, where each user's token and choices are kept.
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('users');

  /// False in a web browser. Checked by every method before touching FCM.
  static bool get isSupported => !kIsWeb;

  /// The FCM topic name for a category, e.g. "Food" -> "category_food".
  ///
  /// Topic names must be plain letters, numbers and a few symbols, so the
  /// category is lower-cased and prefixed rather than used as it is.
  static String topicFor(String category) =>
      'category_${category.toLowerCase()}';

  /// Everything that has to happen once, after someone signs in.
  ///
  /// 1. Ask permission to show notifications - Android 13+ requires this at
  ///    runtime, like the location permission.
  /// 2. Save this phone's FCM token under the user, so a single device can be
  ///    targeted from the console when testing.
  /// 3. Re-subscribe to every category the user has switched on. FCM keeps
  ///    subscriptions on the phone, and they are lost if the app is
  ///    reinstalled; re-applying what the database says keeps the switches
  ///    and the real subscriptions in step.
  ///
  /// Any failure here is swallowed. Notifications are a bonus, and a problem
  /// with them must never stop the rest of the app from starting.
  Future<void> setUp(String uid) async {
    if (!isSupported || uid.isEmpty) return;

    try {
      await _messaging.requestPermission();

      final String? token = await _messaging.getToken();
      if (token != null) {
        await _usersRef.child(uid).child('fcmToken').set(token);
      }

      final Set<String> chosen = await _readChosenCategories(uid);
      for (final String category in chosen) {
        await _messaging.subscribeToTopic(topicFor(category));
      }
    } catch (error) {
      debugPrint('Notification set-up failed: $error');
    }
  }

  /// Messages that arrive while the app is open and on screen.
  ///
  /// This is the easy-to-miss part of FCM. When the app is closed or in the
  /// background, Android shows the notification by itself. When the app is in
  /// the foreground, Android shows nothing at all - the message is handed to
  /// the app through this stream, and it is up to the app to display it.
  Stream<RemoteMessage> get foregroundMessages => FirebaseMessaging.onMessage;

  /// Whether the user has allowed notifications for this app.
  ///
  /// Used by Profile to explain why nothing will arrive if they said no.
  Future<bool> isPermitted() async {
    if (!isSupported) return false;
    final NotificationSettings settings =
        await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// A live set of the categories this user has switched on.
  ///
  /// Stored as users/{uid}/notifyCategories/{category}: true. A category that
  /// is switched off is simply absent.
  Stream<Set<String>> streamChosenCategories(String uid) {
    return _usersRef
        .child(uid)
        .child('notifyCategories')
        .onValue
        .map((DatabaseEvent event) => _keysOf(event.snapshot.value));
  }

  /// Switches one category on or off, in both places that need to know.
  ///
  /// The database write is what the switch displays; the topic subscription
  /// is what actually delivers messages. Doing both keeps them in agreement.
  Future<void> setCategory({
    required String uid,
    required String category,
    required bool enabled,
  }) async {
    final DatabaseReference entry =
        _usersRef.child(uid).child('notifyCategories').child(category);

    if (enabled) {
      await entry.set(true);
      if (isSupported) await _messaging.subscribeToTopic(topicFor(category));
    } else {
      await entry.remove();
      if (isSupported) {
        await _messaging.unsubscribeFromTopic(topicFor(category));
      }
    }
  }

  /// A one-off read of the chosen categories, for re-subscribing at start-up.
  Future<Set<String>> _readChosenCategories(String uid) async {
    final DataSnapshot snapshot =
        await _usersRef.child(uid).child('notifyCategories').get();
    return _keysOf(snapshot.value);
  }

  /// Turns `{ "Food": true, "Music": true }` into `{"Food", "Music"}`.
  /// Firebase gives back null when the branch does not exist.
  static Set<String> _keysOf(Object? raw) {
    if (raw == null) return <String>{};
    return (raw as Map<Object?, Object?>)
        .keys
        .map((key) => key as String)
        .toSet();
  }
}
