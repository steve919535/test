enum TripCategory {
  business,
  personal,
  unclassified;

  String get label => switch (this) {
    TripCategory.business => 'Business',
    TripCategory.personal => 'Personal',
    TripCategory.unclassified => 'Unclassified',
  };

  String get dbValue => name;

  static TripCategory fromDbValue(String value) =>
      TripCategory.values.firstWhere(
        (c) => c.dbValue == value,
        orElse: () => TripCategory.unclassified,
      );
}

/// A single recorded trip. [endTime] is null while the trip is still open
/// (the driver is currently in motion and the trip hasn't been finalized).
class Trip {
  Trip({
    this.id,
    required this.startTime,
    this.endTime,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    this.startAddress,
    this.endAddress,
    required this.distanceMeters,
    this.category = TripCategory.unclassified,
    this.notes,
    this.autoDetected = true,
  });

  final int? id;
  final DateTime startTime;
  final DateTime? endTime;
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;
  final String? startAddress;
  final String? endAddress;
  final double distanceMeters;
  final TripCategory category;
  final String? notes;
  final bool autoDetected;

  bool get isOpen => endTime == null;

  double get distanceKm => distanceMeters / 1000;

  /// Journey duration. `null` while the trip is still open (no [endTime]
  /// yet) rather than falling back to "now", since an open trip's duration
  /// keeps changing and isn't a fact about the trip until it's closed.
  Duration? get duration => endTime?.difference(startTime);

  Trip copyWith({
    int? id,
    DateTime? startTime,
    DateTime? endTime,
    bool clearEndTime = false,
    double? startLat,
    double? startLng,
    double? endLat,
    double? endLng,
    String? startAddress,
    String? endAddress,
    double? distanceMeters,
    TripCategory? category,
    String? notes,
    bool? autoDetected,
  }) {
    return Trip(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      startLat: startLat ?? this.startLat,
      startLng: startLng ?? this.startLng,
      endLat: endLat ?? this.endLat,
      endLng: endLng ?? this.endLng,
      startAddress: startAddress ?? this.startAddress,
      endAddress: endAddress ?? this.endAddress,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      autoDetected: autoDetected ?? this.autoDetected,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'start_time': startTime.toUtc().millisecondsSinceEpoch,
      'end_time': endTime?.toUtc().millisecondsSinceEpoch,
      'start_lat': startLat,
      'start_lng': startLng,
      'end_lat': endLat,
      'end_lng': endLng,
      'start_address': startAddress,
      'end_address': endAddress,
      'distance_meters': distanceMeters,
      'category': category.dbValue,
      'notes': notes,
      'auto_detected': autoDetected ? 1 : 0,
    };
  }

  static Trip fromMap(Map<String, Object?> map) {
    return Trip(
      id: map['id'] as int?,
      startTime: DateTime.fromMillisecondsSinceEpoch(
        map['start_time'] as int,
        isUtc: true,
      ).toLocal(),
      endTime: map['end_time'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              map['end_time'] as int,
              isUtc: true,
            ).toLocal(),
      startLat: map['start_lat'] as double,
      startLng: map['start_lng'] as double,
      endLat: map['end_lat'] as double,
      endLng: map['end_lng'] as double,
      startAddress: map['start_address'] as String?,
      endAddress: map['end_address'] as String?,
      distanceMeters: map['distance_meters'] as double,
      category: TripCategory.fromDbValue(map['category'] as String),
      notes: map['notes'] as String?,
      autoDetected: (map['auto_detected'] as int) == 1,
    );
  }
}
