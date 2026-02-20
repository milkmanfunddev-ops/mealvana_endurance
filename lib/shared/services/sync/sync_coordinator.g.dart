// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_coordinator.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Centralized sync coordinator - SINGLE entry point for ALL sync operations
///
/// Key responsibilities:
/// 1. Prevents concurrent syncs (sync lock)
/// 2. Calls DataSyncService.syncAllData()
/// 3. Invalidates ALL data providers after successful sync
/// 4. Logs sync operations (silent error handling)
///
/// Sync triggers (OAuth-only strategy):
/// - oauthSignIn: After successful OAuth sign-in (new device login, sign back in)
/// - pullToRefresh: Manual user refresh
/// - manual: Any other explicit sync request
///
/// NOT synced on app startup - returning users see cached data until pull-to-refresh

@ProviderFor(SyncCoordinator)
const syncCoordinatorProvider = SyncCoordinatorProvider._();

/// Centralized sync coordinator - SINGLE entry point for ALL sync operations
///
/// Key responsibilities:
/// 1. Prevents concurrent syncs (sync lock)
/// 2. Calls DataSyncService.syncAllData()
/// 3. Invalidates ALL data providers after successful sync
/// 4. Logs sync operations (silent error handling)
///
/// Sync triggers (OAuth-only strategy):
/// - oauthSignIn: After successful OAuth sign-in (new device login, sign back in)
/// - pullToRefresh: Manual user refresh
/// - manual: Any other explicit sync request
///
/// NOT synced on app startup - returning users see cached data until pull-to-refresh
final class SyncCoordinatorProvider
    extends $NotifierProvider<SyncCoordinator, SyncState> {
  /// Centralized sync coordinator - SINGLE entry point for ALL sync operations
  ///
  /// Key responsibilities:
  /// 1. Prevents concurrent syncs (sync lock)
  /// 2. Calls DataSyncService.syncAllData()
  /// 3. Invalidates ALL data providers after successful sync
  /// 4. Logs sync operations (silent error handling)
  ///
  /// Sync triggers (OAuth-only strategy):
  /// - oauthSignIn: After successful OAuth sign-in (new device login, sign back in)
  /// - pullToRefresh: Manual user refresh
  /// - manual: Any other explicit sync request
  ///
  /// NOT synced on app startup - returning users see cached data until pull-to-refresh
  const SyncCoordinatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncCoordinatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncCoordinatorHash();

  @$internal
  @override
  SyncCoordinator create() => SyncCoordinator();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncState>(value),
    );
  }
}

String _$syncCoordinatorHash() => r'2cb92269bf792b3e115ec0a293a24a8cb4b9ff54';

/// Centralized sync coordinator - SINGLE entry point for ALL sync operations
///
/// Key responsibilities:
/// 1. Prevents concurrent syncs (sync lock)
/// 2. Calls DataSyncService.syncAllData()
/// 3. Invalidates ALL data providers after successful sync
/// 4. Logs sync operations (silent error handling)
///
/// Sync triggers (OAuth-only strategy):
/// - oauthSignIn: After successful OAuth sign-in (new device login, sign back in)
/// - pullToRefresh: Manual user refresh
/// - manual: Any other explicit sync request
///
/// NOT synced on app startup - returning users see cached data until pull-to-refresh

abstract class _$SyncCoordinator extends $Notifier<SyncState> {
  SyncState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<SyncState, SyncState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SyncState, SyncState>,
              SyncState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
