import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/constants.dart';
import '../data/trip.dart';

/// Wraps `flutter_local_notifications` for the one thing this app uses it
/// for: telling the user a trip just finished recording, so they can tap
/// through and mark it Business or Personal.
///
/// Each Dart isolate gets its own copy of this singleton (isolates don't
/// share memory), so both the main isolate (which needs it to *receive* taps
/// and navigate) and the Android foreground-service isolate (which needs it
/// to *show* the notification in the first place) call [init] independently.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<int> _tapController =
      StreamController<int>.broadcast();

  bool _initialized = false;

  /// Emits a trip id whenever the user taps a trip-completed notification
  /// while the app is already running.
  Stream<int> get onTripTapped => _tapController.stream;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      ),
      onDidReceiveNotificationResponse: _handleResponse,
    );

    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

  void _handleResponse(NotificationResponse response) {
    final tripId = int.tryParse(response.payload ?? '');
    if (tripId != null) _tapController.add(tripId);
  }

  /// If the app was fully closed and the user tapped a trip-completed
  /// notification to launch it, returns that trip's id so the caller can
  /// navigate straight to it. Returns null on every other kind of launch.
  Future<int?> consumeLaunchTripId() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      return int.tryParse(details!.notificationResponse?.payload ?? '');
    }
    return null;
  }

  Future<void> showTripCompletedNotification(Trip trip) async {
    final id = trip.id;
    if (id == null) return;

    const androidDetails = AndroidNotificationDetails(
      kTripCompletedChannelId,
      kTripCompletedChannelName,
      channelDescription:
          'Lets you know a trip finished recording so you can categorize it.',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      id: id,
      title: 'Trip recorded — ${trip.distanceKm.toStringAsFixed(1)} km',
      body: 'Tap to mark it Business or Personal.',
      notificationDetails: details,
      payload: '$id',
    );
  }
}
