// Domain models for the By-Hour nutrition view.
// Maps food items from a during-activity section into 15-minute time slots
// grouped by hour. Drinks appear at :00 inline with other food items.

import 'food_item_data.dart';

/// Represents a 15-minute slot within an hour.
class TimeSlot {
  const TimeSlot({required this.hourIndex, required this.slotIndex});

  /// 0-based hour (0 = Hour 1, 1 = Hour 2, etc.)
  final int hourIndex;

  /// 0-3 within the hour (0 = :00, 1 = :15, 2 = :30, 3 = :45)
  final int slotIndex;

  /// Display label like "0:00", "0:15", "1:30"
  String get displayLabel {
    final hour = hourIndex;
    final minutes = slotIndex * 15;
    return '$hour:${minutes.toString().padLeft(2, '0')}';
  }

  /// Absolute minutes from activity start
  int get absoluteMinutes => hourIndex * 60 + slotIndex * 15;

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      hourIndex: json['hourIndex'] as int,
      slotIndex: json['slotIndex'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'hourIndex': hourIndex,
    'slotIndex': slotIndex,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeSlot &&
          runtimeType == other.runtimeType &&
          hourIndex == other.hourIndex &&
          slotIndex == other.slotIndex;

  @override
  int get hashCode => hourIndex.hashCode ^ slotIndex.hashCode;

  @override
  String toString() => 'TimeSlot($displayLabel)';
}

/// Maps a food item to a specific time slot.
class TimeSlotAssignment {
  const TimeSlotAssignment({
    required this.foodItemId,
    required this.timeSlot,
    this.isSipThroughout = false,
    this.adjustedQuantity,
    this.timingCategory,
  });

  /// References FoodItemData.id in the parent PlanSection.foodItems
  final String foodItemId;

  /// The time slot this food is assigned to
  final TimeSlot timeSlot;

  /// True for drinks that should be sipped throughout the hour
  final bool isSipThroughout;

  /// Adjusted quantity for this hour's portion (e.g., 1.0 when 3 servings split across 3 hours).
  /// When null, the food's full quantity is used (backward compat).
  final double? adjustedQuantity;

  /// Timing category for UI badge rendering. Nullable for backward compat.
  final TimingCategory? timingCategory;

  TimeSlotAssignment copyWith({
    String? foodItemId,
    TimeSlot? timeSlot,
    bool? isSipThroughout,
    double? adjustedQuantity,
    TimingCategory? timingCategory,
  }) {
    return TimeSlotAssignment(
      foodItemId: foodItemId ?? this.foodItemId,
      timeSlot: timeSlot ?? this.timeSlot,
      isSipThroughout: isSipThroughout ?? this.isSipThroughout,
      adjustedQuantity: adjustedQuantity ?? this.adjustedQuantity,
      timingCategory: timingCategory ?? this.timingCategory,
    );
  }

  factory TimeSlotAssignment.fromJson(Map<String, dynamic> json) {
    return TimeSlotAssignment(
      foodItemId: json['foodItemId'] as String,
      timeSlot: TimeSlot.fromJson(json['timeSlot'] as Map<String, dynamic>),
      isSipThroughout: json['isSipThroughout'] as bool? ?? false,
      adjustedQuantity: (json['adjustedQuantity'] as num?)?.toDouble(),
      timingCategory: _parseTimingCategory(json['timingCategory'] as String?),
    );
  }

  static TimingCategory? _parseTimingCategory(String? value) {
    if (value == null) return null;
    for (final tc in TimingCategory.values) {
      if (tc.name == value) return tc;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'foodItemId': foodItemId,
    'timeSlot': timeSlot.toJson(),
    'isSipThroughout': isSipThroughout,
    if (adjustedQuantity != null) 'adjustedQuantity': adjustedQuantity,
    if (timingCategory != null) 'timingCategory': timingCategory!.name,
  };

  @override
  String toString() =>
      'TimeSlotAssignment($foodItemId @ ${timeSlot.displayLabel}${isSipThroughout ? " sip" : ""}${adjustedQuantity != null ? " qty=$adjustedQuantity" : ""})';
}

/// Container for all by-hour assignment data for a during-activity section.
class ByHourData {
  const ByHourData({required this.durationMinutes, required this.assignments});

  /// Total duration of the during phase in minutes
  final int durationMinutes;

  /// All food-to-slot assignments
  final List<TimeSlotAssignment> assignments;

  /// Number of full hours (e.g., 150 min -> 2 full hours)
  int get totalFullHours => durationMinutes ~/ 60;

  /// Total hours including partial (e.g., 150 min -> 3)
  int get totalHours =>
      (durationMinutes / 60).ceil().clamp(1, double.infinity).toInt();

  /// Number of 15-minute slots in the last hour (if partial).
  ///
  /// Only shows slots where food can meaningfully be scheduled.
  /// Hides trailing slots that fall within the end-cutoff zone (last 15 min)
  /// where no food would be placed by the apportionment algorithm.
  int get lastHourSlotCount {
    final remainder = durationMinutes % 60;
    if (remainder == 0) return 4; // Full hour
    // Only show slots where at least END_CUTOFF (15 min) remains after slot start
    final usableMinutes = remainder - 15;
    if (usableMinutes <= 0) return 1; // Always show :00 for drinks
    return (usableMinutes ~/ 15) + 1;
  }

  /// Number of slots for a given hour index
  int slotCountForHour(int hourIndex) {
    if (hourIndex < totalHours - 1) return 4; // Full hour
    return lastHourSlotCount;
  }

  /// Get global sip-throughout assignments (hourIndex == -1).
  /// These are drinks and electrolytes that apply across all hours.
  List<TimeSlotAssignment> get globalSipAssignments {
    return assignments.where((a) => a.timeSlot.hourIndex == -1).toList();
  }

  /// Get assignments for a specific hour (excludes global sip items)
  List<TimeSlotAssignment> assignmentsForHour(int hourIndex) {
    return assignments.where((a) => a.timeSlot.hourIndex == hourIndex).toList()
      ..sort((a, b) => a.timeSlot.slotIndex.compareTo(b.timeSlot.slotIndex));
  }

  /// Get assignments for a specific time slot
  List<TimeSlotAssignment> assignmentsForSlot(TimeSlot slot) {
    return assignments.where((a) => a.timeSlot == slot).toList();
  }

  ByHourData copyWith({
    int? durationMinutes,
    List<TimeSlotAssignment>? assignments,
  }) {
    return ByHourData(
      durationMinutes: durationMinutes ?? this.durationMinutes,
      assignments: assignments ?? this.assignments,
    );
  }

  factory ByHourData.fromJson(Map<String, dynamic> json) {
    return ByHourData(
      durationMinutes: json['durationMinutes'] as int,
      assignments: (json['assignments'] as List<dynamic>)
          .map((a) => TimeSlotAssignment.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'durationMinutes': durationMinutes,
    'assignments': assignments.map((a) => a.toJson()).toList(),
  };

  @override
  String toString() =>
      'ByHourData(${durationMinutes}min, ${assignments.length} assignments, $totalHours hours)';
}
