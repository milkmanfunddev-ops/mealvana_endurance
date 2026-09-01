// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_library_remote_data_source.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(mealLibraryRemoteDataSource)
const mealLibraryRemoteDataSourceProvider =
    MealLibraryRemoteDataSourceProvider._();

final class MealLibraryRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          MealLibraryRemoteDataSource,
          MealLibraryRemoteDataSource,
          MealLibraryRemoteDataSource
        >
    with $Provider<MealLibraryRemoteDataSource> {
  const MealLibraryRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mealLibraryRemoteDataSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mealLibraryRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<MealLibraryRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MealLibraryRemoteDataSource create(Ref ref) {
    return mealLibraryRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MealLibraryRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MealLibraryRemoteDataSource>(value),
    );
  }
}

String _$mealLibraryRemoteDataSourceHash() =>
    r'a2c2d5b346bc0e9410800de2f89b45b7881022aa';
