// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_session_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Ensures a usable Supabase auth session exists before onboarding starts.
///
/// History (Critical bug, 2026-09-17 "new anonymous UID minted per open and
/// sign-out"): the Welcome screen's "Build My Plan" handler used to
/// unconditionally `signOut()` + `signInAnonymously()`. Because the router
/// funnels users to Welcome whenever the local profile lookup misses (schema
/// resync, mid-onboarding kill, post sign-out), every visit forked the
/// athlete onto a fresh anonymous uid, orphaning all data keyed to the old
/// one — 67% of prod devices carried multiple anonymous uids. It also signed
/// out freshly logged-in users whose profile row had not synced yet.
///
/// The rule now: an existing session — anonymous or authenticated — is NEVER
/// signed out and NEVER replaced here. A new anonymous uid is minted only
/// when no session exists at all (nothing to reuse: fresh install, or the
/// refresh token was discarded by an explicit sign-out).

@ProviderFor(OnboardingSessionController)
const onboardingSessionControllerProvider =
    OnboardingSessionControllerProvider._();

/// Ensures a usable Supabase auth session exists before onboarding starts.
///
/// History (Critical bug, 2026-09-17 "new anonymous UID minted per open and
/// sign-out"): the Welcome screen's "Build My Plan" handler used to
/// unconditionally `signOut()` + `signInAnonymously()`. Because the router
/// funnels users to Welcome whenever the local profile lookup misses (schema
/// resync, mid-onboarding kill, post sign-out), every visit forked the
/// athlete onto a fresh anonymous uid, orphaning all data keyed to the old
/// one — 67% of prod devices carried multiple anonymous uids. It also signed
/// out freshly logged-in users whose profile row had not synced yet.
///
/// The rule now: an existing session — anonymous or authenticated — is NEVER
/// signed out and NEVER replaced here. A new anonymous uid is minted only
/// when no session exists at all (nothing to reuse: fresh install, or the
/// refresh token was discarded by an explicit sign-out).
final class OnboardingSessionControllerProvider
    extends
        $AsyncNotifierProvider<
          OnboardingSessionController,
          OnboardingSession?
        > {
  /// Ensures a usable Supabase auth session exists before onboarding starts.
  ///
  /// History (Critical bug, 2026-09-17 "new anonymous UID minted per open and
  /// sign-out"): the Welcome screen's "Build My Plan" handler used to
  /// unconditionally `signOut()` + `signInAnonymously()`. Because the router
  /// funnels users to Welcome whenever the local profile lookup misses (schema
  /// resync, mid-onboarding kill, post sign-out), every visit forked the
  /// athlete onto a fresh anonymous uid, orphaning all data keyed to the old
  /// one — 67% of prod devices carried multiple anonymous uids. It also signed
  /// out freshly logged-in users whose profile row had not synced yet.
  ///
  /// The rule now: an existing session — anonymous or authenticated — is NEVER
  /// signed out and NEVER replaced here. A new anonymous uid is minted only
  /// when no session exists at all (nothing to reuse: fresh install, or the
  /// refresh token was discarded by an explicit sign-out).
  const OnboardingSessionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingSessionControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingSessionControllerHash();

  @$internal
  @override
  OnboardingSessionController create() => OnboardingSessionController();
}

String _$onboardingSessionControllerHash() =>
    r'64180a72fb20856a557458ef9058c377bb6c062a';

/// Ensures a usable Supabase auth session exists before onboarding starts.
///
/// History (Critical bug, 2026-09-17 "new anonymous UID minted per open and
/// sign-out"): the Welcome screen's "Build My Plan" handler used to
/// unconditionally `signOut()` + `signInAnonymously()`. Because the router
/// funnels users to Welcome whenever the local profile lookup misses (schema
/// resync, mid-onboarding kill, post sign-out), every visit forked the
/// athlete onto a fresh anonymous uid, orphaning all data keyed to the old
/// one — 67% of prod devices carried multiple anonymous uids. It also signed
/// out freshly logged-in users whose profile row had not synced yet.
///
/// The rule now: an existing session — anonymous or authenticated — is NEVER
/// signed out and NEVER replaced here. A new anonymous uid is minted only
/// when no session exists at all (nothing to reuse: fresh install, or the
/// refresh token was discarded by an explicit sign-out).

abstract class _$OnboardingSessionController
    extends $AsyncNotifier<OnboardingSession?> {
  FutureOr<OnboardingSession?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<OnboardingSession?>, OnboardingSession?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<OnboardingSession?>, OnboardingSession?>,
              AsyncValue<OnboardingSession?>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
