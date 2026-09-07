import 'day_plan.dart';
import 'meal_plan.dart';
import 'meal_ref.dart';
import 'meal_type.dart';
import 'plan_rule.dart';
import 'shopping_item.dart';
import 'user_memory.dart';
import 'wire_record.dart';

/// A tool result that renders in the chat — `VanaPart` in `contracts.ts`
/// (`kind` discriminant). The UI renders parts, never raw JSON.
///
/// Sealed so the widget layer can switch exhaustively. Unknown kinds are
/// dropped at the parse layer (same forward-compat rule as
/// `AiCoachUiPart.fromJson`): a newer server's part simply does not render
/// on an older client.
sealed class VanaPart extends WireRecord {
  const VanaPart();

  String get kind;

  /// Returns `null` for an unknown `kind` or malformed JSON so callers can
  /// filter with `whereType<VanaPart>()`.
  static VanaPart? fromJson(Map<String, dynamic> json) {
    try {
      switch (json['kind']) {
        case 'choices':
          return VanaChoicesPart.fromJson(json);
        case 'meal_picker':
          return VanaMealPickerPart.fromJson(json);
        case 'staples':
          return VanaStaplesPart.fromJson(json);
        case 'batch':
          return VanaBatchPart.fromJson(json);
        case 'rule':
          return VanaRulePart.fromJson(json);
        case 'shopping_list':
          return VanaShoppingListPart.fromJson(json);
        case 'day_guidance':
          return VanaDayGuidancePart.fromJson(json);
        case 'memory_saved':
          return VanaMemorySavedPart.fromJson(json);
        case 'logged':
          return VanaLoggedPart.fromJson(json);
        case 'day':
          return VanaDayPart.fromJson(json);
        case 'brief':
          return VanaBriefPart.fromJson(json);
        case 'pantry':
          return VanaPantryPart.fromJson(json);
        case 'week':
          return VanaWeekPart.fromJson(json);
        case 'debrief':
          return VanaDebriefPart.fromJson(json);
        default:
          return null;
      }
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// Parse a list, dropping unknown/malformed entries.
  static List<VanaPart> listFromJson(Object? raw) {
    if (raw is! List) return const [];
    return List.unmodifiable([
      for (final item in raw)
        if (asJsonMap(item) case final map?)
          if (fromJson(map) case final part?) part,
    ]);
  }
}

/// `askChoice` — 2..4 chips, each optionally carrying a one-line trade-off
/// ([details], spec §2.3). `details` is absent on rows written before the
/// trade-off contract; when present it is parallel to [options].
class VanaChoicesPart extends VanaPart {
  const VanaChoicesPart({
    this.question,
    required this.options,
    this.details = const [],
  });

  final String? question;
  final List<String> options;

  /// Parallel to [options] once non-empty: one trade-off line per option, or
  /// `null` where the server sent none. Empty means no details at all.
  final List<String?> details;

  /// Any option carries a trade-off line — the renderer switches from a
  /// [Wrap] of chips to full-width two-line rows.
  bool get hasDetails => details.any((d) => d != null && d.isNotEmpty);

  /// The detail for [options] at [index], `null` when absent.
  String? detailAt(int index) => index < details.length ? details[index] : null;

  @override
  String get kind => 'choices';

  factory VanaChoicesPart.fromJson(Map<String, dynamic> json) {
    final options = readStringList(json, 'options');
    return VanaChoicesPart(
      question: readString(json, 'question'),
      options: options,
      details: _readDetails(json['details'], options.length),
    );
  }

  /// Lenient: a missing or short list pads with `null`s to [length];
  /// non-string entries read as `null`; anything that is not a list means
  /// no details.
  static List<String?> _readDetails(Object? raw, int length) {
    if (raw is! List) return const [];
    return List<String?>.unmodifiable([
      for (var i = 0; i < length; i++)
        if (i < raw.length && raw[i] is String) raw[i] as String else null,
    ]);
  }

  @override
  Map<String, dynamic> toJson() => {
    'kind': kind,
    if (question != null) 'question': question,
    'options': options,
    if (hasDetails) 'details': details,
  };

  VanaChoicesPart copyWith({
    String? question,
    List<String>? options,
    List<String?>? details,
  }) => VanaChoicesPart(
    question: question ?? this.question,
    options: options ?? this.options,
    details: details ?? this.details,
  );
}

/// `suggestMeals` — a carousel of [MealRef]s to pick from.
class VanaMealPickerPart extends VanaPart {
  const VanaMealPickerPart({
    required this.title,
    this.mealType,
    required this.meals,
    this.multi = false,
    this.defaultServings = 4,
  });

  final String title;
  final MealType? mealType;
  final List<MealRef> meals;
  final bool multi;
  final int defaultServings;

  @override
  String get kind => 'meal_picker';

  factory VanaMealPickerPart.fromJson(Map<String, dynamic> json) =>
      VanaMealPickerPart(
        title: readString(json, 'title') ?? '',
        mealType: MealType.fromWire(readString(json, 'mealType')),
        meals: readRecordList(json, 'meals', MealRef.fromJson),
        multi: readBool(json, 'multi') ?? false,
        defaultServings: readInt(json, 'defaultServings') ?? 4,
      );

  @override
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'title': title,
    if (mealType != null) 'mealType': mealType!.wire,
    'meals': meals.map((m) => m.toJson()).toList(),
    'multi': multi,
    'defaultServings': defaultServings,
  };

  VanaMealPickerPart copyWith({
    String? title,
    MealType? mealType,
    List<MealRef>? meals,
    bool? multi,
    int? defaultServings,
  }) => VanaMealPickerPart(
    title: title ?? this.title,
    mealType: mealType ?? this.mealType,
    meals: meals ?? this.meals,
    multi: multi ?? this.multi,
    defaultServings: defaultServings ?? this.defaultServings,
  );
}

/// `diagnoseStaples` — suggest only; nothing is added until tapped.
class VanaStaplesPart extends VanaPart {
  const VanaStaplesPart({
    required this.meals,
    this.planCarbsPerDay,
    this.targetCarbsPerDay,
    this.covered,
    this.of,
  });

