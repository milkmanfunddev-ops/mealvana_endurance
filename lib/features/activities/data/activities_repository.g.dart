// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activities_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(activitiesRepository)
const activitiesRepositoryProvider = ActivitiesRepositoryProvider._();

final class ActivitiesRepositoryProvider
    extends
        $FunctionalProvider<
          ActivitiesRepository,
          ActivitiesRepository,
          ActivitiesRepository
        >
    with $Provider<ActivitiesRepository> {
  const ActivitiesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activitiesRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activitiesRepositoryHash();

  @$internal
  @override
  $ProviderElement<ActivitiesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ActivitiesRepository create(Ref ref) {
    return activitiesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ActivitiesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ActivitiesRepository>(value),
    );
  }
}

String _$activitiesRepositoryHash() =>
    r'868ce4c2a59547adf5bdd199fbb86207e28c9578';
