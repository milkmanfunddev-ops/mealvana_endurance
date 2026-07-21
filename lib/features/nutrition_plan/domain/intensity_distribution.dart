/// Represents the distribution of workout intensity across three zones.
///
/// All percentages must sum to 100. This is used to track how much time
/// an athlete spends in each training zone during a workout.
///
/// Zone definitions:
/// - Conversational (Z1-Z2): Easy effort, can hold conversation
/// - Tempo (Z3-Z4): Moderate-hard effort
/// - All-Out (Z5+): Maximum effort, race pace
class IntensityDistribution {
  /// Percentage of workout spent in Conversational zone (Z1-Z2)
  final int conversationalPct;

  /// Percentage of workout spent in Tempo zone (Z3-Z4)
  final int tempoPct;

  /// Percentage of workout spent in All-Out zone (Z5+)
  final int allOutPct;

  /// Creates an intensity distribution with validation.
  ///
  /// Throws [ArgumentError] if percentages don't sum to 100 or if any
  /// percentage is negative or greater than 100.
  ///
  /// Use the const constructor for compile-time constant patterns.
  const IntensityDistribution({
    required this.conversationalPct,
    required this.tempoPct,
    required this.allOutPct,
  }) : assert(conversationalPct >= 0 && conversationalPct <= 100),
       assert(tempoPct >= 0 && tempoPct <= 100),
       assert(allOutPct >= 0 && allOutPct <= 100),
       assert(conversationalPct + tempoPct + allOutPct == 100);

  /// Creates an intensity distribution with runtime validation.
  ///
  /// Prefer using the const constructor when possible. Use this factory
  /// when values are computed at runtime and need validation error messages.
  factory IntensityDistribution.validated({
    required int conversationalPct,
    required int tempoPct,
    required int allOutPct,
  }) {
    if (conversationalPct < 0 || conversationalPct > 100) {
      throw ArgumentError(
        'conversationalPct must be between 0 and 100, got $conversationalPct',
      );
    }
    if (tempoPct < 0 || tempoPct > 100) {
      throw ArgumentError('tempoPct must be between 0 and 100, got $tempoPct');
    }
    if (allOutPct < 0 || allOutPct > 100) {
      throw ArgumentError(
        'allOutPct must be between 0 and 100, got $allOutPct',
      );
    }

    final sum = conversationalPct + tempoPct + allOutPct;
    if (sum != 100) {
      throw ArgumentError(
        'Percentages must sum to 100, got $sum '
        '(conversational: $conversationalPct, tempo: $tempoPct, allOut: $allOutPct)',
      );
    }

    return IntensityDistribution(
      conversationalPct: conversationalPct,
      tempoPct: tempoPct,
      allOutPct: allOutPct,
    );
  }

  /// Creates the default intensity distribution: 70% Conversational, 20% Tempo, 10% All-Out.
  ///
  /// This is based on the 80/20 training principle, where most training volume
  /// should be at easy intensity.
  factory IntensityDistribution.defaultDistribution() {
    return IntensityDistribution(
      conversationalPct: 70,
      tempoPct: 20,
      allOutPct: 10,
    );
  }

  /// Creates a copy with optional field updates.
  IntensityDistribution copyWith({
    int? conversationalPct,
    int? tempoPct,
    int? allOutPct,
  }) {
    return IntensityDistribution(
      conversationalPct: conversationalPct ?? this.conversationalPct,
      tempoPct: tempoPct ?? this.tempoPct,
      allOutPct: allOutPct ?? this.allOutPct,
    );
  }