  final List<StapleMeal> meals;
  final int? planCarbsPerDay;
  final int? targetCarbsPerDay;
  final int? covered;
  final int? of;

  @override
  String get kind => 'staples';

  factory VanaStaplesPart.fromJson(Map<String, dynamic> json) =>
      VanaStaplesPart(
        meals: readRecordList(json, 'meals', StapleMeal.fromJson),
        planCarbsPerDay: readInt(json, 'planCarbsPerDay'),
        targetCarbsPerDay: readInt(json, 'targetCarbsPerDay'),
        covered: readInt(json, 'covered'),
        of: readInt(json, 'of'),
      );

  @override
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'meals': meals.map((m) => m.toJson()).toList(),
    if (planCarbsPerDay != null) 'planCarbsPerDay': planCarbsPerDay,
    if (targetCarbsPerDay != null) 'targetCarbsPerDay': targetCarbsPerDay,
    if (covered != null) 'covered': covered,
    if (of != null) 'of': of,
  };

  VanaStaplesPart copyWith({
    List<StapleMeal>? meals,
    int? planCarbsPerDay,
    int? targetCarbsPerDay,
    int? covered,
    int? of,
  }) => VanaStaplesPart(
    meals: meals ?? this.meals,
    planCarbsPerDay: planCarbsPerDay ?? this.planCarbsPerDay,
    targetCarbsPerDay: targetCarbsPerDay ?? this.targetCarbsPerDay,
    covered: covered ?? this.covered,
    of: of ?? this.of,
  );
}

/// `updateBatch` / `getBatch` — not rendered inline; folded into plan state.
class VanaBatchPart extends VanaPart {
  const VanaBatchPart({required this.plan});

  final MealPlan plan;

  @override
  String get kind => 'batch';

  factory VanaBatchPart.fromJson(Map<String, dynamic> json) =>
      VanaBatchPart(plan: MealPlan.fromJson(requireJsonMap(json, 'plan')));

  @override
  Map<String, dynamic> toJson() => {'kind': kind, 'plan': plan.toJson()};

  VanaBatchPart copyWith({MealPlan? plan}) =>
      VanaBatchPart(plan: plan ?? this.plan);
}

/// `proposeRule`.
class VanaRulePart extends VanaPart {
  const VanaRulePart({required this.rule, this.meal});

  final PlanRule rule;
  final MealRef? meal;

  @override
  String get kind => 'rule';

