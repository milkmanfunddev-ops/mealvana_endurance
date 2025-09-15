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
    r'5190da0a1e04f55771351f2f467ad50dc401395e';

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
  late final String category;

  FutureOr<SwapFoodState> build(
    String category,
  );
}

/// Controller for swap food functionality - takes category as parameter
///
/// Copied from [SwapFoodController].
@ProviderFor(SwapFoodController)
const swapFoodControllerProvider = SwapFoodControllerFamily();

/// Controller for swap food functionality - takes category as parameter
///
/// Copied from [SwapFoodController].
class SwapFoodControllerFamily extends Family<AsyncValue<SwapFoodState>> {
  /// Controller for swap food functionality - takes category as parameter
  ///
  /// Copied from [SwapFoodController].
  const SwapFoodControllerFamily();

  /// Controller for swap food functionality - takes category as parameter
  ///
  /// Copied from [SwapFoodController].
  SwapFoodControllerProvider call(
    String category,
  ) {
    return SwapFoodControllerProvider(
      category,
    );
  }

  @override
  SwapFoodControllerProvider getProviderOverride(
    covariant SwapFoodControllerProvider provider,
  ) {
    return call(
      provider.category,
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

/// Controller for swap food functionality - takes category as parameter
///
/// Copied from [SwapFoodController].
class SwapFoodControllerProvider extends AutoDisposeAsyncNotifierProviderImpl<
    SwapFoodController, SwapFoodState> {
  /// Controller for swap food functionality - takes category as parameter
  ///
  /// Copied from [SwapFoodController].
  SwapFoodControllerProvider(
    String category,
  ) : this._internal(
          () => SwapFoodController()..category = category,
          from: swapFoodControllerProvider,
          name: r'swapFoodControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$swapFoodControllerHash,
          dependencies: SwapFoodControllerFamily._dependencies,
          allTransitiveDependencies:
              SwapFoodControllerFamily._allTransitiveDependencies,
          category: category,
        );

  SwapFoodControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.category,
  }) : super.internal();

  final String category;

  @override
  FutureOr<SwapFoodState> runNotifierBuild(
    covariant SwapFoodController notifier,
  ) {
    return notifier.build(
      category,
    );
  }

  @override
  Override overrideWith(SwapFoodController Function() create) {
    return ProviderOverride(
      origin: this,
      override: SwapFoodControllerProvider._internal(
        () => create()..category = category,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        category: category,
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
    return other is SwapFoodControllerProvider && other.category == category;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, category.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SwapFoodControllerRef
    on AutoDisposeAsyncNotifierProviderRef<SwapFoodState> {
  /// The parameter `category` of this provider.
  String get category;
}

class _SwapFoodControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<SwapFoodController,
        SwapFoodState> with SwapFoodControllerRef {
  _SwapFoodControllerProviderElement(super.provider);

  @override
  String get category => (origin as SwapFoodControllerProvider).category;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
