// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vana_chat_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Shared transport (auth headers, error mapping, NDJSON splitting). Reads
/// its Supabase client from [appExternalDepsProvider] — the seam the
/// widget-test harness mocks.

@ProviderFor(vanaTransport)
const vanaTransportProvider = VanaTransportProvider._();

/// Shared transport (auth headers, error mapping, NDJSON splitting). Reads
/// its Supabase client from [appExternalDepsProvider] — the seam the
/// widget-test harness mocks.

final class VanaTransportProvider
    extends $FunctionalProvider<VanaTransport, VanaTransport, VanaTransport>
    with $Provider<VanaTransport> {
  /// Shared transport (auth headers, error mapping, NDJSON splitting). Reads
  /// its Supabase client from [appExternalDepsProvider] — the seam the
  /// widget-test harness mocks.
  const VanaTransportProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vanaTransportProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vanaTransportHash();

  @$internal
  @override
  $ProviderElement<VanaTransport> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VanaTransport create(Ref ref) {
    return vanaTransport(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VanaTransport value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VanaTransport>(value),
    );
  }
}

String _$vanaTransportHash() => r'b6ea7368fb1c07ba460f2936b6477e1fdb3e2190';

/// The Vana chat client against `vana-chat` (planning + general).

@ProviderFor(vanaChatRepository)
const vanaChatRepositoryProvider = VanaChatRepositoryProvider._();

/// The Vana chat client against `vana-chat` (planning + general).

final class VanaChatRepositoryProvider
    extends
        $FunctionalProvider<
          VanaChatRepository,
          VanaChatRepository,
          VanaChatRepository
        >
    with $Provider<VanaChatRepository> {
  /// The Vana chat client against `vana-chat` (planning + general).
  const VanaChatRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vanaChatRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vanaChatRepositoryHash();

  @$internal
  @override
  $ProviderElement<VanaChatRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VanaChatRepository create(Ref ref) {
    return vanaChatRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VanaChatRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VanaChatRepository>(value),
    );
  }
}

String _$vanaChatRepositoryHash() =>
    r'1cc9f7caf18c1a118753c7e021081796859698d3';
