/// One event, as the app understands it.
///
/// Firebase hands back plain nested Maps, not Dart objects. This class is the
/// translation layer in both directions: [AppEvent.fromMap] turns a Firebase
/// record into something type-safe, and [toMap] turns it back for saving.
/// Everything is final, so an event object cannot be changed after it is
/// created - to change an event we build a new one and save that.
class AppEvent {
  /// The Firebase key for this event, e.g. "-Oa1b2c3d4".
  ///
  /// It is not stored inside the record itself - it is the name of the branch
  /// the record sits under - so fromMap takes it separately. We need it to
  /// know which event to update or delete later.
  final String id;

  final String title;
  final String description;

  /// One of [eventCategories].
  final String category;

  /// A Cloudinary delivery URL, already carrying the w_800,q_auto,f_auto
  /// transformation so the phone downloads a resized, compressed copy.
  final String imageUrl;

  final String venueName;

  /// When the event happens, as milliseconds since 1 January 1970.
  ///
  /// Stored as a plain integer rather than a formatted string because integers
  /// sort correctly and mean the same thing in every timezone and locale.
  /// Use [date] to get something printable.
  final int dateTime;

  final double lat;
  final double lng;

  /// Whether it happens outdoors. Used by the detail screen to decide whether
  /// the weather forecast is worth showing prominently.
  final bool isOutdoor;

  /// Who created it. The security rules compare this against the signed-in
  /// user's uid to decide whether editing and deleting are allowed.
  final String ownerUid;
  final String ownerName;

  final int createdAt;

  /// The uids of everyone who has said they are going.
  ///
  /// Stored inside the event as `attendees: { uid: true, uid: true }`, so the
  /// count arrives in the same live stream as the event itself. A Set, because
  /// each person can only be going once.
  final Set<String> attendees;

  const AppEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.imageUrl,
    required this.venueName,
    required this.dateTime,
    required this.lat,
    required this.lng,
    required this.isOutdoor,
    required this.ownerUid,
    required this.ownerName,
    required this.createdAt,
    this.attendees = const <String>{},
  });

  /// How many people are going.
  int get attendeeCount => attendees.length;

  /// Whether one particular user has said they are going.
  bool isAttending(String uid) => attendees.contains(uid);

  /// The event date as a DateTime, for formatting and comparing.
  DateTime get date => DateTime.fromMillisecondsSinceEpoch(dateTime);

  /// Builds an AppEvent from one Firebase record.
  ///
  /// Takes the Firebase key and the raw map stored under it. Every field has a
  /// fallback, because a record written by an older version of the app - or by
  /// hand in the console - might be missing something, and a missing field
  /// should give us an odd-looking event rather than a crash.
  factory AppEvent.fromMap(String id, Map<Object?, Object?> map) {
    return AppEvent(
      id: id,
      title: map['title'] as String? ?? 'Untitled event',
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? 'Other',
      imageUrl: map['imageUrl'] as String? ?? '',
      venueName: map['venueName'] as String? ?? '',
      // Firebase gives whole numbers back as int, but a value typed by hand in
      // the console can arrive as a double. num covers both.
      dateTime: (map['dateTime'] as num?)?.toInt() ?? 0,
      lat: (map['lat'] as num?)?.toDouble() ?? 0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0,
      isOutdoor: map['isOutdoor'] as bool? ?? false,
      ownerUid: map['ownerUid'] as String? ?? '',
      ownerName: map['ownerName'] as String? ?? 'Unknown',
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
      // Stored as { "uid1": true, "uid2": true }. We only need the keys. An
      // event nobody has joined has no attendees branch at all, because
      // Firebase does not keep empty branches - hence the fallback.
      attendees: (map['attendees'] as Map<Object?, Object?>?)
              ?.keys
              .map((key) => key as String)
              .toSet() ??
          <String>{},
    );
  }

  /// Turns this event into the map Firebase stores.
  ///
  /// The id is deliberately left out - it is the branch name, not part of the
  /// record, and writing it inside would duplicate it.
  ///
  /// The attendees are left out too, on purpose. They are written one at a
  /// time by the RSVP button, never by the form. Because editing uses
  /// update(), which only touches the fields sent, saving an edit leaves
  /// everyone's RSVPs exactly as they were.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'title': title,
      'description': description,
      'category': category,
      'imageUrl': imageUrl,
      'venueName': venueName,
      'dateTime': dateTime,
      'lat': lat,
      'lng': lng,
      'isOutdoor': isOutdoor,
      'ownerUid': ownerUid,
      'ownerName': ownerName,
      'createdAt': createdAt,
    };
  }
}

/// The fixed set of categories an event can belong to.
///
/// A fixed list rather than free text, so the Discover filter chips and the
/// create form's dropdown always agree, and so no event can be filed under a
/// category nothing else uses.
const List<String> eventCategories = <String>[
  'Music',
  'Sports',
  'Tech',
  'Food',
  'Community',
  'Other',
];

/// The default photo used for a new event in each category.
///
/// The app has no image upload - the brief's Option B is to host images
/// elsewhere and store the URL - so a new event gets the stock photo for its
/// category. Picking a category on the form therefore also picks the picture.
///
/// Every URL carries `w_800,q_auto,f_auto`, which makes Cloudinary resize and
/// compress the image as it is delivered. The originals are several megabytes;
/// what the phone actually downloads is about 50 KB.
const Map<String, String> categoryImages = <String, String>{
  'Music':
      'https://res.cloudinary.com/dnsdebfir/image/upload/w_800,q_auto,f_auto/v1790404139/music_1_etb3kh.jpg',
  'Sports':
      'https://res.cloudinary.com/dnsdebfir/image/upload/w_800,q_auto,f_auto/v1790429909/sports_1_djiftt.jpg',
  'Tech':
      'https://res.cloudinary.com/dnsdebfir/image/upload/w_800,q_auto,f_auto/v1790404108/tech_1_x5ymuc.jpg',
  'Food':
      'https://res.cloudinary.com/dnsdebfir/image/upload/w_800,q_auto,f_auto/v1790404137/food_1_vbdxoy.jpg',
  'Community':
      'https://res.cloudinary.com/dnsdebfir/image/upload/w_800,q_auto,f_auto/v1790404126/community_1_ooux7n.jpg',
  'Other':
      'https://res.cloudinary.com/dnsdebfir/image/upload/w_800,q_auto,f_auto/v1790404125/other_1_jitlie.jpg',
};
