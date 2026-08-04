# Mileage Tracker

A Flutter (Material 3) mileage tracker for iOS and Android. Everything runs
and stays on-device: trip detection, storage, and exports. No account, no
server, no subscription.

## Features

- **Automatic trip start/end detection** from GPS speed, running in the
  background even when the app isn't open.
- **A notification the moment a trip ends**, prompting Business or Personal;
  tapping it jumps straight to that trip (works whether the app is
  backgrounded or fully closed).
- **Business / Personal** categorization per trip (plus an "unclassified"
  state for trips awaiting review, in case a notification is dismissed
  without tapping it).
- **Dashboard** with business/personal kilometre totals for the current
  month and all time.
- **Filter the trip list** by date range (all time / this month / this year /
  custom) and type (Business / Personal / Unclassified).
- **Local storage only** — trips live in an on-device SQLite database.
- **CSV and PDF export**, filterable by date range and category, shared
  through the OS share sheet.
- **Dedicated business tax report export** (CSV or a signature-ready PDF)
  pre-filtered to business trips for a chosen period, separate from the
  general export above.
- Manual trip entry for anything automatic tracking missed.

## How automatic detection works

There's no OS API that simply tells an app "the user is driving now." This
app infers it from a stream of GPS fixes:

- A trip **starts** once speed has stayed above ~15 km/h for 45 seconds
  straight (filters out a red-light-adjacent GPS blip).
- A trip **ends** once speed has stayed below ~5 km/h for 3 minutes straight
  (rides out a stoplight or a short queue without ending the trip early).
- Trips under 500 m or 60 seconds are treated as GPS noise and discarded
  rather than saved.

All of this logic lives in `lib/services/trip_detection_engine.dart` and is
plain Dart with no platform dependency, so the same code drives both
platforms' background loops (see below).

**Limitations inherent to a permission-light, speed-only heuristic:** a bus
or train ride can look like driving; a very slow crawl in heavy traffic can
look like "stopped" and end a trip early. There's no way to fully solve this
without asking for motion-activity permissions and building a fusion model,
which was out of scope here. Wrongly captured trips can just be deleted or
recategorized in the trip list.

## Why tracking is implemented differently per platform

- **Android** has no concept of "let my app run forever in the background."
  Reliable background location requires a persistent **foreground service**
  (via `flutter_foreground_task`), which runs the detector in its own Dart
  isolate (`lib/services/background_task_handler.dart`) with its own SQLite
  connection, and pings the main isolate (`sendDataToMain`) whenever a trip
  changes so the UI can reload from disk.
- **iOS** has the opposite constraint: `flutter_foreground_task`'s
  background isolate on iOS is limited to ~30 seconds of runtime every ~15
  minutes, useless for continuous tracking. Instead, once "Always" location
  permission is granted and `UIBackgroundModes: location` is set (already
  configured in `Info.plist`), iOS keeps the app's own process alive
  indefinitely for location updates. So on iOS the detector just runs
  directly in the main isolate against the same `TripRepository` instance
  the UI uses — no cross-isolate messaging needed at all.

`lib/services/tracking_controller.dart` hides this split behind one
`start()`/`stop()` API.

## Project layout

```
lib/
  core/constants.dart              tuning constants for the detector
  data/                            Trip model, sqflite access, in-memory cache
  services/
    trip_detection_engine.dart     the state machine (pure Dart)
    background_task_handler.dart   Android foreground-service entry point
    tracking_controller.dart       start/stop facade, permissions
    location_settings.dart         per-platform GPS settings
    geocoding_service.dart         best-effort reverse geocoding
    notification_service.dart      trip-completed notification + tap routing
    export_service.dart            CSV / PDF generation + share sheet
  ui/                               screens (Trips, Dashboard, Settings)
    trips/widgets/trip_filter_sheet.dart   date-range + type filter, reused by
                                            the Trips list, the general export,
                                            and (with the category locked to
                                            Business) the tax report export
```

## Running it

```
flutter pub get
flutter run
```

Automatic tracking requires a real device (background GPS doesn't mean much
in a simulator) and, on Android, a dev build rather than Expo-Go-style
hosting — this is a normal Flutter app, so `flutter run` / `flutter build`
already produce that.

The very first time you turn on "Automatic trip detection" in Settings, the
OS will prompt for location permission twice — once for foreground access,
once to escalate to "Always"/background access. Background tracking won't
work without the second grant.

### Permissions declared

- **Android** (`android/app/src/main/AndroidManifest.xml`): fine/coarse/background
  location, `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_LOCATION`,
  notifications (required on Android 13+ both for the foreground-service
  notification and the trip-completed alert), and an optional
  battery-optimization exemption request surfaced in Settings.
- **iOS** (`ios/Runner/Info.plist`): `NSLocationAlwaysAndWhenInUseUsageDescription`
  and `UIBackgroundModes: [location]`. Notification permission (alert/badge/sound)
  is requested separately at runtime the first time the app initializes.

### Trip-completed notifications

`flutter_local_notifications` needs a bit of native wiring beyond the Dart
side:

- **Android**: `android/app/build.gradle.kts` enables core library
  desugaring (`isCoreLibraryDesugaringEnabled` + the `desugar_jdk_libs`
  dependency) and `multiDexEnabled`, both required by the plugin regardless
  of whether notifications are scheduled or shown immediately (which is all
  this app does).
- **iOS**: `ios/Runner/AppDelegate.swift` sets
  `UNUserNotificationCenter.current().delegate` and registers the plugin's
  background-isolate plugin registrant callback, both required for the app
  to receive notification taps.

Showing the notification itself happens wherever a trip finishes: inside the
Android foreground-service isolate, or the iOS main isolate. Both call
`NotificationService.instance` independently — each isolate has its own copy
of that singleton and must `init()` the plugin itself before `show()` will
work there.

## About the business tax report

`ExportService.shareBusinessTaxReportPdf` (Settings → Tax records) produces a
PDF styled for handing to an accountant: a "Period: ..." line, a business-only
trip table with a purpose/notes column, and a prepared-by/date signature line
at the bottom. It deliberately does **not** claim to satisfy any specific tax
authority's requirements — I don't know your jurisdiction and can't verify
that, so it states plainly that it's a self-reported GPS record and that you
should keep it alongside whatever documentation your tax authority actually
requires. Treat the wording in `export_service.dart`'s disclaimer as a
starting point to edit if you know your own jurisdiction's requirements.

## Reverse geocoding and "offline"

Trip addresses are a display convenience, resolved lazily via the OS's own
geocoder (`geocoding` package — Apple's on iOS, Android's `Geocoder` on
Android) when a trip is shown in the list. This is the same as any GPS app
resolving a street address and needs network connectivity to do so, but it
talks to no service of ours — no account, no API key, no analytics. If it's
offline or fails, the trip just shows raw coordinates instead; nothing about
recording, categorizing, or exporting trips depends on it.

## Known limitations

- If the user force-quits the app on iOS mid-trip, iOS will not relaunch it
  in the background (Apple only auto-relaunches apps killed by the system,
  not by the user). The open trip resumes accumulating once the app is
  reopened; the gap in between isn't tracked.
- The detector can't distinguish "driving" from "passenger in a fast
  vehicle" (bus, train, being driven) — it only sees speed.
- This project was built and statically analyzed (`flutter analyze`,
  `flutter test`) in a sandbox without Android/iOS SDKs available, so a full
  native build has not been run here. Run `flutter build apk` /
  `flutter build ios` locally before shipping to confirm the Gradle/Xcode
  configuration builds clean on your machine.
