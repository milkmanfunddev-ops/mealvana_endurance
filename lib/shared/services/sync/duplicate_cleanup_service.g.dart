// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'duplicate_cleanup_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(duplicateCleanupService)
const duplicateCleanupServiceProvider = DuplicateCleanupServiceProvider._();

final class DuplicateCleanupServiceProvider
    extends
        $FunctionalProvider<
          DuplicateCleanupService,
          DuplicateCleanupService,
          DuplicateCleanupService
        >
    with $Provider<DuplicateCleanupService> {
  const DuplicateCleanupServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'duplicateCleanupServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$duplicateCleanupServiceHash();

  @$internal
  @override
  $ProviderElement<DuplicateCleanupService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DuplicateCleanupService create(Ref ref) {
    return duplicateCleanupService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DuplicateCleanupService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DuplicateCleanupService>(value),
    );
  }
}

String _$duplicateCleanupServiceHash() =>
    r'1a96b0d10957d6f380ac94ee336ec38352f38405';
