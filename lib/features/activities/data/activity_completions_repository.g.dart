// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_completions_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(activityCompletionsRepository)
const activityCompletionsRepositoryProvider =
    ActivityCompletionsRepositoryProvider._();

final class ActivityCompletionsRepositoryProvider
    extends
        $FunctionalProvider<
          ActivityCompletionsRepository,
          ActivityCompletionsRepository,
          ActivityCompletionsRepository
        >
    with $Provider<ActivityCompletionsRepository> {
  const ActivityCompletionsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activityCompletionsRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activityCompletionsRepositoryHash();

  @$internal
  @override
  $ProviderElement<ActivityCompletionsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ActivityCompletionsRepository create(Ref ref) {
    return activityCompletionsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ActivityCompletionsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ActivityCompletionsRepository>(
        value,
      ),
    );
  }
}

String _$activityCompletionsRepositoryHash() =>
    r'959fa0f577e6ad1966df31eefb69d83f381122df';
