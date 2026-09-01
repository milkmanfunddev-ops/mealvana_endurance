import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/providers/user_id_provider.dart';
import '../../../../shared/services/preferences_service.dart';
import '../../../activities/presentation/providers/activities_controller.dart';
import '../../../auth/data/user_repository.dart';
import '../../../calendar/presentation/providers/calendar_selected_date_provider.dart';
import '../../../daily_macros/domain/daily_macro_targets.dart';
import '../../../daily_macros/presentation/providers/daily_macros_controller.dart';
import '../../../meal_logging/presentation/providers/meal_log_providers.dart';
import '../../application/dashboard_assembler.dart';
import '../../domain/dashboard_models.dart';

part 'macro_dashboard_providers.g.dart';

/// Assembles the macro-dashboard day view from existing data sources —
/// composition, not refetching (same pattern as fuelTimelineDay). A card
/// state change flows: gesture → activities controller (optimistic) → this
/// provider recomputes → the WHOLE dashboard rebuilds in the same pump —
/// surface rule S-1, never a local repaint.
@riverpod
Future<DashboardData> macroDashboardDay(Ref ref) async {
  final selectedDate = ref.watch(calendarSelectedDateProvider);
  final dateStr = _ymd(selectedDate);

  final macrosState = await ref.watch(dailyMacrosControllerProvider.future);
  final meals = await ref.watch(mealLogsForDateProvider(dateStr).future);
  final consumed = await ref.watch(
    consumedTotalsForDateProvider(dateStr).future,
  );
  final allActivities = await ref.watch(activitiesControllerProvider.future);

  // S-1 "same pump" across a targets recompute: a skip / unskip / manual
  // profile edit invalidates the day's cached targets by design, and the
  // daily-macros controller then reports `dailyMacros: null, isCalculating:
  // true` until the edge function answers. Rendering that null would blank
  // the energy card for the round trip and repaint it a second later — the
  // flicker class fixed in 3ca2ee27. Hold the last targets this surface
  // showed for the SAME user+day while (and only while) a recompute is in
  // flight; a genuine "no targets" (error, never computed) still renders none.
  final userId = await ref.watch(userIdProvider.future);
  final targets = HeldTargets.resolve(
    userId,
    dateStr,
    current: macrosState.dailyMacros,
    weekly: macrosState.weeklyMacros,
    calculating: macrosState.isCalculating,
  );

  // Bug 2026-08-20-dashboard-weight-fallback-70kg: hand the assembler the
  // athlete's live profile weight so formula-rung session kcal are priced at
  // the ATHLETE's body weight (F4 is exactly linear in weight — I6). The
  // assembler prefers this value, falls back to the weight the engine
  // calculated with (targets.weightKg), and with neither surfaces the
  // absence instead of inventing a number. A weight edit reaches here
  // because a manual engine-input change invalidates
  // dailyMacrosControllerProvider (Q-016 path), which this provider watches.
  double? profileWeightKg;
  try {
    final userRepository = await ref.watch(userRepositoryProvider.future);
    final profile = await userRepository.getCurrentUser();
    final weightPounds = profile?.weightPounds ?? 0;
    if (weightPounds > 0) {
      // Same lb→kg factor the engine payload uses (daily_macro_service).
      profileWeightKg = weightPounds * 0.453592;
    }
  } catch (_) {
    // Profile unreachable → leave null; the assembler's fallback chain
    // (targets.weightKg → honest absence) keeps the surface truthful, and a
    // profile read failure must not take the whole dashboard down.
  }

  bool onSelectedDay(DateTime d) =>
      d.year == selectedDate.year &&
      d.month == selectedDate.month &&
      d.day == selectedDate.day;

  final dayActivities = allActivities
      .where((a) => onSelectedDay(a.displayTime))
      .toList(growable: false);

  const assembler = MacroDashboardAssembler();
  return assembler.assemble(
    selectedDate: selectedDate,
    now: DateTime.now(),
    activities: dayActivities,
    meals: meals,
    targets: targets.daily,
    consumed: consumed,
    weeklyTargets: targets.weekly,
    profileWeightKg: profileWeightKg,
    // Tracking is a DISPLAY mode gated by the screen from the view state —
    // toggling it must not recompute the day (intraday-display §5).
    trackingOn: true,
  );
}

