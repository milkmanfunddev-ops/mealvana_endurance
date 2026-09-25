/// Presentation models for the loading-day dashboard surfaces.
///
/// Design SSOT: docs/ssot/spec/design/surfaces/carb-loading-dashboard.md
/// (CD-1..6), components/carb-slot-card.md, components/energy-card.md
/// §LOAD-face amendment (Q-D9 form). Numbers authority:
/// docs/ssot/spec/fueling/carb-loading.md — every quantity here arrives
/// pre-derived through [CarbLoadingPaceEngine]; these models invent no
/// arithmetic (P-3/S-3), and every string is the §2a copy register's,
/// verbatim.
library;

import '../../carb_loading/domain/carb_loading_pace_engine.dart';
import '../../carb_loading/domain/meal_type.dart';

export '../../carb_loading/domain/carb_loading_pace_engine.dart'
    show CarbDayRel;

/// The LOAD face's render data (energy-card.md §LOAD-face, Q-D9 form:
/// collapsed loader row + admitted expansion).
class CarbLoadFaceData {
  const CarbLoadFaceData({
    required this.labelLine,
    required this.paceMainStr,
    required this.paceSubStr,
    required this.paceMainIsWord,
    required this.fillFrac,
    required this.tickFrac,
    required this.tickHidden,
    required this.loaded,
    required this.dayRel,
    required this.eatenOfTargetStr,
    required this.toGoStr,
    required this.paceByNowStr,
  });

  /// `CARB LOAD · DAY 2 OF 3`, flipping to `LOADED · …` on completion (CD-5).
  final String labelLine;

  /// Register v1: `31 g` / `On pace` / `Loaded` / `680 g` (future) /
  /// `521 g` (past).
  final String paceMainStr;

  /// Register v1: `behind pace` / `ahead of pace` / `322 of 544 g` /
  /// `planned` / `of 544 g`.
  final String paceSubStr;

  /// True when [paceMainStr] is a word (`On pace` / `Loaded`) — the
  /// reference renders words a step smaller than gram values.
  final bool paceMainIsWord;

  /// Loader fill 0..1 (engine `fillFrac`, CL-9).
  final double fillFrac;

  /// Pace-tick position 0..1, or null when the tick is hidden.
  final double? tickFrac;
  final bool tickHidden;
  final bool loaded;
  final CarbDayRel dayRel;

  /// Expanded face (Q-D9): `295 of 544 g`.
  final String eatenOfTargetStr;

  /// Registered form `N g to go`, to-go = max(target − eaten, 0).
  final String toGoStr;

  /// Registered form `pace N g by now`, or null when no pace is owed
  /// (pre-window, loaded, or off-today).
  final String? paceByNowStr;
}

/// One receipt row inside a slot card's peek (carb-slot-card.md).
class CarbSlotItemData {
  const CarbSlotItemData({
    required this.id,
    required this.name,
    required this.gramsStr,
  });

  final String id;
  final String name;

  /// Whole-gram carbs for the receipt row (`58 g`).
  final String gramsStr;
}

/// One loading-day slot card (carb-slot-card.md): a gauge and a door.
class CarbSlotCardData {
  const CarbSlotCardData({
    required this.slot,
    required this.label,
    required this.clockStr,
    required this.eatenG,
    required this.targetG,
    required this.items,
    required this.summaryLine,
    required this.dayRel,
  });

  final MealType slot;
  final String label;

  /// CL-5 grid clock: `6:00 AM` … `9:00 PM`.
  final String clockStr;

  /// Whole grams; may EXCEED [targetG] — no clamp, no warning state.
  final int eatenG;
  final int targetG;

  /// Receipt rows, logging order. Their grams sum to [eatenG] exactly
  /// (a mismatch is a red, not a rounding allowance).
  final List<CarbSlotItemData> items;

  /// Summary-line register: 1 → `<Name>` · 2 → `<A> + <B>` · ≥3 →
  /// `<First> +N more`. Empty string when [isEmpty].
  final String summaryLine;
  final CarbDayRel dayRel;

  bool get isEmpty => items.isEmpty;

  /// Header figure: `124 / 136 g` (or `0 / 136 g` when empty).
  String get headerFigure => '$eatenG / $targetG g';
}

/// One BY MEAL row on the breakdown page.
class CarbBreakdownMealRow {
  const CarbBreakdownMealRow({
    required this.label,
    required this.clockStr,
    required this.eatenG,
    required this.targetG,
    required this.fillFrac,
    required this.isCurrentWindow,
  });

  final String label;
  final String clockStr;
  final int eatenG;
  final int targetG;

  /// min(1, eaten/target) for the mini bar.
  final double fillFrac;

  /// True only on today, for the slot whose window contains now.
  final bool isCurrentWindow;
}

/// One PROTOCOL chip on the breakdown page (CD-6: chips navigate).
class CarbBreakdownDayChip {
  const CarbBreakdownDayChip({
    required this.label,
    required this.targetStr,
    required this.date,
    required this.isViewed,
  });

  final String label;
  final String targetStr;
  final DateTime date;
  final bool isViewed;
}

/// The read-only breakdown page's data (E2 destination on LOAD).
class CarbBreakdownData {
  const CarbBreakdownData({
    required this.titleLine,
    required this.face,
    required this.eatenOfTargetStr,
    required this.carbsStr,
    required this.proteinStr,
    required this.fatStr,
    required this.kcalStr,
    required this.mealRows,
    required this.dayChips,
  });

  /// `Carb Load · Day 2 of 3`.
  final String titleLine;
  final CarbLoadFaceData face;

  /// `295 of 544 g carbs`.
  final String eatenOfTargetStr;

  // Macro strip (D7 named exception: the carbs figure renders in
  // electrolyte on THIS strip — tokens.md Q-D3 exception).
  final String carbsStr;
  final String proteinStr;
  final String fatStr;
  final String kcalStr;

  final List<CarbBreakdownMealRow> mealRows;
  final List<CarbBreakdownDayChip> dayChips;
}

/// Everything the dashboard needs on a loading day (CD-1: on a regular day
/// this whole object is null and NO carb surface exists in the DOM).
class CarbDashboardData {
  const CarbDashboardData({
    required this.face,
    required this.slots,
    required this.breakdown,
    required this.dayRel,
    required this.eventId,
  });

  final CarbLoadFaceData face;

  /// The six slot cards, CL-5 order (CD-3: these ARE the loading-day meal
  /// timeline; no Recovery group).
  final List<CarbSlotCardData> slots;
  final CarbBreakdownData breakdown;
  final CarbDayRel dayRel;

  /// The owning event — the CE-7 `Manage plan ›` footer navigates to its
  /// plan summary.
  final String? eventId;
}
