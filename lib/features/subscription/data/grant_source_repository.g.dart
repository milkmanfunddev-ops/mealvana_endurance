// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grant_source_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reads its Supabase client from [appExternalDepsProvider] (the seam the
/// widget-test harness mocks) rather than `Supabase.instance`.

@ProviderFor(grantSourceRepository)
const grantSourceRepositoryProvider = GrantSourceRepositoryProvider._();

/// Reads its Supabase client from [appExternalDepsProvider] (the seam the
/// widget-test harness mocks) rather than `Supabase.instance`.

final class GrantSourceRepositoryProvider
    extends
        $FunctionalProvider<
          GrantSourceRepository,
          GrantSourceRepository,
          GrantSourceRepository
        >
    with $Provider<GrantSourceRepository> {
  /// Reads its Supabase client from [appExternalDepsProvider] (the seam the
  /// widget-test harness mocks) rather than `Supabase.instance`.
  const GrantSourceRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'grantSourceRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$grantSourceRepositoryHash();

  @$internal
  @override
  $ProviderElement<GrantSourceRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GrantSourceRepository create(Ref ref) {
    return grantSourceRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GrantSourceRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GrantSourceRepository>(value),
    );
  }
}

String _$grantSourceRepositoryHash() =>
    r'6ed689c21f8b3898bb62efbcd2536033365f0496';
