# CivicSpeak – resident app (Flutter)

*Your city. Your voice. Your future.*

The resident app for CivicSpeak. It talks to the Django backend's `/api/` (see the backend README).

## What's in it
- **Survey first, then the account.** The answers decide what shows up first and what you get notified about.
- **Home:** Ongoing (brief summaries), Completed (updates on proposals you follow come first), Abandoned (what fell through, and why).
- **Proposal:** Breakdown · Pros & Cons (Impacts once completed) · Process · Sources. Your view (Support / Neutral / Oppose) only while input is open. No vote totals are shown to residents.
- **+ Follow** pins a proposal on the **map** (red pin icon). Map has Ongoing and Completed tabs, impact circles, and a popup with cost, who pays and when → funding (reserve fund statements).
- **Notifications** (bell), **Community** (one staff story per completed proposal, no points or rewards), **Settings** (answers, language EN/FR/ES/ZH, audio mode with Read aloud, text size).

## Run it
You need Flutter 3.22 or newer.

```bash
cd civicspeak_app
flutter create . --org ca.civicspeak --project-name civicspeak   # adds the android/ios/web folders (keeps lib/)
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000      # Android emulator → Django on your computer
```

`API_BASE_URL` options:
- Android emulator to a local server: `http://10.0.2.2:8000` (the default)
- iOS simulator or Chrome: `http://localhost:8000`
- Your Coolify deploy: `https://your-civicspeak-domain`

### Android settings for a local (http) server
In `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<application android:usesCleartextTraffic="true" ...>
```
(Only needed for `http://`. A Coolify deploy with `https://` doesn't need cleartext.)

### Push notifications (Firebase)
The server sends a push when staff publish a proposal, change it, or post an update, to residents who
chose app notifications and either follow it or match its topics, area and timing. Each push also shows under the bell.

1. Create a Firebase project at console.firebase.google.com (free).
2. In this folder:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure        # pick the project; adds google-services.json and GoogleService-Info.plist
   ```
3. **iOS only:** in Xcode turn on *Push Notifications* and *Background Modes → Remote notifications*,
   and upload an APNs key in Firebase → Project settings → Cloud Messaging.
4. **Server:** Firebase → Project settings → Service accounts → *Generate new private key*.
   Put that JSON in Coolify as `FIREBASE_CREDENTIALS_JSON` (paste it, or base64 it to keep it on one line).
   Never commit it.

Without step 2 the app still runs; push is just off and the bell keeps working.

### Backend checklist
1. Backend running with PostGIS (`docker compose up` or Coolify).
2. `python manage.py load_demo_proposals` (or `LOAD_DEMO=1`) so there is something to show.
3. For Flutter web, keep `CORS_ALLOWED_ORIGINS=*` or set it to the web app's origin.

## Files
```
lib/
  main.dart            app, theme, text size, splash → Welcome or Home
  config.dart          API_BASE_URL and default map centre
  api.dart             HTTP client for /api/
  state.dart           sign-in, profile, language, audio mode, unread count
  theme.dart           pastel tabs, Libre Baskerville, navy, red pin
  i18n.dart            EN / FR / ES / ZH interface text
  survey_data.dart     the onboarding survey questions
  widgets.dart         header icons (home, map pin, bell, community, settings), pill tabs, cards
  screens/             welcome, survey, account, home, proposal, funding, map, notifications, community, settings
```
