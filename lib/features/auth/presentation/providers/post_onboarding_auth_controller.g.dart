// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_onboarding_auth_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for managing post-onboarding authentication flow
/// Handles Apple Sign-In, Google Sign-In, and Email/Password signup

@ProviderFor(PostOnboardingAuthController)
const postOnboardingAuthControllerProvider =
    PostOnboardingAuthControllerProvider._();

/// Controller for managing post-onboarding authentication flow
/// Handles Apple Sign-In, Google Sign-In, and Email/Password signup
final class PostOnboardingAuthControllerProvider
    extends $AsyncNotifierProvider<PostOnboardingAuthController, void> {
  /// Controller for managing post-onboarding authentication flow
  /// Handles Apple Sign-In, Google Sign-In, and Email/Password signup
  const PostOnboardingAuthControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'postOnboardingAuthControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$postOnboardingAuthControllerHash();

  @$internal
  @override
  PostOnboardingAuthController create() => PostOnboardingAuthController();
}

String _$postOnboardingAuthControllerHash() =>
    r'abac4cc51a9f9bc05162737885273db223895698';

/// Controller for managing post-onboarding authentication flow
/// Handles Apple Sign-In, Google Sign-In, and Email/Password signup

abstract class _$PostOnboardingAuthController extends $AsyncNotifier<void> {
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
