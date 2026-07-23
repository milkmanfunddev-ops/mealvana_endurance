import '../../../shared/domain/activity_type.dart';

/// Service that generates race day gear checklist items based on event type and user profile
class GearTemplateService {
  /// Generate gear list for an event
  ///
  /// Parameters:
  /// - [eventType]: Type of event (running, cycling, swimming, triathlon, etc.)
  /// - [userGender]: User's gender ('male', 'female', 'other') for gender-specific items
  /// - [eventSubtype]: Optional event subtype for distance-specific items (e.g., 'marathon', 'ultra_50k')
  ///
  /// Returns a list of gear item names in display order
  List<String> generateGearList({
    required ActivityType eventType,
    required String? userGender,
    String? eventSubtype,
  }) {
    switch (eventType) {
      case ActivityType.running:
        return _getRunningGear(userGender, eventSubtype);

      case ActivityType.cycling:
        return _getCyclingGear(userGender, eventSubtype);

      case ActivityType.swimming:
        return _getSwimmingGear(userGender);

      case ActivityType.triathlon:
      case ActivityType.duathlon:
      case ActivityType.multisport:
      case ActivityType.brick:
        return _getTriathlonGear(userGender, eventSubtype);

      case ActivityType.other:
        // Import-only, unsupported activity type — races/events are never
        // created with this type, but handle it with a minimal generic list.
        return _getGenericGear(userGender);
    }
  }

  /// Generic gear for unsupported/"other" activity types
  List<String> _getGenericGear(String? userGender) {
    return [
      'Comfortable athletic clothing',
      'Athletic shoes',
      if (userGender == 'female') 'Sports bra',
      'Water bottle',
      'GPS watch/fitness tracker',
      'Sunscreen',
    ];
  }

  /// Running-specific gear
  List<String> _getRunningGear(String? userGender, String? eventSubtype) {
    final gear = <String>[
      'Running shoes',
      'Running shorts/pants',
      'Running shirt/singlet',
      if (userGender == 'female') 'Sports bra',
      'Socks (moisture-wicking)',
      'GPS watch/fitness tracker',
      'Race bib',
      'Race belt OR safety pins',
      'Sunglasses',
      'Hat or visor',
      'Sunscreen',
      'Body glide/anti-chafe cream',
    ];

    // Add distance-specific items for longer races
    if (_isLongDistanceRun(eventSubtype)) {
      gear.addAll(['Band-aids/blister protection']);
    }

    // Ultra-specific items
    if (_isUltraRun(eventSubtype)) {
      gear.addAll([
        'Headlamp + extra batteries',
        'Trail running shoes',
        'Trekking poles (if allowed)',
        'Emergency blanket',
      ]);
    }

    return gear;
  }

  /// Cycling-specific gear
  List<String> _getCyclingGear(String? userGender, String? eventSubtype) {
    return [
      'Bike (race-ready)',
      'Helmet',
      'Cycling shoes',
      'Cycling shorts/bibs',
      'Cycling jersey',
      if (userGender == 'female') 'Sports bra',
      'Socks',
      'Cycling gloves',
      'Sunglasses',
      'GPS bike computer',
      'Race number',
      'Saddle bag with tools',
      'Spare tube (2)',
      'CO2 cartridges (2-3) OR mini pump',
      'Tire levers',
      'Multi-tool',
    ];
  }

  /// Swimming/Open water specific gear
  List<String> _getSwimmingGear(String? userGender) {
    return [
      'Swimsuit OR tri suit',
      'Goggles (primary)',
      'Goggles (backup pair)',
      'Swim cap',
      if (userGender == 'female') 'Sports bra (under tri suit)',
      if (userGender == 'female') 'Hair ties',
      'Towel',
      'Flip flops/sandals',
      'Race bib',
      'Wetsuit (if water temp requires)',
      'Wetsuit lubricant',
    ];
  }

  /// Triathlon/Multisport gear (combines all sports)
  List<String> _getTriathlonGear(String? userGender, String? eventSubtype) {
    final gear = <String>[
      // Transition essentials
      'Transition bag/mat',
      'Towel (for drying feet)',
      'Race belt with bib',
      'Body marking (race numbers)',

      // Swim gear
      'Tri suit OR swim-to-bike outfit',
      'Goggles (primary + backup)',
      'Wetsuit (if applicable)',
      'Wetsuit lubricant',
      'Swim cap',

      // Bike gear
      'Bike (race-ready)',
      'Helmet',
      'Cycling shoes OR running shoes',
      if (userGender == 'female') 'Sports bra',
      'Sunglasses',
      'Bike computer/GPS watch',
      'Spare tube + CO2/pump',
      'Multi-tool',

      // Run gear
      'Running shoes (with elastic laces)',
      'Hat/visor',
      'Sunscreen (pre-applied)',
    ];

    // Add distance-specific items for Half Ironman / Ironman
    if (_isLongDistanceTriathlon(eventSubtype)) {
      gear.addAll([
        'Special needs bags (bike/run)',
        'Bike lights (if early/late)',
        'Arm warmers/leg warmers',
        'Rain jacket (in special needs)',
        'Extra socks',
      ]);
    }

    return gear;
  }

  /// Check if event is a long distance run (half marathon or longer)
  bool _isLongDistanceRun(String? eventSubtype) {
    if (eventSubtype == null) return false;
    return eventSubtype.contains('half_marathon') ||
        eventSubtype.contains('marathon') ||
        eventSubtype.contains('ultra');
  }

  /// Check if event is an ultra run (50K or longer)
  bool _isUltraRun(String? eventSubtype) {
    if (eventSubtype == null) return false;
    return eventSubtype.contains('ultra');
  }

  /// Check if event is a long distance triathlon (Half Ironman or Ironman)
  bool _isLongDistanceTriathlon(String? eventSubtype) {
    if (eventSubtype == null) return false;
    return eventSubtype.contains('half_ironman') ||
        eventSubtype.contains('ironman') ||
        eventSubtype.contains('70.3');
  }
}