  factory VanaRulePart.fromJson(Map<String, dynamic> json) => VanaRulePart(
    rule: PlanRule.fromJson(requireJsonMap(json, 'rule')),
    meal: switch (asJsonMap(json['meal'])) {
      final map? => MealRef.fromJson(map),
      null => null,
    },
  );

  @override
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'rule': rule.toJson(),
    if (meal != null) 'meal': meal!.toJson(),
  };

  VanaRulePart copyWith({PlanRule? rule, MealRef? meal}) =>
      VanaRulePart(rule: rule ?? this.rule, meal: meal ?? this.meal);
}

/// `shoppingList` — inline `ConfirmedCard` / the Shopping tab.
class VanaShoppingListPart extends VanaPart {
  const VanaShoppingListPart({
    required this.items,
    required this.itemCount,
    this.skipped = const [],
  });

  final List<ShoppingItem> items;

  /// Items not marked `have`.
  final int itemCount;

  /// Names of items left off because the athlete already has them.
  final List<String> skipped;

  @override
  String get kind => 'shopping_list';

  /// Build from items the way the server's `shop()` helper does.
  factory VanaShoppingListPart.fromItems(List<ShoppingItem> items) =>
      VanaShoppingListPart(
        items: items,
        itemCount: items.where((i) => !i.have).length,
        skipped: [
          for (final i in items)
            if (i.have) i.name,
        ],
      );

  factory VanaShoppingListPart.fromJson(Map<String, dynamic> json) =>
      VanaShoppingListPart(
        items: readRecordList(json, 'items', ShoppingItem.fromJson),
        itemCount: readInt(json, 'itemCount') ?? 0,
        skipped: readStringList(json, 'skipped'),
      );

  @override
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'items': items.map((i) => i.toJson()).toList(),
    'itemCount': itemCount,
    'skipped': skipped,
  };

  VanaShoppingListPart copyWith({
    List<ShoppingItem>? items,
    int? itemCount,
    List<String>? skipped,
  }) => VanaShoppingListPart(
    items: items ?? this.items,
    itemCount: itemCount ?? this.itemCount,
    skipped: skipped ?? this.skipped,
  );
}

/// `dayGuidance` — deterministic from budget + workouts + library contexts.
class VanaDayGuidancePart extends VanaPart {
  const VanaDayGuidancePart({
    required this.date,
    required this.label,
    this.workout,
    required this.minCarbsG,
    required this.note,
    this.suggestions = const [],
  });

  /// `YYYY-MM-DD`.
  final String date;
  final String label;
  final String? workout;
  final int minCarbsG;
  final String note;
  final List<MealRef> suggestions;

  @override
  String get kind => 'day_guidance';

  factory VanaDayGuidancePart.fromJson(Map<String, dynamic> json) =>
      VanaDayGuidancePart(
        date: requireString(json, 'date'),
        label: readString(json, 'label') ?? '',
        workout: readString(json, 'workout'),
        minCarbsG: readInt(json, 'minCarbsG') ?? 0,
        note: readString(json, 'note') ?? '',
        suggestions: readRecordList(json, 'suggestions', MealRef.fromJson),
      );

  @override
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'date': date,
    'label': label,
    'workout': workout,
    'minCarbsG': minCarbsG,
    'note': note,
    'suggestions': suggestions.map((m) => m.toJson()).toList(),
  };

  VanaDayGuidancePart copyWith({
    String? date,
    String? label,
    String? workout,
    int? minCarbsG,
    String? note,
    List<MealRef>? suggestions,
  }) => VanaDayGuidancePart(
    date: date ?? this.date,
    label: label ?? this.label,
    workout: workout ?? this.workout,
    minCarbsG: minCarbsG ?? this.minCarbsG,
    note: note ?? this.note,
    suggestions: suggestions ?? this.suggestions,
  );
}

/// `rememberFact`.
class VanaMemorySavedPart extends VanaPart {
  const VanaMemorySavedPart({required this.memory});

  final UserMemory memory;

  @override
  String get kind => 'memory_saved';

  factory VanaMemorySavedPart.fromJson(Map<String, dynamic> json) =>
      VanaMemorySavedPart(
        memory: UserMemory.fromJson(requireJsonMap(json, 'memory')),
      );

  @override
  Map<String, dynamic> toJson() => {'kind': kind, 'memory': memory.toJson()};

