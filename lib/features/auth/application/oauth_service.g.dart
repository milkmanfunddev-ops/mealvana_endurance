// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'oauth_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Service for handling OAuth account linking via native SDKs
/// Uses native Google Sign-In and Apple Sign-In packages
/// Links OAuth identities to existing anonymous users via linkIdentityWithIdToken()
/// Preserves user ID and all user data during account linking
/// Follows Andrea Bizzotto's AsyncNotifier pattern with @riverpod

@ProviderFor(OAuthService)
const oAuthServiceProvider = OAuthServiceProvider._();

/// Service for handling OAuth account linking via native SDKs
/// Uses native Google Sign-In and Apple Sign-In packages
/// Links OAuth identities to existing anonymous users via linkIdentityWithIdToken()
/// Preserves user ID and all user data during account linking
/// Follows Andrea Bizzotto's AsyncNotifier pattern with @riverpod
final class OAuthServiceProvider
    extends $AsyncNotifierProvider<OAuthService, void> {
  /// Service for handling OAuth account linking via native SDKs
  /// Uses native Google Sign-In and Apple Sign-In packages
  /// Links OAuth identities to existing anonymous users via linkIdentityWithIdToken()
  /// Preserves user ID and all user data during account linking
  /// Follows Andrea Bizzotto's AsyncNotifier pattern with @riverpod
  const OAuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'oAuthServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$oAuthServiceHash();

  @$internal
  @override
  OAuthService create() => OAuthService();
}

String _$oAuthServiceHash() => r'bae3ba350bde2b3c370d43dc657f4ea7a55e2af2';

/// Service for handling OAuth account linking via native SDKs
/// Uses native Google Sign-In and Apple Sign-In packages
/// Links OAuth identities to existing anonymous users via linkIdentityWithIdToken()
/// Preserves user ID and all user data during account linking
/// Follows Andrea Bizzotto's AsyncNotifier pattern with @riverpod

abstract class _$OAuthService extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    build();
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleValue(ref, null);
  }
}
