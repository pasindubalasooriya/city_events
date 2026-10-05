import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import 'package:city_events/models/app_event.dart';
import 'package:city_events/services/auth_service.dart';
import 'package:city_events/services/event_service.dart';
import 'package:city_events/services/location_service.dart';

/// The form for posting an event, and for editing one.
///
/// One screen does both jobs. With no [existingEvent] it is the Create tab: it
/// starts empty, saves with push(), and clears itself afterwards. Given an
/// [existingEvent] it is opened from My Events: it starts filled in, saves
/// with update(), and closes itself afterwards. Two near-identical screens
/// would mean every future change to the form has to be made twice.
///
/// Five kinds of input, which is what criterion 5 asks for: text fields, a
/// dropdown, a date picker, a switch, and the GPS button.
class EventFormScreen extends StatefulWidget {
  /// The event being edited, or null when creating a new one.
  final AppEvent? existingEvent;

  const EventFormScreen({super.key, this.existingEvent});

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _venueController = TextEditingController();

  final EventService _eventService = EventService();
  final LocationService _locationService = LocationService();

  // The values that are not typed into a text field, so each needs its own
  // piece of state rather than a controller.
  String _category = eventCategories.first;
  DateTime? _dateTime;
  bool _isOutdoor = true;
  double? _lat;
  double? _lng;

  bool _isSaving = false;
  bool _isGettingLocation = false;

  /// True when editing rather than creating. Used to change the wording and
  /// what happens on save.
  bool get _isEditing => widget.existingEvent != null;

