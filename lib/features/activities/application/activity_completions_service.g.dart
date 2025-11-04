// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_completions_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(activityCompletionsService)
const activityCompletionsServiceProvider =
    ActivityCompletionsServiceProvider._();

final class ActivityCompletionsServiceProvider
    extends
        $FunctionalProvider<
          ActivityCompletionsService,
          ActivityCompletionsService,
          ActivityCompletionsService
        >
    with $Provider<ActivityCompletionsService> {
  const ActivityCompletionsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activityCompletionsServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activityCompletionsServiceHash();

  @$internal
  @override
  $ProviderElement<ActivityCompletionsService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ActivityCompletionsService create(Ref ref) {
    return activityCompletionsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ActivityCompletionsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ActivityCompletionsService>(value),
    );
  }
}

String _$activityCompletionsServiceHash() =>
    r'd9f8f81bc06bb3d634b1ce20a94a4381c9d0737d';
