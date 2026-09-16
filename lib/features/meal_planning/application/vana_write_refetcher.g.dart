// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vana_write_refetcher.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Keeps the device's offline-first stores honest after a write Vana made
/// on the server (Lee's playtest 2026-09-16 §10).
///
/// Events and meal logs are owned locally (Drift, `needs_upload`,
/// `ensureSynced`); a server-side write bypasses all of that, so a
/// `receipt` part is the cue to pull the store it names. This is the least
/// invasive hook available: the repositories already have a remote pull
/// (`syncFromRemote`, dirty rows preserved) and the coordinator already has
/// a forced entry point for it, so the refetch is one forced sync of one
/// repository plus an invalidate of the read providers that do not stream
/// from Drift. Nothing new is written locally and no screen changes how
/// it loads.
///
/// keepAlive: the chat controller reads it once per receipt, and an
/// auto-dispose provider would hand it a dead [Ref] the moment the read
/// returned.

@ProviderFor(vanaWriteRefetcher)
const vanaWriteRefetcherProvider = VanaWriteRefetcherProvider._();

/// Keeps the device's offline-first stores honest after a write Vana made
/// on the server (Lee's playtest 2026-09-16 §10).
///
/// Events and meal logs are owned locally (Drift, `needs_upload`,
/// `ensureSynced`); a server-side write bypasses all of that, so a
/// `receipt` part is the cue to pull the store it names. This is the least
/// invasive hook available: the repositories already have a remote pull
/// (`syncFromRemote`, dirty rows preserved) and the coordinator already has
/// a forced entry point for it, so the refetch is one forced sync of one
/// repository plus an invalidate of the read providers that do not stream
/// from Drift. Nothing new is written locally and no screen changes how
/// it loads.
///
/// keepAlive: the chat controller reads it once per receipt, and an
/// auto-dispose provider would hand it a dead [Ref] the moment the read
/// returned.

final class VanaWriteRefetcherProvider
    extends
        $FunctionalProvider<
          VanaWriteRefetcher,
          VanaWriteRefetcher,
          VanaWriteRefetcher
        >
    with $Provider<VanaWriteRefetcher> {
  /// Keeps the device's offline-first stores honest after a write Vana made
  /// on the server (Lee's playtest 2026-09-16 §10).
  ///
  /// Events and meal logs are owned locally (Drift, `needs_upload`,
  /// `ensureSynced`); a server-side write bypasses all of that, so a
  /// `receipt` part is the cue to pull the store it names. This is the least
  /// invasive hook available: the repositories already have a remote pull
  /// (`syncFromRemote`, dirty rows preserved) and the coordinator already has
  /// a forced entry point for it, so the refetch is one forced sync of one
  /// repository plus an invalidate of the read providers that do not stream
  /// from Drift. Nothing new is written locally and no screen changes how
  /// it loads.
  ///
  /// keepAlive: the chat controller reads it once per receipt, and an
  /// auto-dispose provider would hand it a dead [Ref] the moment the read
  /// returned.
  const VanaWriteRefetcherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vanaWriteRefetcherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vanaWriteRefetcherHash();

  @$internal
  @override
  $ProviderElement<VanaWriteRefetcher> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VanaWriteRefetcher create(Ref ref) {
    return vanaWriteRefetcher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VanaWriteRefetcher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VanaWriteRefetcher>(value),
    );
  }
}

String _$vanaWriteRefetcherHash() =>
    r'6b07f08b4188fe09baadfc7a9e6fa181ad735db3';
