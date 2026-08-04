import 'dart:io';

import 'package:geolocator/geolocator.dart';

import '../core/constants.dart';

/// Location settings used for automatic trip tracking, shared by both the
/// Android foreground-service isolate and the iOS main-isolate stream.
LocationSettings trackingLocationSettings() {
  if (Platform.isAndroid) {
    return AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: kLocationDistanceFilterMeters,
      intervalDuration: kAndroidLocationInterval,
      forceLocationManager: false,
    );
  }
  if (Platform.isIOS) {
    return AppleSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: kLocationDistanceFilterMeters,
      activityType: ActivityType.automotiveNavigation,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: true,
      allowBackgroundLocationUpdates: true,
    );
  }
  return LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: kLocationDistanceFilterMeters,
  );
}