/// The last targets the dashboard rendered, per user+day — see the note in
/// [macroDashboardDay]. Module-level on purpose: the value must outlive the
/// auto-dispose day provider's rebuilds. Keyed by the signed-in user id, so
/// an account switch can never surface another account's plan.
class HeldTargets {
  HeldTargets._();

  static final Map<String, _Held> _held = {};

  static ({DailyMacroTargets? daily, List<DailyMacroTargets?> weekly}) resolve(
    String userId,
    String dateKey, {
    required DailyMacroTargets? current,
    required List<DailyMacroTargets?> weekly,
    required bool calculating,
  }) {
    final key = '$userId:$dateKey';
    if (current != null) {
      _held[key] = _Held(current, weekly);
      return (daily: current, weekly: weekly);
    }
    if (calculating) {
      final held = _held[key];
      if (held != null) return (daily: held.daily, weekly: held.weekly);
    }
    return (daily: null, weekly: weekly);
  }

  /// Drop everything (tests; account switch).
  static void clear() => _held.clear();
}

class _Held {
  const _Held(this.daily, this.weekly);
  final DailyMacroTargets daily;
  final List<DailyMacroTargets?> weekly;
}

String _ymd(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

/// Ephemeral view state — filter lens, energy-card expansion, rail
/// visibility, tracking. The energy card's `expanded` lives HERE, not in the
/// card: P-1 requires it to survive face switches and any card state change
/// on the surface (S-4).
class MacroDashboardViewState {
  const MacroDashboardViewState({
    this.filter = DashboardFilter.all,
    this.dashOpen = false,
    this.timelineOpen = true,
    this.trackingOn = true,
    this.expandedMealId,
  });

  final DashboardFilter filter;
  final bool dashOpen;
  final bool timelineOpen;
  final bool trackingOn;
  final String? expandedMealId;

  MacroDashboardViewState copyWith({
    DashboardFilter? filter,
    bool? dashOpen,
    bool? timelineOpen,
    bool? trackingOn,
    String? expandedMealId,
    bool clearExpandedMeal = false,
  }) {
    return MacroDashboardViewState(
      filter: filter ?? this.filter,
      dashOpen: dashOpen ?? this.dashOpen,
      timelineOpen: timelineOpen ?? this.timelineOpen,
      trackingOn: trackingOn ?? this.trackingOn,
      expandedMealId: clearExpandedMeal
          ? null
          : (expandedMealId ?? this.expandedMealId),
    );
  }
}

final macroDashboardViewProvider =
    NotifierProvider<MacroDashboardViewNotifier, MacroDashboardViewState>(
      MacroDashboardViewNotifier.new,
    );

class MacroDashboardViewNotifier extends Notifier<MacroDashboardViewState> {
  @override
  MacroDashboardViewState build() {
    final trackingOn = ref.read(preferencesServiceProvider).fuelTrackingEnabled;
    return MacroDashboardViewState(trackingOn: trackingOn);
  }

  /// Face transition (E3): content swaps in place — expansion is NOT reset.
  void setFilter(DashboardFilter filter) =>
      state = state.copyWith(filter: filter, clearExpandedMeal: true);

  void toggleDash() => state = state.copyWith(dashOpen: !state.dashOpen);

  void toggleTimeline() =>
      state = state.copyWith(timelineOpen: !state.timelineOpen);

  /// Tracking-off is a display mode, never an engine mode (intraday §5).
  void toggleTracking() {
    final next = !state.trackingOn;
    state = state.copyWith(trackingOn: next);
    ref.read(preferencesServiceProvider).setFuelTrackingEnabled(next);
  }

  void toggleMealExpanded(String mealId) {
    state = state.expandedMealId == mealId
        ? state.copyWith(clearExpandedMeal: true)
        : state.copyWith(expandedMealId: mealId);
  }
}
