import 'package:firebase_database/firebase_database.dart';

import 'package:city_events/models/app_event.dart';

/// Everything the app does with events in the Realtime Database.
///
/// Phase 4 only needs reading. Create, update and delete join this class in
/// Phases 5 and 7, so all four CRUD operations end up in one short file.
class EventService {
  /// A pointer to the "events" branch. Creating it fetches nothing - it is
  /// just an address.
  final DatabaseReference _eventsRef = FirebaseDatabase.instance.ref('events');

  /// A live list of every event, soonest first.
  ///
  /// onValue is a stream: it fires once with everything currently there, and
  /// again every single time anything under /events changes. That is what
  /// makes the feed update by itself when somebody else posts an event - no
  /// pull-to-refresh, no polling.
  ///
  /// The alternative, get(), reads once and stops listening. We would then
  /// have to guess when to re-read.
  Stream<List<AppEvent>> streamAllEvents() {
    return _eventsRef.onValue.map((DatabaseEvent event) {
      final Object? raw = event.snapshot.value;

      // Firebase does not keep empty branches. If no events exist, /events is
      // absent entirely and the value is null - not an empty map.
      if (raw == null) return <AppEvent>[];

      // The shape is { "-Oa1b2...": { title: ..., ... }, "-Oa1b3...": {...} }
      final Map<Object?, Object?> all = raw as Map<Object?, Object?>;

      final List<AppEvent> events = all.entries.map((entry) {
        return AppEvent.fromMap(
          entry.key as String,
          entry.value as Map<Object?, Object?>,
        );
      }).toList();

      // Sorted here in Dart rather than by Firebase. Firebase can only order
      // by one child key and always ascending, and from Phase 5 we re-sort
      // this list by distance from the user, which Firebase cannot do at all
      // because it does not know where the user is.
      events.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      return events;
    });
  }

  /// Saves a brand new event.
  ///
  /// push() asks Firebase for a fresh unique key and set() writes the record
  /// underneath it. The pair is the standard way to add to a list in the
  /// Realtime Database.
  ///
  /// Why push() and not set() at a key we choose: an event has no natural id,
  /// and two people creating an event at the same moment must not collide.
  /// push() keys are also ordered by creation time, so they sort sensibly.
  ///
  /// Nothing is returned. The feed is already listening through onValue, so
  /// the new event appears by itself - on this device and on everyone else's.
  Future<void> createEvent(AppEvent event) async {
    await _eventsRef.push().set(event.toMap());
  }

  /// A live list of only the events one user created.
  ///
  /// Built from the same stream as the full feed, keeping events whose
  /// ownerUid matches. Filtering here in Dart keeps this to one line. The
  /// alternative - asking Firebase for only matching records with
  /// orderByChild('ownerUid').equalTo(uid) - downloads less, but needs an extra
  /// index rule, and with a few dozen events the saving is not worth it.
  Stream<List<AppEvent>> streamMyEvents(String uid) {
    return streamAllEvents().map(
      (List<AppEvent> events) =>
          events.where((e) => e.ownerUid == uid).toList(),
    );
  }

  /// A live list of the events one user has said they are going to.
  ///
  /// Also built from the full stream, because attendance is stored inside each
  /// event - so there is still only one Firebase listener behind it.
  Stream<List<AppEvent>> streamAttendingEvents(String uid) {
    return streamAllEvents().map(
      (List<AppEvent> events) =>
          events.where((e) => e.isAttending(uid)).toList(),
    );
  }

  /// A live view of one single event, or null once it has been deleted.
  ///
  /// The detail screen receives a copy of the event when it opens, and that
  /// copy never changes. This stream is what lets the RSVP count on that
  /// screen move when somebody else joins, while you are looking at it.
  Stream<AppEvent?> streamEvent(String id) {
    return _eventsRef.child(id).onValue.map((DatabaseEvent event) {
      final Object? raw = event.snapshot.value;
      if (raw == null) return null;
      return AppEvent.fromMap(id, raw as Map<Object?, Object?>);
    });
  }

  /// Records that a user is, or is no longer, going to an event.
  ///
  /// Going writes `attendees/<uid>: true`; not going removes that entry. Only
  /// that one small branch is touched, never the rest of the event - which is
  /// also all the security rules allow a non-owner to write.
  Future<void> setAttending({
    required String eventId,
    required String uid,
    required bool going,
  }) async {
    final DatabaseReference entry =
        _eventsRef.child(eventId).child('attendees').child(uid);

    if (going) {
      await entry.set(true);
    } else {
      await entry.remove();
    }
  }

  /// Saves changes to an existing event.
  ///
  /// child(id) points at the one event; update() changes only the fields in
  /// the map and leaves anything else under that event untouched. set() would
  /// replace the whole record instead, wiping any field we forgot to send.
  ///
  /// The security rules only allow this if you are the event's owner.
  Future<void> updateEvent(AppEvent event) async {
    await _eventsRef.child(event.id).update(event.toMap());
  }

  /// Deletes an event permanently.
  ///
  /// remove() deletes the event's branch and everything under it. There is no
  /// undo, which is why the screen asks for confirmation before calling this.
  /// The security rules only allow it if you are the event's owner.
  Future<void> deleteEvent(String id) async {
    await _eventsRef.child(id).remove();
  }
}
