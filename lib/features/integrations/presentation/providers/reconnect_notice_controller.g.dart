// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reconnect_notice_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The one-time "sign in again" notice for a connected app (testing-wave
/// ticket 138, Finding 118-007; Lee 2026-09-26).
///
/// State is the provider id whose notice the Timeline should show, or null.
/// [IntegrationsRepository.updateSyncStatus] reports every status it writes
/// through [onSyncStatusWritten], so the notice fires no matter which path
/// found the dead token: a background sync, Sync Now, or Garmin's backfill.
///
/// Shown once per move into `requires_reauth`: the move is remembered in
/// SharedPreferences under the provider's key, and a later `success` for the
/// same provider forgets it, so the next relapse is announced again.
///
/// Repeats are safe: two writes of `requires_reauth` in a row (the same sync
/// hitting two endpoints) read the same flag and show one notice; a refresh
/// of the controller re-reads nothing, because the flag lives in prefs.

@ProviderFor(ReconnectNoticeController)
const reconnectNoticeControllerProvider = ReconnectNoticeControllerProvider._();

/// The one-time "sign in again" notice for a connected app (testing-wave
/// ticket 138, Finding 118-007; Lee 2026-09-26).
///
/// State is the provider id whose notice the Timeline should show, or null.
/// [IntegrationsRepository.updateSyncStatus] reports every status it writes
/// through [onSyncStatusWritten], so the notice fires no matter which path
/// found the dead token: a background sync, Sync Now, or Garmin's backfill.
///
/// Shown once per move into `requires_reauth`: the move is remembered in
/// SharedPreferences under the provider's key, and a later `success` for the
/// same provider forgets it, so the next relapse is announced again.
///
/// Repeats are safe: two writes of `requires_reauth` in a row (the same sync
/// hitting two endpoints) read the same flag and show one notice; a refresh
/// of the controller re-reads nothing, because the flag lives in prefs.
final class ReconnectNoticeControllerProvider
    extends $NotifierProvider<ReconnectNoticeController, String?> {
  /// The one-time "sign in again" notice for a connected app (testing-wave
  /// ticket 138, Finding 118-007; Lee 2026-09-26).
  ///
  /// State is the provider id whose notice the Timeline should show, or null.
  /// [IntegrationsRepository.updateSyncStatus] reports every status it writes
  /// through [onSyncStatusWritten], so the notice fires no matter which path
  /// found the dead token: a background sync, Sync Now, or Garmin's backfill.
  ///
  /// Shown once per move into `requires_reauth`: the move is remembered in
  /// SharedPreferences under the provider's key, and a later `success` for the
  /// same provider forgets it, so the next relapse is announced again.
  ///
  /// Repeats are safe: two writes of `requires_reauth` in a row (the same sync
  /// hitting two endpoints) read the same flag and show one notice; a refresh
  /// of the controller re-reads nothing, because the flag lives in prefs.
  const ReconnectNoticeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reconnectNoticeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reconnectNoticeControllerHash();

  @$internal
  @override
  ReconnectNoticeController create() => ReconnectNoticeController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$reconnectNoticeControllerHash() =>
    r'f5e5959cf97f45e4f7f2da361d9f951e6e0d9ae9';

/// The one-time "sign in again" notice for a connected app (testing-wave
/// ticket 138, Finding 118-007; Lee 2026-09-26).
///
/// State is the provider id whose notice the Timeline should show, or null.
/// [IntegrationsRepository.updateSyncStatus] reports every status it writes
/// through [onSyncStatusWritten], so the notice fires no matter which path
/// found the dead token: a background sync, Sync Now, or Garmin's backfill.
///
/// Shown once per move into `requires_reauth`: the move is remembered in
/// SharedPreferences under the provider's key, and a later `success` for the
/// same provider forgets it, so the next relapse is announced again.
///
/// Repeats are safe: two writes of `requires_reauth` in a row (the same sync
/// hitting two endpoints) read the same flag and show one notice; a refresh
/// of the controller re-reads nothing, because the flag lives in prefs.

abstract class _$ReconnectNoticeController extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