  /// Adjusts the distribution when one zone changes, distributing the delta
  /// proportionally across the other zones.
  ///
  /// Algorithm:
  /// 1. Calculate delta = newValue - oldValue
  /// 2. Distribute delta proportionally across other zones
  /// 3. Clamp all values to 0-100
  /// 4. Normalize to ensure sum = 100
  ///
  /// Example:
  /// - Start: 70/20/10 (conversational/tempo/allOut)
  /// - User changes conversational from 70 to 80 (delta = +10)
  /// - Remaining zones: tempo (20), allOut (10), total = 30
  /// - tempo -= 10 * (20/30) = 20 - 6.67 = 13.33 → 13
  /// - allOut -= 10 * (10/30) = 10 - 3.33 = 6.67 → 7
  /// - Result: 80/13/7
  ///
  /// Edge cases:
  /// - If sum != 100 after adjustment, normalize proportionally
  /// - If only one zone has value > 0, that zone locks at current value (others locked at 0)
  /// - Minimum value for any zone: 0%
  /// - Maximum value for any zone: 100%
  IntensityDistribution adjustProportionally({
    int? conversationalPct,
    int? tempoPct,
    int? allOutPct,
  }) {
    // Determine which zone changed
    final changedZone = conversationalPct != null
        ? 'conversational'
        : tempoPct != null
        ? 'tempo'
        : allOutPct != null
        ? 'allOut'
        : throw ArgumentError('At least one zone must be provided');

    final newValue = conversationalPct ?? tempoPct ?? allOutPct!;
    final oldValue = changedZone == 'conversational'
        ? this.conversationalPct
        : changedZone == 'tempo'
        ? this.tempoPct
        : this.allOutPct;

    // Clamp the new value to 0-100
    final clampedNewValue = newValue.clamp(0, 100);
    final delta = clampedNewValue - oldValue;

    // If no change, return unchanged
    if (delta == 0) {
      return this;
    }

    // Start with current values
    var newConversational = this.conversationalPct;
    var newTempo = this.tempoPct;
    var newAllOut = this.allOutPct;

    // Update the changed zone
    if (changedZone == 'conversational') {
      newConversational = clampedNewValue;
    } else if (changedZone == 'tempo') {
      newTempo = clampedNewValue;
    } else {
      newAllOut = clampedNewValue;
    }

    // Calculate remaining zones total
    final remainingZones = <String, int>{};
    if (changedZone != 'conversational') {
      remainingZones['conversational'] = newConversational;
    }
    if (changedZone != 'tempo') {
      remainingZones['tempo'] = newTempo;
    }
    if (changedZone != 'allOut') {
      remainingZones['allOut'] = newAllOut;
    }

    final totalRemaining = remainingZones.values.fold<int>(
      0,
      (sum, val) => sum + val,
    );

    // If no remaining value to distribute
    if (totalRemaining == 0) {
      if (delta < 0) {
        // We're reducing a zone at 100% - distribute freed percentage equally to others
        final freedPct = -delta; // e.g., if changing from 100 to 80, freed = 20
        final otherZones = remainingZones.keys.toList();
        final pctPerZone = freedPct ~/ otherZones.length; // Integer division
        final remainder = freedPct % otherZones.length;

        var i = 0;
        for (final zone in otherZones) {
          final extra = i < remainder ? 1 : 0; // Distribute remainder
          if (zone == 'conversational') {
            newConversational = pctPerZone + extra;
          } else if (zone == 'tempo') {
            newTempo = pctPerZone + extra;
          } else {
            newAllOut = pctPerZone + extra;
          }
          i++;
        }
      } else {
        // Original behavior for increasing to 100%
        if (changedZone != 'conversational') newConversational = 0;
        if (changedZone != 'tempo') newTempo = 0;
        if (changedZone != 'allOut') newAllOut = 0;
      }
    } else {
      // Distribute delta proportionally
      for (final entry in remainingZones.entries) {
        final proportion = entry.value / totalRemaining;
        final adjustment = (delta * proportion).round();

        if (entry.key == 'conversational') {
          newConversational = (newConversational - adjustment).clamp(0, 100);
        } else if (entry.key == 'tempo') {
          newTempo = (newTempo - adjustment).clamp(0, 100);
        } else {
          newAllOut = (newAllOut - adjustment).clamp(0, 100);
        }
      }
    }

    // Normalize to ensure sum = 100
    final sum = newConversational + newTempo + newAllOut;
    if (sum != 100) {
      // Find the largest zone to absorb the difference
      final diff = 100 - sum;
      if (newConversational >= newTempo && newConversational >= newAllOut) {
        newConversational = (newConversational + diff).clamp(0, 100);
      } else if (newTempo >= newConversational && newTempo >= newAllOut) {
        newTempo = (newTempo + diff).clamp(0, 100);
      } else {
        newAllOut = (newAllOut + diff).clamp(0, 100);
      }
    }

    return IntensityDistribution(
      conversationalPct: newConversational,
      tempoPct: newTempo,
      allOutPct: newAllOut,
    );
  }

  /// Converts to JSON format for persistence.
  Map<String, dynamic> toJson() {
    return {
      'conversationalPct': conversationalPct,
      'tempoPct': tempoPct,
      'allOutPct': allOutPct,
    };
  }

  /// Creates from JSON format.
  factory IntensityDistribution.fromJson(Map<String, dynamic> json) {
    return IntensityDistribution(
      conversationalPct: json['conversationalPct'] as int,
      tempoPct: json['tempoPct'] as int,
      allOutPct: json['allOutPct'] as int,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is IntensityDistribution &&
        other.conversationalPct == conversationalPct &&
        other.tempoPct == tempoPct &&
        other.allOutPct == allOutPct;
  }

  @override
  int get hashCode {
    return Object.hash(conversationalPct, tempoPct, allOutPct);
  }

  @override
  String toString() {
    return 'IntensityDistribution(conversational: $conversationalPct%, tempo: $tempoPct%, allOut: $allOutPct%)';
  }
}
