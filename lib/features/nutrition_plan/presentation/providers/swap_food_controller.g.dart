// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'swap_food_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$foodRepositoryHash() => r'01690ac89647b154cd2c79e39fc98eaf3463bea5';

/// Provider for food repository
///
/// Copied from [foodRepository].
@ProviderFor(foodRepository)
final foodRepositoryProvider = AutoDisposeProvider<FoodRepository>.internal(
  foodRepository,
  name: r'foodRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$foodRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FoodRepositoryRef = AutoDisposeProviderRef<FoodRepository>;
String _$swapFoodControllerHash() =>
    r'7f0ddc0b1bf38752493601baaf20e9f9603d1e92';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$SwapFoodController
    extends BuildlessAutoDisposeAsyncNotifier<SwapFoodState> {
  late final SwapFoodParams params;

  FutureOr<SwapFoodState> build(
    SwapFoodParams params,
  );
}

/// Controller for swap food functionality - takes swap parameters
///
/// Copied from [SwapFoodController].
@ProviderFor(SwapFoodController)
const swapFoodControllerProvider = SwapFoodControllerFamily();

/// Controller for swap food functionality - takes swap parameters
///
/// Copied from [SwapFoodController].
class SwapFoodControllerFamily extends Family<AsyncValue<SwapFoodState>> {
  /// Controller for swap food functionality - takes swap parameters
  ///
  /// Copied from [SwapFoodController].
  const SwapFoodControllerFamily();

  /// Controller for swap food functionality - takes swap parameters
  ///
  /// Copied from [SwapFoodController].
  SwapFoodControllerProvider call(
    SwapFoodParams params,
  ) {
    return SwapFoodControllerProvider(
      params,
    );
  }

  @override
  SwapFoodControllerProvider getProviderOverride(
    covariant SwapFoodControllerProvider provider,
  ) {
    return call(
      provider.params,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'swapFoodControllerProvider';
}

/// Controller for swap food functionality - takes swap parameters
///
/// Copied from [SwapFoodController].
class SwapFoodControllerProvider extends AutoDisposeAsyncNotifierProviderImpl<
    SwapFoodController, SwapFoodState> {
  /// Controller for swap food functionality - takes swap parameters
  ///
  /// Copied from [SwapFoodController].
  SwapFoodControllerProvider(
    SwapFoodParams params,
  ) : this._internal(
          () => SwapFoodController()..params = params,
          from: swapFoodControllerProvider,
          name: r'swapFoodControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$swapFoodControllerHash,
          dependencies: SwapFoodControllerFamily._dependencies,
          allTransitiveDependencies:
              SwapFoodControllerFamily._allTransitiveDependencies,
          params: params,
        );

  SwapFoodControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.params,
  }) : super.internal();

  final SwapFoodParams params;

  @override
  FutureOr<SwapFoodState> runNotifierBuild(
    covariant SwapFoodController notifier,
  ) {
    return notifier.build(
      params,
    );
  }

  @override
  Override overrideWith(SwapFoodController Function() create) {
    return ProviderOverride(
      origin: this,
      override: SwapFoodControllerProvider._internal(
        () => create()..params = params,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        params: params,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<SwapFoodController, SwapFoodState>
      createElement() {
    return _SwapFoodControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SwapFoodControllerProvider && other.params == params;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, params.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SwapFoodControllerRef
    on AutoDisposeAsyncNotifierProviderRef<SwapFoodState> {
  /// The parameter `params` of this provider.
  SwapFoodParams get params;
}

class _SwapFoodControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<SwapFoodController,
        SwapFoodState> with SwapFoodControllerRef {
  _SwapFoodControllerProviderElement(super.provider);

  @override
  SwapFoodParams get params => (origin as SwapFoodControllerProvider).params;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
