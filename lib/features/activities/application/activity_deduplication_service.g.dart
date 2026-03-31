// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_deduplication_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(activityDeduplicationService)
const activityDeduplicationServiceProvider =
    ActivityDeduplicationServiceProvider._();

final class ActivityDeduplicationServiceProvider
    extends
        $FunctionalProvider<
          ActivityDeduplicationService,
          ActivityDeduplicationService,
          ActivityDeduplicationService
        >
    with $Provider<ActivityDeduplicationService> {
  const ActivityDeduplicationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activityDeduplicationServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activityDeduplicationServiceHash();

  @$internal
  @override
  $ProviderElement<ActivityDeduplicationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ActivityDeduplicationService create(Ref ref) {
    return activityDeduplicationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ActivityDeduplicationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ActivityDeduplicationService>(value),
    );
  }
}

String _$activityDeduplicationServiceHash() =>
    r'b1121307507127ca4b5376cf7c2c4bc0dcd3a3fc';
