import 'meal_source.dart';
import 'meal_type.dart';
import 'wire_record.dart';

/// What a day-planner slot points at — `DaySlotRef` in `contracts.ts`.
class DaySlotRef extends WireRecord {
  const DaySlotRef({
    required this.source,
    required this.id,
    required this.name,
    this.kcal,
    this.carbsG,
  });

  final DaySlotSource source;
  final String id;
  final String name;
  final int? kcal;
  final double? carbsG;

  factory DaySlotRef.fromJson(Map<String, dynamic> json) => DaySlotRef(
    source: DaySlotSource.requireWire(readString(json, 'source')),
    id: requireString(json, 'id'),
    name: readString(json, 'name') ?? '',
    kcal: readInt(json, 'kcal'),
    carbsG: readDouble(json, 'carbsG'),
  );

  @override
  Map<String, dynamic> toJson() => {
    'source': source.wire,
    'id': id,
    'name': name,
    'kcal': kcal,
    'carbsG': carbsG,
  };

  DaySlotRef copyWith({
    DaySlotSource? source,
    String? id,
    String? name,
    int? kcal,
    double? carbsG,
  }) => DaySlotRef(
    source: source ?? this.source,
    id: id ?? this.id,
    name: name ?? this.name,
    kcal: kcal ?? this.kcal,
    carbsG: carbsG ?? this.carbsG,
  );
}

/// One day's slots — `DayPlan = Partial<Record<DaySlot, DaySlotRef | null>>`.
///
/// A slot can be absent (never set) or present-and-null (explicitly cleared);
/// both read as "empty" via [slotFor] but round-trip distinctly.
class DayPlan extends WireRecord {
  const DayPlan({this.slots = const {}});

  static const empty = DayPlan();

  final Map<MealType, DaySlotRef?> slots;

  DaySlotRef? slotFor(MealType slot) => slots[slot];

  bool get isEmpty => slots.values.every((ref) => ref == null);

  /// Slots that currently hold a reference.
  List<MealType> get filled => [
    for (final entry in slots.entries)
      if (entry.value != null) entry.key,
  ];

  factory DayPlan.fromJson(Map<String, dynamic> json) {
    final slots = <MealType, DaySlotRef?>{};
    for (final entry in json.entries) {
      final slot = MealType.fromWire(entry.key);
      if (slot == null) continue; // unknown slot key — drop
      final map = asJsonMap(entry.value);
      if (map == null) {
        slots[slot] = null;
        continue;
      }
      try {
        slots[slot] = DaySlotRef.fromJson(map);
      } on FormatException {
        // Malformed ref — treat as empty rather than fail the day.
        slots[slot] = null;
      }
    }
    return DayPlan(slots: Map.unmodifiable(slots));
  }

  @override
  Map<String, dynamic> toJson() => {
    for (final entry in slots.entries) entry.key.wire: entry.value?.toJson(),
  };

  DayPlan copyWith({Map<MealType, DaySlotRef?>? slots}) =>
      DayPlan(slots: slots ?? this.slots);

  /// Returns a copy with [slot] set to [ref] (`null` clears it).
  DayPlan withSlot(MealType slot, DaySlotRef? ref) =>
      DayPlan(slots: Map.unmodifiable({...slots, slot: ref}));
}
