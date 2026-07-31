/// Event subtype definitions for all sport categories
/// This class provides constants and helpers for specific race distances/types
class EventSubtype {
  const EventSubtype({
    required this.name,
    required this.displayName,
    this.distanceMiles,
    this.swimDistanceMeters,
    this.bikeDistanceMiles,
    this.runDistanceMiles,
  });

  final String name;
  final String displayName;
  final double? distanceMiles;

  // For multi-sport events
  final double? swimDistanceMeters;
  final double? bikeDistanceMiles;
  final double? runDistanceMiles;

  /// Running event subtypes
  static const runningEvents = [
    EventSubtype(name: '5k', displayName: '5K (3.1 mi)', distanceMiles: 3.1),
    EventSubtype(name: '10k', displayName: '10K (6.2 mi)', distanceMiles: 6.2),
    EventSubtype(name: '15k', displayName: '15K (9.3 mi)', distanceMiles: 9.3),
    EventSubtype(name: '10_mile', displayName: '10 Mile', distanceMiles: 10.0),
    EventSubtype(
      name: 'half_marathon',
      displayName: 'Half Marathon (13.1 mi)',
      distanceMiles: 13.1,
    ),
    EventSubtype(
      name: '25k',
      displayName: '25K (15.5 mi)',
      distanceMiles: 15.5,
    ),
    EventSubtype(
      name: '30k',
      displayName: '30K (18.6 mi)',
      distanceMiles: 18.6,
    ),
    EventSubtype(
      name: 'marathon',
      displayName: 'Marathon (26.2 mi)',
      distanceMiles: 26.2,
    ),
    EventSubtype(
      name: 'ultra_50k',
      displayName: '50K Ultra (31 mi)',
      distanceMiles: 31.0,
    ),
    EventSubtype(
      name: 'ultra_50m',
      displayName: '50 Mile Ultra',
      distanceMiles: 50.0,
    ),
    EventSubtype(
      name: 'ultra_100k',
      displayName: '100K Ultra (62 mi)',
      distanceMiles: 62.0,
    ),
    EventSubtype(
      name: 'ultra_100m',
      displayName: '100 Mile Ultra',
      distanceMiles: 100.0,
    ),
    EventSubtype(
      name: 'ultra_12h',
      displayName: '12 Hour Ultra',
      distanceMiles: null,
    ),
    EventSubtype(
      name: 'ultra_24h',
      displayName: '24 Hour Ultra',
      distanceMiles: null,
    ),
    EventSubtype(
      name: 'custom',
      displayName: 'Custom Distance',
      distanceMiles: null,
    ),
  ];

  /// Cycling event subtypes
  static const cyclingEvents = [
    EventSubtype(name: '10k', displayName: '10K (6.2 mi)', distanceMiles: 6.2),
    EventSubtype(
      name: '20k',
      displayName: '20K (12.4 mi)',
      distanceMiles: 12.4,
    ),
    EventSubtype(
      name: '40k_tt',
      displayName: '40K Time Trial (24.9 mi)',
      distanceMiles: 24.9,
    ),
    EventSubtype(name: '50k', displayName: '50K (31 mi)', distanceMiles: 31.0),
    EventSubtype(
      name: 'half_century',
      displayName: 'Half Century (50 mi)',
      distanceMiles: 50.0,
    ),
    EventSubtype(
      name: 'metric_century',
      displayName: 'Metric Century (100K / 62 mi)',
      distanceMiles: 62.0,
    ),
    EventSubtype(
      name: 'century',
      displayName: 'Century (100 mi)',
      distanceMiles: 100.0,
    ),
    EventSubtype(
      name: 'gran_fondo',
      displayName: 'Gran Fondo (70-100+ mi)',
      distanceMiles: 85.0,
    ),
    EventSubtype(
      name: '200k',
      displayName: '200K (124 mi)',
      distanceMiles: 124.0,
    ),
    EventSubtype(
      name: 'custom',
      displayName: 'Custom Distance',
      distanceMiles: null,
    ),
  ];

  /// Swimming event subtypes
  static const swimmingEvents = [
    EventSubtype(
      name: '1k',
      displayName: '1K Open Water',
      distanceMiles: 0.62,
      swimDistanceMeters: 1000,
    ),
    EventSubtype(
      name: '1.5k',
      displayName: '1.5K Open Water',
      distanceMiles: 0.93,
      swimDistanceMeters: 1500,
    ),
    EventSubtype(
      name: '2.5k',
      displayName: '2.5K Open Water',
      distanceMiles: 1.55,
      swimDistanceMeters: 2500,
    ),
    EventSubtype(
      name: '5k',
      displayName: '5K Open Water',
      distanceMiles: 3.1,
      swimDistanceMeters: 5000,
    ),
    EventSubtype(
      name: '10k',
      displayName: '10K Open Water',
      distanceMiles: 6.2,
      swimDistanceMeters: 10000,
    ),
    EventSubtype(
      name: 'custom',
      displayName: 'Custom Distance',
      distanceMiles: null,
    ),
  ];

