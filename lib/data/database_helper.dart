import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';

/// Opens the on-device SQLite database.
///
/// Every isolate that touches the database (the main UI isolate, and on
/// Android the separate foreground-service isolate that runs while the app
/// is backgrounded) must open its own connection -- Dart isolates don't
/// share memory, but sqflite/SQLite itself is safe to open concurrently
/// from multiple connections against the same file, so this is called
/// independently wherever it's needed rather than passed across isolates.
class DatabaseHelper {
  DatabaseHelper._();

  static Database? _db;

  static Future<Database> open() async {
    final existing = _db;
    if (existing != null && existing.isOpen) return existing;

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, kDatabaseName);

    final db = await openDatabase(
      path,
      version: kDatabaseVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE trips (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            start_time INTEGER NOT NULL,
            end_time INTEGER,
            start_lat REAL NOT NULL,
            start_lng REAL NOT NULL,
            end_lat REAL NOT NULL,
            end_lng REAL NOT NULL,
            start_address TEXT,
            end_address TEXT,
            distance_meters REAL NOT NULL,
            category TEXT NOT NULL DEFAULT 'unclassified',
            notes TEXT,
            auto_detected INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_trips_start_time ON trips(start_time)',
        );
        await db.execute('CREATE INDEX idx_trips_end_time ON trips(end_time)');
      },
    );
    _db = db;
    return db;
  }
}