  VanaMemorySavedPart copyWith({UserMemory? memory}) =>
      VanaMemorySavedPart(memory: memory ?? this.memory);
}

/// `logFromPlan`.
class VanaLoggedPart extends VanaPart {
  const VanaLoggedPart({
    required this.planMealId,
    required this.name,
    required this.servingsLeft,
  });

  final String planMealId;
  final String name;
  final int servingsLeft;

  @override
  String get kind => 'logged';

  factory VanaLoggedPart.fromJson(Map<String, dynamic> json) => VanaLoggedPart(
    planMealId: requireString(json, 'planMealId'),
    name: readString(json, 'name') ?? '',
    servingsLeft: readInt(json, 'servingsLeft') ?? 0,
  );

  @override
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'planMealId': planMealId,
    'name': name,
    'servingsLeft': servingsLeft,
  };

  VanaLoggedPart copyWith({
    String? planMealId,
    String? name,
    int? servingsLeft,
  }) => VanaLoggedPart(
    planMealId: planMealId ?? this.planMealId,
    name: name ?? this.name,
    servingsLeft: servingsLeft ?? this.servingsLeft,
  );
}

/// `planDay` / `setDaySlot` — the Plan tab's day grid.
class VanaDayPart extends VanaPart {
  const VanaDayPart({
    required this.date,
    required this.label,
    required this.slots,
    this.filled = const [],
  });

  final String date;
  final String label;
  final DayPlan slots;

  /// Slots this call filled (empty for a clear).
  final List<MealType> filled;

  @override
  String get kind => 'day';

  factory VanaDayPart.fromJson(Map<String, dynamic> json) => VanaDayPart(
    date: requireString(json, 'date'),
    label: readString(json, 'label') ?? '',
    slots: DayPlan.fromJson(
      asJsonMap(json['slots']) ?? const <String, dynamic>{},
    ),
    filled: List.unmodifiable(
      readStringList(
        json,
        'filled',
      ).map(MealType.fromWire).whereType<MealType>(),
    ),
  );

  @override
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'date': date,
    'label': label,
    'slots': slots.toJson(),
    'filled': filled.map((s) => s.wire).toList(),
  };

  VanaDayPart copyWith({
    String? date,
    String? label,
    DayPlan? slots,
    List<MealType>? filled,
  }) => VanaDayPart(
    date: date ?? this.date,
    label: label ?? this.label,
    slots: slots ?? this.slots,
    filled: filled ?? this.filled,
  );
}

/// `weeklyBrief` — **legacy**. Still parsed so old history rows load, but
/// the UI does not render it (contract 02 §3).
class VanaBriefPart extends VanaPart {
  const VanaBriefPart({
    required this.text,
    this.chips = const [],
    this.cites = const [],
  });

  final String text;
  final List<String> chips;
  final List<String> cites;

  @override
  String get kind => 'brief';

  factory VanaBriefPart.fromJson(Map<String, dynamic> json) => VanaBriefPart(
    text: readString(json, 'text') ?? '',
    chips: readStringList(json, 'chips'),
    cites: readStringList(json, 'cites'),
  );

  @override
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'text': text,
    'chips': chips,
    'cites': cites,
  };

  VanaBriefPart copyWith({
    String? text,
    List<String>? chips,
    List<String>? cites,
  }) => VanaBriefPart(
    text: text ?? this.text,
    chips: chips ?? this.chips,
    cites: cites ?? this.cites,
  );
}

/// Where a `pantry` part's items came from — a suggestion seeded from the
/// athlete's history, or a fridge photo's ingredient detection (plan
/// Phase 7).
enum PantryOrigin {
  suggested('suggested'),
  photo('photo');

  const PantryOrigin(this.wire);

  final String wire;

  static PantryOrigin? fromWire(String? value) {
    if (value == null) return null;
    for (final v in PantryOrigin.values) {
      if (v.wire == value) return v;
    }
    return null;
  }
}

/// One tickable row of a `pantry` part — `{name, selected}`.
class PantryItem extends WireRecord {
  const PantryItem({required this.name, this.selected = false});

  final String name;
  final bool selected;

  factory PantryItem.fromJson(Map<String, dynamic> json) => PantryItem(
    name: requireString(json, 'name'),
    selected: readBool(json, 'selected') ?? false,
  );

