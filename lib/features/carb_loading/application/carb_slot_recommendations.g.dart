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

@ProviderFor(carbRecommendationResolution)
const carbRecommendationResolutionProvider =
    CarbRecommendationResolutionFamily._();

/// Provider face of [resolveCarbRecommendation] for the slot page's tap.

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
    r'082395d47aaf1bff6ad0a6d80304b7c4d6390ceb';

/// Provider face of [resolveCarbRecommendation] for the slot page's tap.

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

  CarbRecommendationResolutionProvider call(String query) =>
      CarbRecommendationResolutionProvider._(argument: query, from: this);

  @override
  String toString() => r'carbRecommendationResolutionProvider';
}
