// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dish_photo_cropper.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The real crop editor: the full-screen crop page, at the picture's aspect.

@ProviderFor(dishPhotoCropper)
const dishPhotoCropperProvider = DishPhotoCropperProvider._();

/// The real crop editor: the full-screen crop page, at the picture's aspect.

final class DishPhotoCropperProvider
    extends
        $FunctionalProvider<
          DishPhotoCropper,
          DishPhotoCropper,
          DishPhotoCropper
        >
    with $Provider<DishPhotoCropper> {
  /// The real crop editor: the full-screen crop page, at the picture's aspect.
  const DishPhotoCropperProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dishPhotoCropperProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dishPhotoCropperHash();

  @$internal
  @override
  $ProviderElement<DishPhotoCropper> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DishPhotoCropper create(Ref ref) {
    return dishPhotoCropper(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DishPhotoCropper value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DishPhotoCropper>(value),
    );
  }
}

String _$dishPhotoCropperHash() => r'1258aad3ccb9edaf9ddf23111f135c3b4eaff61e';