  @override
  Map<String, dynamic> toJson() => {'name': name, 'selected': selected};

  PantryItem copyWith({String? name, bool? selected}) =>
      PantryItem(name: name ?? this.name, selected: selected ?? this.selected);
}

/// `askPantry` / fridge-photo detection — a multi-select grid of what is in
/// the house (plan Phase 7): `{ title, items[{name, selected}], allowCustom,
/// origin }`. The athlete ticks, adds, then "Use these".
class VanaPantryPart extends VanaPart {
  const VanaPantryPart({
    this.title,
    required this.items,
    this.allowCustom = true,
    this.origin = PantryOrigin.suggested,
  });

  final String? title;
  final List<PantryItem> items;

  /// Whether the trailing `+` chip (custom entry) shows.
  final bool allowCustom;
  final PantryOrigin origin;

  /// The pre-ticked names, in wire order.
  List<String> get selectedNames => [
    for (final item in items)
      if (item.selected) item.name,
  ];

  @override
  String get kind => 'pantry';

  factory VanaPantryPart.fromJson(Map<String, dynamic> json) => VanaPantryPart(
    title: readString(json, 'title'),
    items: readRecordList(json, 'items', PantryItem.fromJson),
    allowCustom: readBool(json, 'allowCustom') ?? true,
    origin:
        PantryOrigin.fromWire(readString(json, 'origin')) ??
        PantryOrigin.suggested,
  );

  @override
  Map<String, dynamic> toJson() => {
    'kind': kind,
    if (title != null) 'title': title,
    'items': items.map((i) => i.toJson()).toList(),
    'allowCustom': allowCustom,
    'origin': origin.wire,
  };

  VanaPantryPart copyWith({
    String? title,
    List<PantryItem>? items,
    bool? allowCustom,
    PantryOrigin? origin,
  }) => VanaPantryPart(
    title: title ?? this.title,
    items: items ?? this.items,
    allowCustom: allowCustom ?? this.allowCustom,
    origin: origin ?? this.origin,
  );
}

/// The Phase 8 "lay these across the week" result — a column of `day`
/// parts (`{ days: VanaDayPart[] }`), rendered read-only with a way into
/// the Plan tab.
class VanaWeekPart extends VanaPart {
  const VanaWeekPart({required this.days});

  final List<VanaDayPart> days;

  @override
  String get kind => 'week';

  factory VanaWeekPart.fromJson(Map<String, dynamic> json) =>
      VanaWeekPart(days: readRecordList(json, 'days', VanaDayPart.fromJson));

  @override
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'days': days.map((d) => d.toJson()).toList(),
  };

  VanaWeekPart copyWith({List<VanaDayPart>? days}) =>
      VanaWeekPart(days: days ?? this.days);
}

/// `recordDebrief` — how last week went (plan Phase 3.3): `{ planId,
/// completed, planned, skipReason, memories }`. [memories] are the distilled
/// `rememberFact` rows (each with `source: 'debrief'`).
class VanaDebriefPart extends VanaPart {
  const VanaDebriefPart({
    required this.planId,
    required this.completed,
    required this.planned,
    this.skipReason,
    this.memories = const [],
  });

  final String planId;
  final int completed;
  final int planned;
  final String? skipReason;
  final List<UserMemory> memories;

  @override
  String get kind => 'debrief';

  factory VanaDebriefPart.fromJson(Map<String, dynamic> json) =>
      VanaDebriefPart(
        planId: requireString(json, 'planId'),
        completed: readInt(json, 'completed') ?? 0,
        planned: readInt(json, 'planned') ?? 0,
        skipReason: readString(json, 'skipReason'),
        memories: readRecordList(json, 'memories', UserMemory.fromJson),
      );

  @override
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'planId': planId,
    'completed': completed,
    'planned': planned,
    'skipReason': skipReason,
    'memories': memories.map((m) => m.toJson()).toList(),
  };

  VanaDebriefPart copyWith({
    String? planId,
    int? completed,
    int? planned,
    String? skipReason,
    List<UserMemory>? memories,
  }) => VanaDebriefPart(
    planId: planId ?? this.planId,
    completed: completed ?? this.completed,
    planned: planned ?? this.planned,
    skipReason: skipReason ?? this.skipReason,
    memories: memories ?? this.memories,
  );
}