  @override
  void initState() {
    super.initState();

    // When editing, start every field with the event's current values.
    // initState is the right place: it runs once, before the first build, so
    // the fields are filled before the user ever sees them.
    final AppEvent? event = widget.existingEvent;
    if (event != null) {
      _titleController.text = event.title;
      _descriptionController.text = event.description;
      _venueController.text = event.venueName;
      _category = event.category;
      _dateTime = event.date;
      _isOutdoor = event.isOutdoor;
      _lat = event.lat;
      _lng = event.lng;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    super.dispose();
  }

  /// Asks for a date, then a time, and combines them.
  ///
  /// Two pickers because Flutter has no single date-and-time picker. Each
  /// returns null if the user backs out, which has to be checked before
  /// showing the next one.
  Future<void> _pickDateTime() async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    // The picker insists the starting date is not before the first allowed
    // date. An event being edited might already be in the past, so allow back
    // to that date rather than crash.
    final DateTime firstDate =
        (_dateTime != null && _dateTime!.isBefore(today)) ? _dateTime! : today;

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _dateTime ?? now.add(const Duration(days: 1)),
      firstDate: firstDate,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;

    // Checked after every await: the user can leave the screen while a picker
    // is open, and touching context afterwards would throw.
    if (!mounted) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime ?? now),
    );
    if (time == null) return;
    if (!mounted) return;

    setState(() {
      _dateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  /// Reads the GPS and stores the coordinates on the form.
  ///
  /// Every failure path arrives as a LocationFailure carrying a message we can
  /// show as-is. The brief requires permission denial to be handled
  /// gracefully, so nothing here throws at the user - worst case they get an
  /// explanation and, if the permission is permanently denied, a way to fix it.
  Future<void> _useCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      final Position position = await _locationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
      });
    } on LocationFailure catch (failure) {
      if (!mounted) return;
      _showLocationProblem(failure);
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  /// Explains a location problem, offering system settings when that is the
  /// only thing that will help.
  void _showLocationProblem(LocationFailure failure) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failure.message),
        duration: const Duration(seconds: 6),
        action: failure.openSettings
            ? SnackBarAction(
                label: 'Settings',
                onPressed: _locationService.openSettings,
              )
            : null,
      ),
    );
  }

  /// Picks the photo for the event being saved.
  ///
  /// A new event gets its category's stock photo. An edited event keeps the
  /// photo it already had - some of the seeded events have their own - unless
  /// the category was changed, in which case the old photo would no longer
  /// match and the new category's photo is used instead.
  String _chooseImageUrl() {
    final AppEvent? existing = widget.existingEvent;
    if (existing != null && existing.category == _category) {
      return existing.imageUrl;
    }
    return categoryImages[_category]!;
  }

  /// Validates everything, then writes the event to Firebase.
  Future<void> _save() async {
    // Runs every field validator. Stops here if any failed, so nothing
    // half-filled ever reaches the network.
    if (!_formKey.currentState!.validate()) return;

    // The date and the location are not text fields, so the Form cannot
    // validate them. They are checked by hand.
    if (_dateTime == null) {
      _showMessage('Please choose a date and time.');
      return;
    }
    if (_lat == null || _lng == null) {
      _showMessage('Please set the location using the button above.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final AppEvent? existing = widget.existingEvent;
      final user = AuthService().currentUser;

      final AppEvent event = AppEvent(
        // When editing, the same id says which record to update. When
        // creating, it is ignored: Firebase generates the key with push().
        id: existing?.id ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _category,
        imageUrl: _chooseImageUrl(),
        venueName: _venueController.text.trim(),
        dateTime: _dateTime!.millisecondsSinceEpoch,
        lat: _lat!,
        lng: _lng!,
        isOutdoor: _isOutdoor,
        // Ownership never changes on edit. Keeping the original owner is also
        // what the security rules check before allowing the update.
        ownerUid: existing?.ownerUid ?? user?.uid ?? '',
        ownerName: existing?.ownerName ?? user?.displayName ?? 'Unknown',
        createdAt:
            existing?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
      );

      if (_isEditing) {
        await _eventService.updateEvent(event);
        if (!mounted) return;
        // Opened on top of My Events, so close and go back there. The list
        // updates by itself because it is listening to the database.
        Navigator.pop(context);
        _showMessage('Changes saved.');
      } else {
        await _eventService.createEvent(event);
        if (!mounted) return;
        _showMessage('Event posted.');
        _resetForm();
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        _isEditing
            ? 'Could not save the changes. Please try again.'
            : 'Could not post the event. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Clears the form after a successful post.
  ///
  /// The Create tab is permanent rather than a pushed page, so there is
  /// nothing to navigate away from - it has to empty itself, or the next event
  /// starts with the last one's text still in it.
  void _resetForm() {
    _formKey.currentState!.reset();
    _titleController.clear();
    _descriptionController.clear();
    _venueController.clear();
    setState(() {
      _category = eventCategories.first;
      _dateTime = null;
      _isOutdoor = true;
      _lat = null;
      _lng = null;
    });
  }

  /// Shows a short message at the bottom of the screen.
  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // When editing, this screen was pushed on top of My Events, so the
      // AppBar automatically gets a back arrow.
      appBar: AppBar(title: Text(_isEditing ? 'Edit event' : 'Create event')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _buildTextFields(),
            const SizedBox(height: 16),
            _buildCategoryDropdown(),
            const SizedBox(height: 16),
            _buildDateField(),
            const SizedBox(height: 8),
            _buildOutdoorSwitch(),
            const SizedBox(height: 8),
            _buildLocationSection(),
            const SizedBox(height: 24),
            _buildSubmitButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Title, description and venue - the three typed fields.
  Widget _buildTextFields() {
    return Column(
      children: <Widget>[
        TextFormField(
          controller: _titleController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Event title',
            prefixIcon: Icon(Icons.title),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please give the event a title';
            }
            if (value.trim().length < 4) return 'That title is a bit short';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          // Grows to three lines, so a description is comfortable to type.
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Description',
            alignLabelWithHint: true,
            prefixIcon: Icon(Icons.notes),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please describe the event';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _venueController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Venue name',
            prefixIcon: Icon(Icons.place_outlined),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please name the venue';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// The category dropdown, which also decides the event photo.
  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _category,
      decoration: const InputDecoration(
        labelText: 'Category',
        prefixIcon: Icon(Icons.category_outlined),
      ),
      items: eventCategories
          .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
          .toList(),
      // Cannot be null: it starts with a value and a dropdown cannot be
      // cleared, which is why there is no validator here.
      onChanged: (value) {
        if (value != null) setState(() => _category = value);
      },
    );
  }

  /// A tappable row showing the chosen date, or a prompt to choose one.
  ///
  /// Not a TextFormField, because typing a date invites typos and awkward
  /// parsing. The picker can only produce a valid date.
  Widget _buildDateField() {
    final ThemeData theme = Theme.of(context);
    final bool chosen = _dateTime != null;

    return InkWell(
      onTap: _pickDateTime,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        // InputDecorator gives this the same outlined box as the real text
        // fields, so the form looks consistent even though this is a button.
        decoration: const InputDecoration(
          labelText: 'Date and time',
          prefixIcon: Icon(Icons.calendar_today_outlined),
        ),
        child: Text(
          chosen
              ? DateFormat('EEE, d MMM yyyy  h:mm a').format(_dateTime!)
              : 'Tap to choose',
          style: chosen
              ? theme.textTheme.bodyLarge
              : theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
        ),
      ),
    );
  }

  /// Indoors or outdoors. Used by the detail screen to decide how prominently
  /// to show the weather.
  Widget _buildOutdoorSwitch() {
    return SwitchListTile(
      value: _isOutdoor,
      onChanged: (value) => setState(() => _isOutdoor = value),
      title: const Text('Outdoor event'),
      subtitle: const Text('Weather will be shown on the event page'),
      contentPadding: EdgeInsets.zero,
    );
  }

  /// The GPS button and whatever it has captured.
  Widget _buildLocationSection() {
    final ThemeData theme = Theme.of(context);
    final bool hasLocation = _lat != null && _lng != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: _isGettingLocation ? null : _useCurrentLocation,
          icon: _isGettingLocation
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location),
          label: Text(
            _isGettingLocation
                ? 'Getting location...'
                : 'Use my current location',
          ),
        ),
        const SizedBox(height: 8),
        if (!hasLocation)
          Text(
            'Needed so people can see how far away the event is.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Row(
            children: <Widget>[
              Icon(
                Icons.check_circle,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                // Four decimal places is about 11 metres - precise enough to
                // be useful, short enough to read.
                'Location set: ${_lat!.toStringAsFixed(4)}, '
                '${_lng!.toStringAsFixed(4)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
      ],
    );
  }

  /// The submit button, which disables itself while the save is in flight.
  Widget _buildSubmitButton() {
    final String label = _isEditing ? 'Save changes' : 'Post event';
    final String busyLabel = _isEditing ? 'Saving...' : 'Posting...';

    return FilledButton.icon(
      onPressed: _isSaving ? null : _save,
      icon: _isSaving
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(_isEditing ? Icons.save_outlined : Icons.publish),
      label: Text(_isSaving ? busyLabel : label),
    );
  }
}
