// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'carb_slot_recommendations.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The slot page's recommendation rows for one slot: the old store filtered
/// by `meal_types` suitability (getFoodsByMealType), fixed curation order.
/// Empty store or no suitable rows → empty list; the section renders its
/// empty state, never crashes (the G21-B empty-state red).

@ProviderFor(carbSlotRecommendations)
const carbSlotRecommendationsProvider = CarbSlotRecommendationsFamily._();

/// The slot page's recommendation rows for one slot: the old store filtered
/// by `meal_types` suitability (getFoodsByMealType), fixed curation order.
/// Empty store or no suitable rows → empty list; the section renders its
/// empty state, never crashes (the G21-B empty-state red).

final class CarbSlotRecommendationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CarbSlotRecommendation>>,
          List<CarbSlotRecommendation>,
          FutureOr<List<CarbSlotRecommendation>>
        >
    with
        $FutureModifier<List<CarbSlotRecommendation>>,
        $FutureProvider<List<CarbSlotRecommendation>> {
  /// The slot page's recommendation rows for one slot: the old store filtered
  /// by `meal_types` suitability (getFoodsByMealType), fixed curation order.
  /// Empty store or no suitable rows → empty list; the section renders its
  /// empty state, never crashes (the G21-B empty-state red).
  const CarbSlotRecommendationsProvider._({
    required CarbSlotRecommendationsFamily super.from,
    required MealType super.argument,
  }) : super(
         retry: null,
         name: r'carbSlotRecommendationsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$carbSlotRecommendationsHash();

  @override
  String toString() {
    return r'carbSlotRecommendationsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<CarbSlotRecommendation>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CarbSlotRecommendation>> create(Ref ref) {
    final argument = this.argument as MealType;
    return carbSlotRecommendations(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CarbSlotRecommendationsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$carbSlotRecommendationsHash() =>
    r'd3a7640bd66e9369839af0f727f6e8f6e48f7237';

/// The slot page's recommendation rows for one slot: the old store filtered
/// by `meal_types` suitability (getFoodsByMealType), fixed curation order.
/// Empty store or no suitable rows → empty list; the section renders its
/// empty state, never crashes (the G21-B empty-state red).

final class CarbSlotRecommendationsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<CarbSlotRecommendation>>,
          MealType
        > {
  const CarbSlotRecommendationsFamily._()
    : super(
        retry: null,
        name: r'carbSlotRecommendationsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The slot page's recommendation rows for one slot: the old store filtered
  /// by `meal_types` suitability (getFoodsByMealType), fixed curation order.
  /// Empty store or no suitable rows → empty list; the section renders its
  /// empty state, never crashes (the G21-B empty-state red).

  CarbSlotRecommendationsProvider call(MealType slot) =>
      CarbSlotRecommendationsProvider._(argument: slot, from: this);

  @override
  String toString() => r'carbSlotRecommendationsProvider';
}

/// Provider face of [resolveCarbRecommendation] for the slot page's tap.
///
/// Exact hit → done. Otherwise the mirror may simply predate a server-side
/// catalog seed (the `foods` sync only ever runs on an EMPTY mirror), so
/// re-sync the catalog once ([FoodRepository.refreshAfterMiss], throttled)
/// and run the FULL resolver again. Offline, throttled, or no signed-in
/// user → the refresh is a no-op and the full resolver (exact then token,
/// the ratified G25/G26 behaviour) still runs exactly once, so nothing
/// regresses: the token pass stays the fallback, and null still hands off
/// to search.

@ProviderFor(carbRecommendationResolution)
const carbRecommendationResolutionProvider =
    CarbRecommendationResolutionFamily._();

/// Provider face of [resolveCarbRecommendation] for the slot page's tap.
///
/// Exact hit → done. Otherwise the mirror may simply predate a server-side
/// catalog seed (the `foods` sync only ever runs on an EMPTY mirror), so
/// re-sync the catalog once ([FoodRepository.refreshAfterMiss], throttled)
/// and run the FULL resolver again. Offline, throttled, or no signed-in
/// user → the refresh is a no-op and the full resolver (exact then token,
/// the ratified G25/G26 behaviour) still runs exactly once, so nothing
/// regresses: the token pass stays the fallback, and null still hands off
/// to search.

final class CarbRecommendationResolutionProvider
    extends
        $FunctionalProvider<
          AsyncValue<CarbFoodResolution?>,
          CarbFoodResolution?,
          FutureOr<CarbFoodResolution?>
        >
    with
        $FutureModifier<CarbFoodResolution?>,
        $FutureProvider<CarbFoodResolution?> {
  /// Provider face of [resolveCarbRecommendation] for the slot page's tap.
  ///
  /// Exact hit → done. Otherwise the mirror may simply predate a server-side
  /// catalog seed (the `foods` sync only ever runs on an EMPTY mirror), so
  /// re-sync the catalog once ([FoodRepository.refreshAfterMiss], throttled)
  /// and run the FULL resolver again. Offline, throttled, or no signed-in
  /// user → the refresh is a no-op and the full resolver (exact then token,
  /// the ratified G25/G26 behaviour) still runs exactly once, so nothing
  /// regresses: the token pass stays the fallback, and null still hands off
  /// to search.
  const CarbRecommendationResolutionProvider._({
    required CarbRecommendationResolutionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'carbRecommendationResolutionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$carbRecommendationResolutionHash();

  @override
  String toString() {
    return r'carbRecommendationResolutionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<CarbFoodResolution?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CarbFoodResolution?> create(Ref ref) {
    final argument = this.argument as String;
    return carbRecommendationResolution(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CarbRecommendationResolutionProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$carbRecommendationResolutionHash() =>
    r'6b0dee06235a72275d8c7ba2d0a90041375bcb2e';

/// Provider face of [resolveCarbRecommendation] for the slot page's tap.
///
/// Exact hit → done. Otherwise the mirror may simply predate a server-side
/// catalog seed (the `foods` sync only ever runs on an EMPTY mirror), so
/// re-sync the catalog once ([FoodRepository.refreshAfterMiss], throttled)
/// and run the FULL resolver again. Offline, throttled, or no signed-in
/// user → the refresh is a no-op and the full resolver (exact then token,
/// the ratified G25/G26 behaviour) still runs exactly once, so nothing
/// regresses: the token pass stays the fallback, and null still hands off
/// to search.

final class CarbRecommendationResolutionFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<CarbFoodResolution?>, String> {
  const CarbRecommendationResolutionFamily._()
    : super(
        retry: null,
        name: r'carbRecommendationResolutionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider face of [resolveCarbRecommendation] for the slot page's tap.
  ///
  /// Exact hit → done. Otherwise the mirror may simply predate a server-side
  /// catalog seed (the `foods` sync only ever runs on an EMPTY mirror), so
  /// re-sync the catalog once ([FoodRepository.refreshAfterMiss], throttled)
  /// and run the FULL resolver again. Offline, throttled, or no signed-in
  /// user → the refresh is a no-op and the full resolver (exact then token,
  /// the ratified G25/G26 behaviour) still runs exactly once, so nothing
  /// regresses: the token pass stays the fallback, and null still hands off
  /// to search.

  CarbRecommendationResolutionProvider call(String query) =>
      CarbRecommendationResolutionProvider._(argument: query, from: this);

  @override
  String toString() => r'carbRecommendationResolutionProvider';
}
