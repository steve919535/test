import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../core/constants.dart';
import '../data/trip.dart';
import '../data/trip_repository.dart';

enum _State { idle, driving }

/// Infers trip start/end from a raw stream of GPS fixes and persists the
/// result through a [TripRepository].
///
/// This class has no Flutter/platform dependency beyond geolocator's
/// [Position] type, so the exact same code runs whether it's driven from
/// the main isolate (iOS, where the OS keeps the app alive for background
/// location) or from the Android foreground-service isolate.
///
/// Detection is speed-based, since that's the only signal available without
/// extra permissions: sustained speed above [kStartSpeedThresholdKmh] starts
/// a trip, sustained speed below [kStopSpeedThresholdKmh] ends one. Both
/// transitions require the condition to hold for a confirmation window so a
/// red light or a burst of GPS jitter doesn't fabricate a trip boundary.
class TripDetectionEngine {
  TripDetectionEngine(this._repository);

  final TripRepository _repository;

  StreamSubscription<Position>? _subscription;
  _State _state = _State.idle;

  DateTime? _fastSince;
  DateTime? _slowSince;
  final List<Position> _recentBuffer = [];

  int? _openTripId;
  DateTime? _openTripStartTime;
  double _accumulatedMeters = 0;
  Position? _last;

  /// Invoked whenever a trip is started, updated, or finished, so the
  /// caller can react (e.g. tell the main isolate to refresh its UI).
  void Function()? onTripChanged;

  /// Invoked specifically when a trip is confirmed finished and saved
  /// (never for a discarded noise trip), with the finished trip's full
  /// record -- e.g. to fire a "categorize this trip" notification.
  void Function(Trip trip)? onTripCompleted;

  Future<void> start(Stream<Position> positions) async {
    final open = await _repository.getOpenTrip();
    if (open != null && open.id != null) {
      _state = _State.driving;
      _openTripId = open.id;
      _openTripStartTime = open.startTime;
      _accumulatedMeters = open.distanceMeters;
      _last = Position(
        latitude: open.endLat,
        longitude: open.endLng,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }
    await _subscription?.cancel();
    _subscription = positions.listen(_onPosition, onError: (_) {});
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _onPosition(Position position) async {
    if (position.accuracy > kPositionAccuracyThresholdMeters) return;

    final speedKmh = position.speed < 0 ? 0.0 : position.speed * 3.6;

    if (_state == _State.idle) {
      await _handleIdle(position, speedKmh);
    } else {
      await _handleDriving(position, speedKmh);
    }
  }

  Future<void> _handleIdle(Position position, double speedKmh) async {
    if (speedKmh >= kStartSpeedThresholdKmh) {
      _fastSince ??= position.timestamp;
      _recentBuffer.add(position);
      if (position.timestamp.difference(_fastSince!) >= kStartConfirmDuration) {
        await _confirmTripStart();
      }
    } else {
      _fastSince = null;
      _recentBuffer.clear();
    }
  }

  Future<void> _confirmTripStart() async {
    final origin = _recentBuffer.first;
    final destination = _recentBuffer.last;

    var distance = 0.0;
    for (var i = 1; i < _recentBuffer.length; i++) {
      distance += Geolocator.distanceBetween(
        _recentBuffer[i - 1].latitude,
        _recentBuffer[i - 1].longitude,
        _recentBuffer[i].latitude,
        _recentBuffer[i].longitude,
      );
    }

    final trip = Trip(
      startTime: origin.timestamp,
      startLat: origin.latitude,
      startLng: origin.longitude,
      endLat: destination.latitude,
      endLng: destination.longitude,
      distanceMeters: distance,
      category: TripCategory.unclassified,
      autoDetected: true,
    );

    _openTripId = await _repository.startOpenTrip(trip);
    _openTripStartTime = origin.timestamp;
    _accumulatedMeters = distance;
    _last = destination;
    _state = _State.driving;
    _fastSince = null;
    _recentBuffer.clear();
    onTripChanged?.call();
  }

  Future<void> _handleDriving(Position position, double speedKmh) async {
    final last = _last;
    if (last != null) {
      final deltaMeters = Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        position.latitude,
        position.longitude,
      );
      final elapsedSeconds = position.timestamp
          .difference(last.timestamp)
          .inSeconds
          .clamp(1, 3600);
      final impliedSpeedKmh = (deltaMeters / elapsedSeconds) * 3.6;
      // Ignore a single implausible jump (e.g. a GPS bounce) rather than let
      // it inflate the trip's distance.
      if (impliedSpeedKmh < 300) {
        _accumulatedMeters += deltaMeters;
      }
    }
    _last = position;

    final id = _openTripId;
    if (id != null) {
      await _repository.updateOpenTripProgress(
        id,
        distanceMeters: _accumulatedMeters,
        endLat: position.latitude,
        endLng: position.longitude,
      );
    }

    if (speedKmh <= kStopSpeedThresholdKmh) {
      _slowSince ??= position.timestamp;
      if (position.timestamp.difference(_slowSince!) >= kStopConfirmDuration) {
        await _finishTrip(_slowSince!);
      }
    } else {
      _slowSince = null;
    }
  }

  Future<void> _finishTrip(DateTime endTime) async {
    final id = _openTripId;
    final startTime = _openTripStartTime;
    final last = _last;
    if (id == null || startTime == null || last == null) return;

    final tripDuration = endTime.difference(startTime);
    if (_accumulatedMeters < kMinTripDistanceMeters ||
        tripDuration < kMinTripDuration) {
      await _repository.discardTrip(id);
    } else {
      await _repository.closeTrip(
        id,
        endTime: endTime,
        distanceMeters: _accumulatedMeters,
        endLat: last.latitude,
        endLng: last.longitude,
      );
      final finished = await _repository.getById(id);
      if (finished != null) onTripCompleted?.call(finished);
    }

    _openTripId = null;
    _openTripStartTime = null;
    _accumulatedMeters = 0;
    _last = null;
    _slowSince = null;
    _state = _State.idle;
    onTripChanged?.call();
  }
}
