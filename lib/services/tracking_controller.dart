import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../data/trip_repository.dart';
import 'background_task_handler.dart';
import 'location_settings.dart';
import 'trip_detection_engine.dart';

enum TrackingStartResult { success, locationServicesDisabled, permissionDenied }

/// Facade the UI talks to for turning automatic trip detection on/off.
///
/// The two platforms keep the tracking loop alive in fundamentally
/// different ways -- Android needs an explicit foreground service running
/// in its own isolate (handled by [TripTrackingTaskHandler]), while iOS
/// keeps the app process alive for background location natively once
/// "Always" permission and the `location` background mode are granted, so
/// the detector can just run in the main isolate. This class hides that
/// split behind a single start/stop API.
class TrackingController extends ChangeNotifier {
  TrackingController(this._repository);

  final TripRepository _repository;
  TripDetectionEngine? _iosEngine;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  Future<void> init() async {
    if (Platform.isAndroid) {
      FlutterForegroundTask.initCommunicationPort();
      FlutterForegroundTask.addTaskDataCallback(_onTaskData);
      _initForegroundTaskOptions();
      _isRunning = await FlutterForegroundTask.isRunningService;
    } else {
      final prefs = await SharedPreferences.getInstance();
      final wasEnabled = prefs.getBool(kPrefsTrackingEnabled) ?? false;
      if (wasEnabled) {
        await start();
        return;
      }
    }
    notifyListeners();
  }

  void _onTaskData(Object data) {
    if (data == 'trips_updated') {
      _repository.load();
    }
  }

  void _initForegroundTaskOptions() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: kForegroundTaskChannelId,
        channelName: kForegroundTaskChannelName,
        channelDescription:
            'Shown while Mileage Tracker is watching for trips.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// Requests foreground location, then escalates to background ("Always")
  /// location. Android and iOS both require a second, separate prompt for
  /// background access after foreground access is granted.
  Future<LocationPermission> ensureLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  Future<TrackingStartResult> start() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return TrackingStartResult.locationServicesDisabled;
    }

    final permission = await ensureLocationPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return TrackingStartResult.permissionDenied;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefsTrackingEnabled, true);

    if (Platform.isAndroid) {
      await _startAndroidService();
    } else {
      final engine = _iosEngine ?? TripDetectionEngine(_repository);
      engine.onTripChanged = _repository.load;
      _iosEngine = engine;
      await engine.start(
        Geolocator.getPositionStream(
          locationSettings: trackingLocationSettings(),
        ),
      );
    }

    _isRunning = true;
    notifyListeners();
    return TrackingStartResult.success;
  }

  Future<void> _startAndroidService() async {
    final notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        serviceId: kForegroundServiceId,
        serviceTypes: const [ForegroundServiceTypes.location],
        notificationTitle: 'Mileage Tracker',
        notificationText: 'Watching for trips…',
        callback: tripTrackingStartCallback,
      );
    }
  }

  Future<void> stop() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefsTrackingEnabled, false);

    if (Platform.isAndroid) {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } else {
      await _iosEngine?.stop();
    }

    _isRunning = false;
    notifyListeners();
  }

  /// Best-effort request to exempt the app from battery optimizations, so
  /// Android is less likely to kill the tracking service. Android only;
  /// no-op elsewhere.
  Future<void> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return;
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }
}
