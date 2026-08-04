import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../data/trip_repository.dart';
import 'location_settings.dart';
import 'notification_service.dart';
import 'trip_detection_engine.dart';

/// Entry point for the Android foreground-service isolate.
///
/// Must be a top-level (or static) function annotated `@pragma('vm:entry-point')`
/// so the Android side can find it when it spins up a fresh Dart isolate for
/// the service.
@pragma('vm:entry-point')
void tripTrackingStartCallback() {
  FlutterForegroundTask.setTaskHandler(TripTrackingTaskHandler());
}

/// Runs entirely inside the foreground-service isolate: it has its own
/// database connection and its own [TripDetectionEngine], separate from
/// whatever the main isolate is doing. Progress is pushed to the main
/// isolate only as "something changed" pings so the UI can reload from
/// disk -- the isolates never share Dart objects.
class TripTrackingTaskHandler extends TaskHandler {
  TripDetectionEngine? _engine;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // This isolate has never touched the notifications plugin before, so it
    // needs its own initialize() call before show() will work here.
    await NotificationService.instance.init();

    final repository = TripRepository();
    final engine = TripDetectionEngine(repository);
    engine.onTripChanged = () {
      FlutterForegroundTask.sendDataToMain('trips_updated');
    };
    engine.onTripCompleted = (trip) {
      NotificationService.instance.showTripCompletedNotification(trip);
    };
    _engine = engine;

    await engine.start(
      Geolocator.getPositionStream(
        locationSettings: trackingLocationSettings(),
      ),
    );
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Not used -- the engine reacts to the position stream directly.
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _engine?.stop();
    _engine = null;
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }
}
