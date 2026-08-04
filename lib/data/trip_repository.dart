import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'trip.dart';

/// Data access + in-memory cache for trips.
///
/// A [TripRepository] can be created in any isolate -- it opens its own
/// database connection lazily. The main app keeps one instance alive for
/// the whole UI (via `provider`) and calls [load] to refresh its cache,
/// which is what widgets actually read from. The Android background
/// tracking isolate creates its own throwaway instance purely to write
/// open-trip progress; it never calls [load] and nothing reads its cache.
class TripRepository extends ChangeNotifier {
  Database? _db;
  List<Trip> _trips = [];
  Trip? _openTrip;

  /// Closed trips, most recent first.
  List<Trip> get trips => List.unmodifiable(_trips);

  Trip? findById(int id) {
    for (final trip in _trips) {
      if (trip.id == id) return trip;
    }
    return null;
  }

  /// The trip currently in progress, if the detector thinks the device is
  /// driving right now.
  Trip? get openTrip => _openTrip;

  Future<Database> get _database async => _db ??= await DatabaseHelper.open();

  /// Reloads the in-memory cache from disk and notifies listeners.
  Future<void> load() async {
    final db = await _database;
    final closedRows = await db.query(
      'trips',
      where: 'end_time IS NOT NULL',
      orderBy: 'start_time DESC',
    );
    _trips = closedRows.map(Trip.fromMap).toList();

    final openRows = await db.query(
      'trips',
      where: 'end_time IS NULL',
      limit: 1,
    );
    _openTrip = openRows.isEmpty ? null : Trip.fromMap(openRows.first);

    notifyListeners();
  }

  // --- Used by the trip-detection engine (may run in a different isolate) ---

  Future<Trip?> getOpenTrip() async {
    final db = await _database;
    final rows = await db.query('trips', where: 'end_time IS NULL', limit: 1);
    return rows.isEmpty ? null : Trip.fromMap(rows.first);
  }

  Future<int> startOpenTrip(Trip trip) async {
    final db = await _database;
    return db.insert('trips', trip.toMap());
  }

  Future<void> updateOpenTripProgress(
    int id, {
    required double distanceMeters,
    required double endLat,
    required double endLng,
  }) async {
    final db = await _database;
    await db.update(
      'trips',
      {'distance_meters': distanceMeters, 'end_lat': endLat, 'end_lng': endLng},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> closeTrip(
    int id, {
    required DateTime endTime,
    required double distanceMeters,
    required double endLat,
    required double endLng,
  }) async {
    final db = await _database;
    await db.update(
      'trips',
      {
        'end_time': endTime.toUtc().millisecondsSinceEpoch,
        'distance_meters': distanceMeters,
        'end_lat': endLat,
        'end_lng': endLng,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> discardTrip(int id) async {
    final db = await _database;
    await db.delete('trips', where: 'id = ?', whereArgs: [id]);
  }

  // --- Used by the UI (always the main isolate) ---

  Future<void> insertManualTrip(Trip trip) async {
    final db = await _database;
    await db.insert('trips', trip.toMap());
    await load();
  }

  Future<void> setCategory(int id, TripCategory category) async {
    final db = await _database;
    await db.update(
      'trips',
      {'category': category.dbValue},
      where: 'id = ?',
      whereArgs: [id],
    );
    await load();
  }

  Future<void> updateNotes(int id, String? notes) async {
    final db = await _database;
    await db.update(
      'trips',
      {'notes': notes},
      where: 'id = ?',
      whereArgs: [id],
    );
    await load();
  }

  Future<void> deleteTrip(int id) async {
    final db = await _database;
    await db.delete('trips', where: 'id = ?', whereArgs: [id]);
    await load();
  }

  Future<void> updateAddresses(
    int id, {
    String? startAddress,
    String? endAddress,
  }) async {
    final db = await _database;
    final values = <String, Object?>{};
    if (startAddress != null) values['start_address'] = startAddress;
    if (endAddress != null) values['end_address'] = endAddress;
    if (values.isEmpty) return;
    await db.update('trips', values, where: 'id = ?', whereArgs: [id]);
    final index = _trips.indexWhere((t) => t.id == id);
    if (index != -1) {
      _trips[index] = _trips[index].copyWith(
        startAddress: startAddress,
        endAddress: endAddress,
      );
      notifyListeners();
    }
  }

  // --- Aggregates for the dashboard, computed over the in-memory cache ---

  double totalKm({TripCategory? category, DateTime? from, DateTime? to}) {
    return _filtered(
      category: category,
      from: from,
      to: to,
    ).fold<double>(0, (sum, t) => sum + t.distanceKm);
  }

  int tripCount({TripCategory? category, DateTime? from, DateTime? to}) {
    return _filtered(category: category, from: from, to: to).length;
  }

  List<Trip> _filtered({TripCategory? category, DateTime? from, DateTime? to}) {
    return _trips.where((t) {
      if (category != null && t.category != category) return false;
      if (from != null && t.startTime.isBefore(from)) return false;
      if (to != null && t.startTime.isAfter(to)) return false;
      return true;
    }).toList();
  }
}
