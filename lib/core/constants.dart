/// Tuning constants for the automatic trip-detection heuristic and storage.
///
/// The detector has no access to a "driving" signal from the OS -- it only
/// sees a stream of GPS fixes -- so it infers trip boundaries from sustained
/// speed. These values are a deliberate trade-off between catching real
/// trips quickly and ignoring GPS jitter / brisk walks / short stops.
library;

/// Speed above which the device is considered to be "moving" for the
/// purpose of starting a trip.
const double kStartSpeedThresholdKmh = 15.0;

/// How long the speed must stay above [kStartSpeedThresholdKmh] before a
/// trip is confirmed to have started.
const Duration kStartConfirmDuration = Duration(seconds: 45);

/// Speed below which the device is considered to have "stopped".
const double kStopSpeedThresholdKmh = 5.0;

/// How long the speed must stay below [kStopSpeedThresholdKmh] before a
/// trip is considered finished. Long enough to ride out a red light or a
/// short stop-and-go queue.
const Duration kStopConfirmDuration = Duration(minutes: 3);

/// Trips shorter than this are treated as GPS noise and discarded rather
/// than saved.
const double kMinTripDistanceMeters = 500.0;

/// Trips shorter than this are treated as GPS noise and discarded rather
/// than saved.
const Duration kMinTripDuration = Duration(seconds: 60);

/// Fixes less accurate than this (in meters) are ignored entirely so a
/// single bad reading can't fabricate a jump in distance.
const double kPositionAccuracyThresholdMeters = 50.0;

/// Minimum distance (in meters) the device must move before a foreground
/// location update is delivered. 0 means "report every update" -- filtering
/// for noise happens in the detector, not the OS location layer.
const int kLocationDistanceFilterMeters = 0;

/// Android-only: desired interval between location updates while tracking.
/// Also used as the cadence the stop-timer relies on to notice the device
/// is still stationary.
const Duration kAndroidLocationInterval = Duration(seconds: 15);

const String kDatabaseName = 'mileage_tracker.db';
const int kDatabaseVersion = 1;

const String kForegroundTaskChannelId = 'mileage_tracker_tracking';
const String kForegroundTaskChannelName = 'Trip tracking';
const int kForegroundServiceId = 4001;

const String kPrefsTrackingEnabled = 'tracking_enabled';