  /// Triathlon event subtypes
  static const triathlonEvents = [
    EventSubtype(
      name: 'sprint',
      displayName: 'Sprint (750m / 20K / 5K)',
      swimDistanceMeters: 750,
      bikeDistanceMiles: 12.4,
      runDistanceMiles: 3.1,
    ),
    EventSubtype(
      name: 'olympic',
      displayName: 'Olympic (1.5K / 40K / 10K)',
      swimDistanceMeters: 1500,
      bikeDistanceMiles: 24.9,
      runDistanceMiles: 6.2,
    ),
    EventSubtype(
      name: 'half_ironman',
      displayName: 'Half Ironman / 70.3 (1.9K / 90K / 21.1K)',
      swimDistanceMeters: 1900,
      bikeDistanceMiles: 56.0,
      runDistanceMiles: 13.1,
    ),
    EventSubtype(
      name: 'ironman',
      displayName: 'Full Ironman / 140.6 (3.8K / 180K / 42.2K)',
      swimDistanceMeters: 3800,
      bikeDistanceMiles: 112.0,
      runDistanceMiles: 26.2,
    ),
    EventSubtype(
      name: 'custom',
      displayName: 'Custom Triathlon',
      swimDistanceMeters: null,
      bikeDistanceMiles: null,
      runDistanceMiles: null,
    ),
  ];

  /// Duathlon event subtypes
  static const duathlonEvents = [
    EventSubtype(
      name: 'sprint',
      displayName: 'Sprint (5K run / 20K bike / 2.5K run)',
      bikeDistanceMiles: 12.4,
      runDistanceMiles: 4.7, // 5K + 2.5K = 7.5K = 4.7 mi
    ),
    EventSubtype(
      name: 'standard',
      displayName: 'Standard (10K run / 40K bike / 5K run)',
      bikeDistanceMiles: 24.9,
      runDistanceMiles: 9.3, // 10K + 5K = 15K = 9.3 mi
    ),
    EventSubtype(
      name: 'long_course',
      displayName: 'Long Course (10K run / 60K bike / 10K run)',
      bikeDistanceMiles: 37.3,
      runDistanceMiles: 12.4, // 10K + 10K = 20K = 12.4 mi
    ),
    EventSubtype(
      name: 'custom',
      displayName: 'Custom Duathlon',
      bikeDistanceMiles: null,
      runDistanceMiles: null,
    ),
  ];

  /// Multi-sport event subtypes
  static const multisportEvents = [
    EventSubtype(name: 'aquathlon', displayName: 'Aquathlon (Swim + Run)'),
    EventSubtype(name: 'aquabike', displayName: 'Aquabike (Swim + Bike)'),
    EventSubtype(name: 'custom', displayName: 'Custom Multi-Sport'),
  ];

  /// Get subtypes for a given event type
  static List<EventSubtype> getSubtypesForEventType(String eventTypeDbValue) {
    switch (eventTypeDbValue) {
      case 'running':
        return runningEvents;
      case 'cycling':
        return cyclingEvents;
      case 'swimming':
        return swimmingEvents;
      case 'triathlon':
        return triathlonEvents;
      case 'duathlon':
        return duathlonEvents;
      case 'multisport':
        return multisportEvents;
      default:
        return runningEvents;
    }
  }

  /// Find an EventSubtype by name
  static EventSubtype? findByName(String eventTypeDbValue, String subtypeName) {
    final subtypes = getSubtypesForEventType(eventTypeDbValue);
    try {
      return subtypes.firstWhere((s) => s.name == subtypeName);
    } catch (e) {
      return null;
    }
  }

  /// Get total distance in miles for the event (handles multi-sport)
  double? get totalDistanceMiles {
    if (distanceMiles != null) return distanceMiles;

    // For multi-sport, sum all legs
    double total = 0.0;
    bool hasDistance = false;

    if (swimDistanceMeters != null) {
      total += swimDistanceMeters! * 0.000621371; // meters to miles
      hasDistance = true;
    }
    if (bikeDistanceMiles != null) {
      total += bikeDistanceMiles!;
      hasDistance = true;
    }
    if (runDistanceMiles != null) {
      total += runDistanceMiles!;
      hasDistance = true;
    }

    return hasDistance ? total : null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventSubtype &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}
