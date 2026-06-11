// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_meals_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(savedMealsRepository)
const savedMealsRepositoryProvider = SavedMealsRepositoryProvider._();

final class SavedMealsRepositoryProvider
    extends
        $FunctionalProvider<
          SavedMealsRepository,
          SavedMealsRepository,
          SavedMealsRepository
        >
    with $Provider<SavedMealsRepository> {
  const SavedMealsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedMealsRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedMealsRepositoryHash();

  @$internal
  @override
  $ProviderElement<SavedMealsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SavedMealsRepository create(Ref ref) {
    return savedMealsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SavedMealsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SavedMealsRepository>(value),
    );
  }
}

String _$savedMealsRepositoryHash() =>
    r'0abbc72f1641593c2008a442ee4a1bc6c48500b7';
