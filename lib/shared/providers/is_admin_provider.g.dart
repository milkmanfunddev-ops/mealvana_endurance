// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'is_admin_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the signed-in user is a team admin (`users.is_admin`, set by hand
/// in the database — mp-144 clause 3). The flag gates admin-only surfaces
/// such as the meal review box; the server enforces the same flag in RLS,
/// so this read is only about what to show.
///
/// One small select per session (`keepAlive`): the cached `user_profiles`
/// row does not carry the flag and a Drift schema bump for a read-only
/// boolean is not worth it. Signed out, or any read failure, means `false`.

@ProviderFor(isAdmin)
const isAdminProvider = IsAdminProvider._();

/// Whether the signed-in user is a team admin (`users.is_admin`, set by hand
/// in the database — mp-144 clause 3). The flag gates admin-only surfaces
/// such as the meal review box; the server enforces the same flag in RLS,
/// so this read is only about what to show.
///
/// One small select per session (`keepAlive`): the cached `user_profiles`
/// row does not carry the flag and a Drift schema bump for a read-only
/// boolean is not worth it. Signed out, or any read failure, means `false`.

final class IsAdminProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether the signed-in user is a team admin (`users.is_admin`, set by hand
  /// in the database — mp-144 clause 3). The flag gates admin-only surfaces
  /// such as the meal review box; the server enforces the same flag in RLS,
  /// so this read is only about what to show.
  ///
  /// One small select per session (`keepAlive`): the cached `user_profiles`
  /// row does not carry the flag and a Drift schema bump for a read-only
  /// boolean is not worth it. Signed out, or any read failure, means `false`.
  const IsAdminProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isAdminProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isAdminHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return isAdmin(ref);
  }
}

String _$isAdminHash() => r'6069375e80dded575b8eff4b2c38a3358094059d';
