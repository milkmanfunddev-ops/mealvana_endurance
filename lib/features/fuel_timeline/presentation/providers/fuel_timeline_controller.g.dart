// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fuel_timeline_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Assembles the Fuel Timeline day view from existing data sources.
///
/// Composes (does not refetch) the calendar's selected date, the day's macro
/// targets, the day's meal logs + consumed totals, and the day's activities,
/// then runs the pure [DayTimelineAssembler]. Produces the full (unfiltered)
/// node list + energy summary; the screen applies the active filter for
/// display, so toggling the filter never re-runs this provider.
///
/// Per-activity burn (`burnByActivityId`) is wired in a later phase from the
/// per-activity macro targets; until then the energy summary's workout burn is
/// zero and only resting + daily-activity energy is shown.

@ProviderFor(fuelTimelineDay)
const fuelTimelineDayProvider = FuelTimelineDayProvider._();

/// Assembles the Fuel Timeline day view from existing data sources.
///
/// Composes (does not refetch) the calendar's selected date, the day's macro
/// targets, the day's meal logs + consumed totals, and the day's activities,
/// then runs the pure [DayTimelineAssembler]. Produces the full (unfiltered)
/// node list + energy summary; the screen applies the active filter for
/// display, so toggling the filter never re-runs this provider.
///
/// Per-activity burn (`burnByActivityId`) is wired in a later phase from the
/// per-activity macro targets; until then the energy summary's workout burn is
/// zero and only resting + daily-activity energy is shown.

final class FuelTimelineDayProvider
    extends
        $FunctionalProvider<
          AsyncValue<DayTimelineResult>,
          DayTimelineResult,
          FutureOr<DayTimelineResult>
        >
    with
        $FutureModifier<DayTimelineResult>,
        $FutureProvider<DayTimelineResult> {
  /// Assembles the Fuel Timeline day view from existing data sources.
  ///
  /// Composes (does not refetch) the calendar's selected date, the day's macro
  /// targets, the day's meal logs + consumed totals, and the day's activities,
  /// then runs the pure [DayTimelineAssembler]. Produces the full (unfiltered)
  /// node list + energy summary; the screen applies the active filter for
  /// display, so toggling the filter never re-runs this provider.
  ///
  /// Per-activity burn (`burnByActivityId`) is wired in a later phase from the
  /// per-activity macro targets; until then the energy summary's workout burn is
  /// zero and only resting + daily-activity energy is shown.
  const FuelTimelineDayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fuelTimelineDayProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fuelTimelineDayHash();

  @$internal
  @override
  $FutureProviderElement<DayTimelineResult> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DayTimelineResult> create(Ref ref) {
    return fuelTimelineDay(ref);
  }
}

String _$fuelTimelineDayHash() => r'dde604f8616b8fd4798edb9497f589ba600c77ef';
