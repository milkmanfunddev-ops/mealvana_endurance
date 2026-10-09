// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reconnect_notice_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The providers whose integrations row needs a reconnect (active and
/// `requires_reauth`), from a Drift watch on the athlete's rows (ticket 77,
/// Finding 68-008). Every write reaches it: this device's own status write,
/// a pull that brought another device's write, a reconnect clearing the
/// status, a disconnect deactivating the row.

@ProviderFor(integrationsNeedingReconnect)
const integrationsNeedingReconnectProvider =
    IntegrationsNeedingReconnectFamily._();

/// The providers whose integrations row needs a reconnect (active and
/// `requires_reauth`), from a Drift watch on the athlete's rows (ticket 77,
/// Finding 68-008). Every write reaches it: this device's own status write,
/// a pull that brought another device's write, a reconnect clearing the
/// status, a disconnect deactivating the row.

final class IntegrationsNeedingReconnectProvider
    extends
        $FunctionalProvider<
          AsyncValue<Set<String>>,
          Set<String>,
          Stream<Set<String>>
        >
    with $FutureModifier<Set<String>>, $StreamProvider<Set<String>> {
  /// The providers whose integrations row needs a reconnect (active and
  /// `requires_reauth`), from a Drift watch on the athlete's rows (ticket 77,
  /// Finding 68-008). Every write reaches it: this device's own status write,
  /// a pull that brought another device's write, a reconnect clearing the
  /// status, a disconnect deactivating the row.
  const IntegrationsNeedingReconnectProvider._({
    required IntegrationsNeedingReconnectFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'integrationsNeedingReconnectProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$integrationsNeedingReconnectHash();

  @override
  String toString() {
    return r'integrationsNeedingReconnectProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Set<String>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Set<String>> create(Ref ref) {
    final argument = this.argument as String;
    return integrationsNeedingReconnect(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is IntegrationsNeedingReconnectProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$integrationsNeedingReconnectHash() =>
    r'3171bc52987d88522635a02671fe8d39e1e1d610';

/// The providers whose integrations row needs a reconnect (active and
/// `requires_reauth`), from a Drift watch on the athlete's rows (ticket 77,
/// Finding 68-008). Every write reaches it: this device's own status write,
/// a pull that brought another device's write, a reconnect clearing the
/// status, a disconnect deactivating the row.

final class IntegrationsNeedingReconnectFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Set<String>>, String> {
  const IntegrationsNeedingReconnectFamily._()
    : super(
        retry: null,
        name: r'integrationsNeedingReconnectProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// The providers whose integrations row needs a reconnect (active and
  /// `requires_reauth`), from a Drift watch on the athlete's rows (ticket 77,
  /// Finding 68-008). Every write reaches it: this device's own status write,
  /// a pull that brought another device's write, a reconnect clearing the
  /// status, a disconnect deactivating the row.

  IntegrationsNeedingReconnectProvider call(String userId) =>
      IntegrationsNeedingReconnectProvider._(argument: userId, from: this);

  @override
  String toString() => r'integrationsNeedingReconnectProvider';
}

/// One pull of the athlete's integrations rows per launch (ticket 77,
/// Finding 68-008). `ensureSynced` skips a repository synced within the
/// hour, and Garmin is push-only, so a row another device moved to
/// `requires_reauth` never reached this one. keepAlive makes this once per
/// process per user. The coordinator uploads dirty rows first, then pulls,
/// and records its own skips (offline: `info`) and failures (`fault`).

@ProviderFor(integrationRowsLaunchPull)
const integrationRowsLaunchPullProvider = IntegrationRowsLaunchPullFamily._();

/// One pull of the athlete's integrations rows per launch (ticket 77,
/// Finding 68-008). `ensureSynced` skips a repository synced within the
/// hour, and Garmin is push-only, so a row another device moved to
/// `requires_reauth` never reached this one. keepAlive makes this once per
/// process per user. The coordinator uploads dirty rows first, then pulls,
/// and records its own skips (offline: `info`) and failures (`fault`).

final class IntegrationRowsLaunchPullProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// One pull of the athlete's integrations rows per launch (ticket 77,
  /// Finding 68-008). `ensureSynced` skips a repository synced within the
  /// hour, and Garmin is push-only, so a row another device moved to
  /// `requires_reauth` never reached this one. keepAlive makes this once per
  /// process per user. The coordinator uploads dirty rows first, then pulls,
  /// and records its own skips (offline: `info`) and failures (`fault`).
  const IntegrationRowsLaunchPullProvider._({
    required IntegrationRowsLaunchPullFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'integrationRowsLaunchPullProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$integrationRowsLaunchPullHash();

  @override
  String toString() {
    return r'integrationRowsLaunchPullProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    final argument = this.argument as String;
    return integrationRowsLaunchPull(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is IntegrationRowsLaunchPullProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$integrationRowsLaunchPullHash() =>
    r'd92df24dbe6e6de01902298a9be68c0ef1b32c65';

/// One pull of the athlete's integrations rows per launch (ticket 77,
/// Finding 68-008). `ensureSynced` skips a repository synced within the
/// hour, and Garmin is push-only, so a row another device moved to
/// `requires_reauth` never reached this one. keepAlive makes this once per
/// process per user. The coordinator uploads dirty rows first, then pulls,
/// and records its own skips (offline: `info`) and failures (`fault`).

final class IntegrationRowsLaunchPullFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<void>, String> {
  const IntegrationRowsLaunchPullFamily._()
    : super(
        retry: null,
        name: r'integrationRowsLaunchPullProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// One pull of the athlete's integrations rows per launch (ticket 77,
  /// Finding 68-008). `ensureSynced` skips a repository synced within the
  /// hour, and Garmin is push-only, so a row another device moved to
  /// `requires_reauth` never reached this one. keepAlive makes this once per
  /// process per user. The coordinator uploads dirty rows first, then pulls,
  /// and records its own skips (offline: `info`) and failures (`fault`).

  IntegrationRowsLaunchPullProvider call(String userId) =>
      IntegrationRowsLaunchPullProvider._(argument: userId, from: this);

  @override
  String toString() => r'integrationRowsLaunchPullProvider';
}

/// The "sign in again" notice for a connected app on the Timeline (ticket
/// 138, Finding 118-007; ticket 77 ruling of 2026-10-09).
///
/// State is the provider id whose notice the Timeline shows, or null. It is
/// derived from the integrations rows ([integrationsNeedingReconnectProvider])
/// on every device and every launch, until the row changes; a launch pull
/// ([integrationRowsLaunchPullProvider]) brings the server's rows in first.
///
/// [dismiss] (the X or Reconnect) hides the shown provider for this launch
/// only; the next provider needing a reconnect then shows. The dismissed set
/// lives in memory, so the notice is back on the next launch while the row
/// still says `requires_reauth`.

@ProviderFor(ReconnectNoticeController)
const reconnectNoticeControllerProvider = ReconnectNoticeControllerProvider._();

/// The "sign in again" notice for a connected app on the Timeline (ticket
/// 138, Finding 118-007; ticket 77 ruling of 2026-10-09).
///
/// State is the provider id whose notice the Timeline shows, or null. It is
/// derived from the integrations rows ([integrationsNeedingReconnectProvider])
/// on every device and every launch, until the row changes; a launch pull
/// ([integrationRowsLaunchPullProvider]) brings the server's rows in first.
///
/// [dismiss] (the X or Reconnect) hides the shown provider for this launch
/// only; the next provider needing a reconnect then shows. The dismissed set
/// lives in memory, so the notice is back on the next launch while the row
/// still says `requires_reauth`.
final class ReconnectNoticeControllerProvider
    extends $NotifierProvider<ReconnectNoticeController, String?> {
  /// The "sign in again" notice for a connected app on the Timeline (ticket
  /// 138, Finding 118-007; ticket 77 ruling of 2026-10-09).
  ///
  /// State is the provider id whose notice the Timeline shows, or null. It is
  /// derived from the integrations rows ([integrationsNeedingReconnectProvider])
  /// on every device and every launch, until the row changes; a launch pull
  /// ([integrationRowsLaunchPullProvider]) brings the server's rows in first.
  ///
  /// [dismiss] (the X or Reconnect) hides the shown provider for this launch
  /// only; the next provider needing a reconnect then shows. The dismissed set
  /// lives in memory, so the notice is back on the next launch while the row
  /// still says `requires_reauth`.
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
    r'2da3cc02f20a049b19fa16c28775f56e40ba08df';

/// The "sign in again" notice for a connected app on the Timeline (ticket
/// 138, Finding 118-007; ticket 77 ruling of 2026-10-09).
///
/// State is the provider id whose notice the Timeline shows, or null. It is
/// derived from the integrations rows ([integrationsNeedingReconnectProvider])
/// on every device and every launch, until the row changes; a launch pull
/// ([integrationRowsLaunchPullProvider]) brings the server's rows in first.
///
/// [dismiss] (the X or Reconnect) hides the shown provider for this launch
/// only; the next provider needing a reconnect then shows. The dismissed set
/// lives in memory, so the notice is back on the next launch while the row
/// still says `requires_reauth`.

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
