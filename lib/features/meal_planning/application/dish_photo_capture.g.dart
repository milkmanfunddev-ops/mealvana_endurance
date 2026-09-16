// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dish_photo_capture.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The real picker.
///
/// No `imageQuality` or `maxWidth` here, unlike the meal-logging capture:
/// those re-encode on the platform side, and the Tester is about to crop the
/// photograph. Full-size bytes go to the crop editor, and `prepareDishPhoto`
/// does the one shrink and the one re-encode afterwards.

@ProviderFor(dishPhotoPicker)
const dishPhotoPickerProvider = DishPhotoPickerProvider._();

/// The real picker.
///
/// No `imageQuality` or `maxWidth` here, unlike the meal-logging capture:
/// those re-encode on the platform side, and the Tester is about to crop the
/// photograph. Full-size bytes go to the crop editor, and `prepareDishPhoto`
/// does the one shrink and the one re-encode afterwards.

final class DishPhotoPickerProvider
    extends
        $FunctionalProvider<DishPhotoPicker, DishPhotoPicker, DishPhotoPicker>
    with $Provider<DishPhotoPicker> {
  /// The real picker.
  ///
  /// No `imageQuality` or `maxWidth` here, unlike the meal-logging capture:
  /// those re-encode on the platform side, and the Tester is about to crop the
  /// photograph. Full-size bytes go to the crop editor, and `prepareDishPhoto`
  /// does the one shrink and the one re-encode afterwards.
  const DishPhotoPickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dishPhotoPickerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dishPhotoPickerHash();

  @$internal
  @override
  $ProviderElement<DishPhotoPicker> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DishPhotoPicker create(Ref ref) {
    return dishPhotoPicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DishPhotoPicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DishPhotoPicker>(value),
    );
  }
}

String _$dishPhotoPickerHash() => r'a91dd24647b0272c96edd53e3ebe237daa81db21';

/// The real one, on another isolate.
///
/// Decoding, resizing and re-encoding a photo straight off a phone camera is
/// tens of megapixels of work; on the UI isolate it would freeze the page,
/// including the spinner that is meant to show something is happening.
///
/// A seam only so that widget tests can run the very same [prepareDishPhoto]
/// inline: a real isolate never resolves inside `pumpAndSettle`'s fake-async
/// zone. What is prepared, and the guarantee that it always is, do not change.

@ProviderFor(dishPhotoPreparer)
const dishPhotoPreparerProvider = DishPhotoPreparerProvider._();

/// The real one, on another isolate.
///
/// Decoding, resizing and re-encoding a photo straight off a phone camera is
/// tens of megapixels of work; on the UI isolate it would freeze the page,
/// including the spinner that is meant to show something is happening.
///
/// A seam only so that widget tests can run the very same [prepareDishPhoto]
/// inline: a real isolate never resolves inside `pumpAndSettle`'s fake-async
/// zone. What is prepared, and the guarantee that it always is, do not change.

final class DishPhotoPreparerProvider
    extends
        $FunctionalProvider<
          DishPhotoPreparer,
          DishPhotoPreparer,
          DishPhotoPreparer
        >
    with $Provider<DishPhotoPreparer> {
  /// The real one, on another isolate.
  ///
  /// Decoding, resizing and re-encoding a photo straight off a phone camera is
  /// tens of megapixels of work; on the UI isolate it would freeze the page,
  /// including the spinner that is meant to show something is happening.
  ///
  /// A seam only so that widget tests can run the very same [prepareDishPhoto]
  /// inline: a real isolate never resolves inside `pumpAndSettle`'s fake-async
  /// zone. What is prepared, and the guarantee that it always is, do not change.
  const DishPhotoPreparerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dishPhotoPreparerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dishPhotoPreparerHash();

  @$internal
  @override
  $ProviderElement<DishPhotoPreparer> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DishPhotoPreparer create(Ref ref) {
    return dishPhotoPreparer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DishPhotoPreparer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DishPhotoPreparer>(value),
    );
  }
}

String _$dishPhotoPreparerHash() => r'ee8df6efedc0f14e85755a97445ac3c80b3e17a5';
