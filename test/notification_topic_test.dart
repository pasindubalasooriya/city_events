// Tests for how event categories become FCM topic names.
//
// Topic names must be exactly what the Firebase Console is told to send to,
// so a mistake here would mean notifications silently going nowhere.

import 'package:flutter_test/flutter_test.dart';

import 'package:city_events/models/app_event.dart';
import 'package:city_events/services/notification_service.dart';

void main() {
  test('category names become lower-case topics with a prefix', () {
    expect(NotificationService.topicFor('Food'), 'category_food');
    expect(NotificationService.topicFor('Community'), 'category_community');
  });

  test('every category produces a valid FCM topic name', () {
    // FCM allows letters, numbers and - _ . ~ % only.
    final RegExp allowed = RegExp(r'^[a-zA-Z0-9\-_.~%]+$');
    for (final String category in eventCategories) {
      expect(allowed.hasMatch(NotificationService.topicFor(category)), isTrue,
          reason: 'bad topic for $category');
    }
  });
}
