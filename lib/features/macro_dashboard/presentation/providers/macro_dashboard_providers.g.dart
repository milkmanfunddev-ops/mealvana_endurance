// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'macro_dashboard_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Assembles the macro-dashboard day view from existing data sources —
/// composition, not refetching (same pattern as fuelTimelineDay). A card
/// state change flows: gesture → activities controller (optimistic) → this
/// provider recomputes → the WHOLE dashboard rebuilds in the same pump —
/// surface rule S-1, never a local repaint.

@ProviderFor(macroDashboardDay)
const macroDashboardDayProvider = MacroDashboardDayProvider._();

/// Assembles the macro-dashboard day view from existing data sources —
/// composition, not refetching (same pattern as fuelTimelineDay). A card
/// state change flows: gesture → activities controller (optimistic) → this
/// provider recomputes → the WHOLE dashboard rebuilds in the same pump —
/// surface rule S-1, never a local repaint.

final class MacroDashboardDayProvider
    extends
        $FunctionalProvider<
          AsyncValue<DashboardData>,
          DashboardData,
          FutureOr<DashboardData>
        >
    with $FutureModifier<DashboardData>, $FutureProvider<DashboardData> {
  /// Assembles the macro-dashboard day view from existing data sources —
  /// composition, not refetching (same pattern as fuelTimelineDay). A card
  /// state change flows: gesture → activities controller (optimistic) → this
  /// provider recomputes → the WHOLE dashboard rebuilds in the same pump —
  /// surface rule S-1, never a local repaint.
  const MacroDashboardDayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'macroDashboardDayProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$macroDashboardDayHash();

  @$internal
  @override
  $FutureProviderElement<DashboardData> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DashboardData> create(Ref ref) {
    return macroDashboardDay(ref);
  }
}

String _$macroDashboardDayHash() => r'00ac85a37c17e5b12c32518edca4056a27aa1f0f';
