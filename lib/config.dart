/// Where the Django backend lives.
///
/// Set it when you run the app:
///   flutter run --dart-define=API_BASE_URL=https://civicspeak.example.com
///
/// Defaults: Android emulator reaches your computer at 10.0.2.2.
/// For the iOS simulator or Flutter web on the same computer use http://127.0.0.1:8000.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000',
);

/// Map starts here until proposals load (Toronto city hall).
const double defaultLat = 43.6534;
const double defaultLng = -79.3841;
