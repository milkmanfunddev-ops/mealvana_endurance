// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food_preference_sync_handler.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(foodPreferenceSyncHandler)
const foodPreferenceSyncHandlerProvider = FoodPreferenceSyncHandlerProvider._();

final class FoodPreferenceSyncHandlerProvider
    extends
        $FunctionalProvider<
          FoodPreferenceSyncHandler,
          FoodPreferenceSyncHandler,
          FoodPreferenceSyncHandler
        >
    with $Provider<FoodPreferenceSyncHandler> {
  const FoodPreferenceSyncHandlerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'foodPreferenceSyncHandlerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$foodPreferenceSyncHandlerHash();

  @$internal
  @override
  $ProviderElement<FoodPreferenceSyncHandler> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FoodPreferenceSyncHandler create(Ref ref) {
    return foodPreferenceSyncHandler(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FoodPreferenceSyncHandler value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FoodPreferenceSyncHandler>(value),
    );
  }
}

String _$foodPreferenceSyncHandlerHash() =>
    r'912f5183422b33a4d90a9047b1054575808b36d6';
