# CityEvents

A Flutter app for finding and sharing local community events in Colombo.

- Sign in and register with Firebase Authentication
- Create, browse, edit and delete events stored in the Firebase Realtime Database,
  with live updates and RSVPs
- Events sorted by distance from your GPS location
- Live weather for each venue from OpenWeather
- Push notifications for chosen categories with Firebase Cloud Messaging
- Material 3 design with automatic light and dark mode, and layouts that adapt to
  rotation and wider screens

## Running the app

1. Install [Flutter](https://docs.flutter.dev/get-started/install) and run
   `flutter pub get`.
2. Copy `secrets.example.json` to `secrets.json` and put your
   [OpenWeather API key](https://home.openweathermap.org/api_keys) in it.
3. Run it:

   ```
   flutter run --dart-define-from-file=secrets.json
   ```

   In VS Code, pressing F5 adds this for you.

Without the key the app still runs, and only the weather panel shows an error.

## Firebase

The app connects to the Firebase project in `lib/firebase_options.dart` and
`android/app/google-services.json`. These files identify the project and are not
secret. Access to the data is controlled by the security rules in
`database.rules.json`.
