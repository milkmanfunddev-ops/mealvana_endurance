// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'integration_sync_coordinator.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Lightweight coordinator for integration staleness checks and dedup.
///
/// Purpose-built for external provider sync (Final Surge, Training Peaks,
/// V.O2). NOT part of the SyncCoordinator dependency graph because integration
/// sync has no dirty-record upload concept.
///
/// Design:
/// - 4-hour staleness threshold (external APIs are slower/less reliable)
/// - 5-minute failure cooldown
/// - Dedup via _syncingNow set
/// - Silent failures (logs only, no snackbars)

@ProviderFor(IntegrationSyncCoordinator)
const integrationSyncCoordinatorProvider =
    IntegrationSyncCoordinatorProvider._();

/// Lightweight coordinator for integration staleness checks and dedup.
///
/// Purpose-built for external provider sync (Final Surge, Training Peaks,
/// V.O2). NOT part of the SyncCoordinator dependency graph because integration
/// sync has no dirty-record upload concept.
///
/// Design:
/// - 4-hour staleness threshold (external APIs are slower/less reliable)
/// - 5-minute failure cooldown
/// - Dedup via _syncingNow set
/// - Silent failures (logs only, no snackbars)
final class IntegrationSyncCoordinatorProvider
    extends $NotifierProvider<IntegrationSyncCoordinator, void> {
  /// Lightweight coordinator for integration staleness checks and dedup.
  ///
  /// Purpose-built for external provider sync (Final Surge, Training Peaks,
  /// V.O2). NOT part of the SyncCoordinator dependency graph because integration
  /// sync has no dirty-record upload concept.
  ///
  /// Design:
  /// - 4-hour staleness threshold (external APIs are slower/less reliable)
  /// - 5-minute failure cooldown
  /// - Dedup via _syncingNow set
  /// - Silent failures (logs only, no snackbars)
  const IntegrationSyncCoordinatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'integrationSyncCoordinatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$integrationSyncCoordinatorHash();

  @$internal
  @override
  IntegrationSyncCoordinator create() => IntegrationSyncCoordinator();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$integrationSyncCoordinatorHash() =>
    r'050cae5f90f5035320acf1e4a8b9ff12ca7d12a6';

/// Lightweight coordinator for integration staleness checks and dedup.
///
/// Purpose-built for external provider sync (Final Surge, Training Peaks,
/// V.O2). NOT part of the SyncCoordinator dependency graph because integration
/// sync has no dirty-record upload concept.
///
/// Design:
/// - 4-hour staleness threshold (external APIs are slower/less reliable)
/// - 5-minute failure cooldown
/// - Dedup via _syncingNow set
/// - Silent failures (logs only, no snackbars)

abstract class _$IntegrationSyncCoordinator extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  void runBuild() {
    build();
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    element.handleValue(ref, null);
  }
}
