import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/services/preferences_service.dart';
import '../../domain/fuel_timeline_filter.dart';

/// Ephemeral view state for the Fuel Timeline screen — the bits that are pure
/// UI and don't belong in the data controller: the active filter, whether the
/// energy dashboard is expanded, and whether the left time rail is shown.
///
/// `trackingOn` is sourced here with a default of `true` for now; Phase 5 moves
/// it to a global [PreferencesService]-backed value. Keeping it on this state
/// object means the screen reads a single source of truth either way.
class FuelTimelineViewState {
  const FuelTimelineViewState({
    this.filter = FuelTimelineFilter.all,
    this.dashOpen = false,
    this.timelineOpen = true,
    this.trackingOn = true,
    this.expandedNodeId,
  });

  final FuelTimelineFilter filter;
  final bool dashOpen;
  final bool timelineOpen;
  final bool trackingOn;

  /// The id of the timeline node whose inline actions (Swap/Remove) are open,
  /// or null when none is expanded. Only one expands at a time.
  final String? expandedNodeId;

  FuelTimelineViewState copyWith({
    FuelTimelineFilter? filter,
    bool? dashOpen,
    bool? timelineOpen,
    bool? trackingOn,
    String? expandedNodeId,
    bool clearExpanded = false,
  }) {
    return FuelTimelineViewState(
      filter: filter ?? this.filter,
      dashOpen: dashOpen ?? this.dashOpen,
      timelineOpen: timelineOpen ?? this.timelineOpen,
      trackingOn: trackingOn ?? this.trackingOn,
      expandedNodeId: clearExpanded
          ? null
          : (expandedNodeId ?? this.expandedNodeId),
    );
  }
}

final fuelTimelineViewProvider =
    NotifierProvider<FuelTimelineViewNotifier, FuelTimelineViewState>(
      FuelTimelineViewNotifier.new,
    );

class FuelTimelineViewNotifier extends Notifier<FuelTimelineViewState> {
  @override
  FuelTimelineViewState build() {
    // Seed tracking from the persisted global preference (default ON).
    final trackingOn = ref.read(preferencesServiceProvider).fuelTrackingEnabled;
    return FuelTimelineViewState(trackingOn: trackingOn);
  }

  void setFilter(FuelTimelineFilter filter) =>
      state = state.copyWith(filter: filter, clearExpanded: true);

  void toggleDash() => state = state.copyWith(dashOpen: !state.dashOpen);

  void toggleTimeline() =>
      state = state.copyWith(timelineOpen: !state.timelineOpen);

  void toggleTracking() {
    final next = !state.trackingOn;
    state = state.copyWith(trackingOn: next);
    // Persist globally (fire-and-forget); the seed in build() reads it back.
    ref.read(preferencesServiceProvider).setFuelTrackingEnabled(next);
  }

  /// Toggle the inline-actions row for [nodeId]; collapses if already open.
  void toggleExpanded(String nodeId) {
    state = state.expandedNodeId == nodeId
        ? state.copyWith(clearExpanded: true)
        : state.copyWith(expandedNodeId: nodeId);
  }

  void collapseExpanded() => state = state.copyWith(clearExpanded: true);
}
