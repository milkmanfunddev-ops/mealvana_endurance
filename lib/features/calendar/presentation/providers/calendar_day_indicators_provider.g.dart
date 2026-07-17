// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_day_indicators_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Per-day calendar dots: which days have an activity, an event, and/or a
/// carb-loading day.
///
/// This is the aggregation that the old `ActivitiesListScreen` computed inline
/// in `_buildDayIndicatorsMap`. When the home tab was swapped to
/// `FuelTimelineScreen`, that screen was left passing `dayIndicators: const {}`
/// to its month view — so events, activities, and carb-loading days stopped
/// showing dots entirely. Extracted here as a single provider so every calendar
/// surface reads the same source of truth rather than re-deriving it (or, as it
/// happened, not deriving it at all).
///
/// Keyed by date-only (year/month/day). Errors in any one source are skipped
/// via `whenData` so a single failing provider doesn't blank all the dots.

@ProviderFor(calendarDayIndicators)
const calendarDayIndicatorsProvider = CalendarDayIndicatorsProvider._();

/// Per-day calendar dots: which days have an activity, an event, and/or a
/// carb-loading day.
///
/// This is the aggregation that the old `ActivitiesListScreen` computed inline
/// in `_buildDayIndicatorsMap`. When the home tab was swapped to
/// `FuelTimelineScreen`, that screen was left passing `dayIndicators: const {}`
/// to its month view — so events, activities, and carb-loading days stopped
/// showing dots entirely. Extracted here as a single provider so every calendar
/// surface reads the same source of truth rather than re-deriving it (or, as it
/// happened, not deriving it at all).
///
/// Keyed by date-only (year/month/day). Errors in any one source are skipped
/// via `whenData` so a single failing provider doesn't blank all the dots.

final class CalendarDayIndicatorsProvider
    extends
        $FunctionalProvider<
          Map<DateTime, Set<DayIndicatorType>>,
          Map<DateTime, Set<DayIndicatorType>>,
          Map<DateTime, Set<DayIndicatorType>>
        >
    with $Provider<Map<DateTime, Set<DayIndicatorType>>> {
  /// Per-day calendar dots: which days have an activity, an event, and/or a
  /// carb-loading day.
  ///
  /// This is the aggregation that the old `ActivitiesListScreen` computed inline
  /// in `_buildDayIndicatorsMap`. When the home tab was swapped to
  /// `FuelTimelineScreen`, that screen was left passing `dayIndicators: const {}`
  /// to its month view — so events, activities, and carb-loading days stopped
  /// showing dots entirely. Extracted here as a single provider so every calendar
  /// surface reads the same source of truth rather than re-deriving it (or, as it
  /// happened, not deriving it at all).
  ///
  /// Keyed by date-only (year/month/day). Errors in any one source are skipped
  /// via `whenData` so a single failing provider doesn't blank all the dots.
  const CalendarDayIndicatorsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'calendarDayIndicatorsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$calendarDayIndicatorsHash();

  @$internal
  @override
  $ProviderElement<Map<DateTime, Set<DayIndicatorType>>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Map<DateTime, Set<DayIndicatorType>> create(Ref ref) {
    return calendarDayIndicators(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<DateTime, Set<DayIndicatorType>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<Map<DateTime, Set<DayIndicatorType>>>(value),
    );
  }
}

String _$calendarDayIndicatorsHash() =>
    r'63182bc596681ef80d0ec2c7eba1abeba0da5965';
