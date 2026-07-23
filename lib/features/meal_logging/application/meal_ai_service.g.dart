// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_ai_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(mealAiService)
const mealAiServiceProvider = MealAiServiceProvider._();

final class MealAiServiceProvider
    extends $FunctionalProvider<MealAiService, MealAiService, MealAiService>
    with $Provider<MealAiService> {
  const MealAiServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mealAiServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mealAiServiceHash();

  @$internal
  @override
  $ProviderElement<MealAiService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MealAiService create(Ref ref) {
    return mealAiService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MealAiService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MealAiService>(value),
    );
  }
}

String _$mealAiServiceHash() => r'835ff86946252c1f1b3c7d31fbb8fe0b9e2cace7';
