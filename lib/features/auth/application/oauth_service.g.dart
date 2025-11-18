// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'oauth_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Service for handling OAuth account linking via Supabase web flow
/// Uses Supabase's hosted OAuth (no native dependencies required)
/// Follows Andrea Bizzotto's AsyncNotifier pattern with @riverpod

@ProviderFor(OAuthService)
const oAuthServiceProvider = OAuthServiceProvider._();

/// Service for handling OAuth account linking via Supabase web flow
/// Uses Supabase's hosted OAuth (no native dependencies required)
/// Follows Andrea Bizzotto's AsyncNotifier pattern with @riverpod
final class OAuthServiceProvider
    extends $AsyncNotifierProvider<OAuthService, void> {
  /// Service for handling OAuth account linking via Supabase web flow
  /// Uses Supabase's hosted OAuth (no native dependencies required)
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

String _$oAuthServiceHash() => r'4249ec7dd1d41d97834d96dd220a6d844a612fc2';

/// Service for handling OAuth account linking via Supabase web flow
/// Uses Supabase's hosted OAuth (no native dependencies required)
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
