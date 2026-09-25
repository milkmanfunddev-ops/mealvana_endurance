// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'carb_dashboard_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The loading-day surface data for one date, or null when the date falls in
/// no carb-loading plan — CD-1's negative: a regular day has NO carb surface
/// anywhere in the DOM.
///
/// Composition, not refetching (same shape as [macroDashboardDay]): a food
/// log write invalidates the meal-log providers, this recomputes, and every
/// carb surface — face, slot cards, slot page, breakdown — rebuilds in the
/// same pump (CD-2, the surface's core contract).

@ProviderFor(carbDashboardForDate)
const carbDashboardForDateProvider = CarbDashboardForDateFamily._();

/// The loading-day surface data for one date, or null when the date falls in
/// no carb-loading plan — CD-1's negative: a regular day has NO carb surface
/// anywhere in the DOM.
///
/// Composition, not refetching (same shape as [macroDashboardDay]): a food
/// log write invalidates the meal-log providers, this recomputes, and every
/// carb surface — face, slot cards, slot page, breakdown — rebuilds in the
/// same pump (CD-2, the surface's core contract).

final class CarbDashboardForDateProvider
    extends
        $FunctionalProvider<
          AsyncValue<CarbDashboardData?>,
          CarbDashboardData?,
          FutureOr<CarbDashboardData?>
        >
    with
        $FutureModifier<CarbDashboardData?>,
        $FutureProvider<CarbDashboardData?> {
  /// The loading-day surface data for one date, or null when the date falls in
  /// no carb-loading plan — CD-1's negative: a regular day has NO carb surface
  /// anywhere in the DOM.
  ///
  /// Composition, not refetching (same shape as [macroDashboardDay]): a food
  /// log write invalidates the meal-log providers, this recomputes, and every
  /// carb surface — face, slot cards, slot page, breakdown — rebuilds in the
  /// same pump (CD-2, the surface's core contract).
  const CarbDashboardForDateProvider._({
    required CarbDashboardForDateFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'carbDashboardForDateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$carbDashboardForDateHash();

  @override
  String toString() {
    return r'carbDashboardForDateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<CarbDashboardData?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CarbDashboardData?> create(Ref ref) {
    final argument = this.argument as String;
    return carbDashboardForDate(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CarbDashboardForDateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$carbDashboardForDateHash() =>
    r'70903ea0f16756e8679c99f4b75c8d3ba684b00c';

/// The loading-day surface data for one date, or null when the date falls in
/// no carb-loading plan — CD-1's negative: a regular day has NO carb surface
/// anywhere in the DOM.
///
/// Composition, not refetching (same shape as [macroDashboardDay]): a food
/// log write invalidates the meal-log providers, this recomputes, and every
/// carb surface — face, slot cards, slot page, breakdown — rebuilds in the
/// same pump (CD-2, the surface's core contract).

final class CarbDashboardForDateFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<CarbDashboardData?>, String> {
  const CarbDashboardForDateFamily._()
    : super(
        retry: null,
        name: r'carbDashboardForDateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The loading-day surface data for one date, or null when the date falls in
  /// no carb-loading plan — CD-1's negative: a regular day has NO carb surface
  /// anywhere in the DOM.
  ///
  /// Composition, not refetching (same shape as [macroDashboardDay]): a food
  /// log write invalidates the meal-log providers, this recomputes, and every
  /// carb surface — face, slot cards, slot page, breakdown — rebuilds in the
  /// same pump (CD-2, the surface's core contract).

  CarbDashboardForDateProvider call(String dateStr) =>
      CarbDashboardForDateProvider._(argument: dateStr, from: this);

  @override
  String toString() => r'carbDashboardForDateProvider';
}
