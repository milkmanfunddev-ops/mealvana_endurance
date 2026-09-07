// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_entitlements_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reads its Supabase client and logger from [appExternalDepsProvider] (the
/// seam the widget-test harness mocks) rather than `Supabase.instance`.

@ProviderFor(userEntitlementsRepository)
const userEntitlementsRepositoryProvider =
    UserEntitlementsRepositoryProvider._();

/// Reads its Supabase client and logger from [appExternalDepsProvider] (the
/// seam the widget-test harness mocks) rather than `Supabase.instance`.

final class UserEntitlementsRepositoryProvider
    extends
        $FunctionalProvider<
          UserEntitlementsRepository,
          UserEntitlementsRepository,
          UserEntitlementsRepository
        >
    with $Provider<UserEntitlementsRepository> {
  /// Reads its Supabase client and logger from [appExternalDepsProvider] (the
  /// seam the widget-test harness mocks) rather than `Supabase.instance`.
  const UserEntitlementsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userEntitlementsRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userEntitlementsRepositoryHash();

  @$internal
  @override
  $ProviderElement<UserEntitlementsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  UserEntitlementsRepository create(Ref ref) {
    return userEntitlementsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserEntitlementsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserEntitlementsRepository>(value),
    );
  }
}

String _$userEntitlementsRepositoryHash() =>
    r'cd841dddbfd31556e75171d12c16eb617079a235';
