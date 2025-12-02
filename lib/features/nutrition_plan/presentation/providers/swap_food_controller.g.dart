// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'swap_food_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for food repository

@ProviderFor(foodRepository)
const foodRepositoryProvider = FoodRepositoryProvider._();

/// Provider for food repository

final class FoodRepositoryProvider
    extends $FunctionalProvider<FoodRepository, FoodRepository, FoodRepository>
    with $Provider<FoodRepository> {
  /// Provider for food repository
  const FoodRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'foodRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$foodRepositoryHash();

  @$internal
  @override
  $ProviderElement<FoodRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FoodRepository create(Ref ref) {
    return foodRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FoodRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FoodRepository>(value),
    );
  }
}

String _$foodRepositoryHash() => r'c7cbda34f5dc4619b4973fb8777b6ca1d9424c4f';

/// Controller for swap food functionality - takes swap parameters

@ProviderFor(SwapFoodController)
const swapFoodControllerProvider = SwapFoodControllerFamily._();

/// Controller for swap food functionality - takes swap parameters
final class SwapFoodControllerProvider
    extends $AsyncNotifierProvider<SwapFoodController, SwapFoodState> {
  /// Controller for swap food functionality - takes swap parameters
  const SwapFoodControllerProvider._({
    required SwapFoodControllerFamily super.from,
    required SwapFoodParams super.argument,
  }) : super(
         retry: null,
         name: r'swapFoodControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$swapFoodControllerHash();

  @override
  String toString() {
    return r'swapFoodControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SwapFoodController create() => SwapFoodController();

  @override
  bool operator ==(Object other) {
    return other is SwapFoodControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$swapFoodControllerHash() =>
    r'5fd353b38983b125fc08f2191a4e5578babc8256';

/// Controller for swap food functionality - takes swap parameters

final class SwapFoodControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SwapFoodController,
          AsyncValue<SwapFoodState>,
          SwapFoodState,
          FutureOr<SwapFoodState>,
          SwapFoodParams
        > {
  const SwapFoodControllerFamily._()
    : super(
        retry: null,
        name: r'swapFoodControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Controller for swap food functionality - takes swap parameters

  SwapFoodControllerProvider call(SwapFoodParams params) =>
      SwapFoodControllerProvider._(argument: params, from: this);

  @override
  String toString() => r'swapFoodControllerProvider';
}

/// Controller for swap food functionality - takes swap parameters

abstract class _$SwapFoodController extends $AsyncNotifier<SwapFoodState> {
  late final _$args = ref.$arg as SwapFoodParams;
  SwapFoodParams get params => _$args;

  FutureOr<SwapFoodState> build(SwapFoodParams params);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<AsyncValue<SwapFoodState>, SwapFoodState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<SwapFoodState>, SwapFoodState>,
              AsyncValue<SwapFoodState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
