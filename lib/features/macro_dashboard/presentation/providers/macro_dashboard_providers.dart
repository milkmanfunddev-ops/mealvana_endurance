import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/services/preferences_service.dart';
import '../../../activities/presentation/providers/activities_controller.dart';
import '../../../calendar/presentation/providers/calendar_selected_date_provider.dart';
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
  final trackingOn = ref.watch(
    macroDashboardViewProvider.select((s) => s.trackingOn),
  );

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
    targets: macrosState.dailyMacros,
    consumed: consumed,
    trackingOn: trackingOn,
  );
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
