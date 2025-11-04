// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activities_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(activitiesService)
const activitiesServiceProvider = ActivitiesServiceProvider._();

final class ActivitiesServiceProvider
    extends
        $FunctionalProvider<
          ActivitiesService,
          ActivitiesService,
          ActivitiesService
        >
    with $Provider<ActivitiesService> {
  const ActivitiesServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activitiesServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activitiesServiceHash();

  @$internal
  @override
  $ProviderElement<ActivitiesService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ActivitiesService create(Ref ref) {
    return activitiesService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ActivitiesService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ActivitiesService>(value),
    );
  }
}

String _$activitiesServiceHash() => r'40071379b8fce583f2b5a69e620f2a44d5cdf4ed';
