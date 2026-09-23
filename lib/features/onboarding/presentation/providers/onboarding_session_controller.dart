import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../shared/services/app_external_deps.dart';

part 'onboarding_session_controller.g.dart';

/// How [OnboardingSessionController.ensureOnboardingSession] satisfied the
/// "a usable auth session exists" requirement.
enum OnboardingSessionOutcome {
  /// An existing anonymous session was reused — same uid, no auth calls.
  reusedAnonymous,

  /// A signed-in (non-anonymous) session was kept — onboarding proceeds
  /// under the athlete's real uid, no sign-out, no new uid.
  keptAuthenticated,

  /// No session existed, so a fresh anonymous session was minted. The only
  /// path that creates a new auth uid.
  mintedAnonymous,
}

/// Result of establishing the onboarding auth session.
class OnboardingSession {
  const OnboardingSession({required this.userId, required this.outcome});

  final String userId;
  final OnboardingSessionOutcome outcome;
}

const _onboardingTempUserIdKey = 'onboarding_temp_user_id';

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
@riverpod
class OnboardingSessionController extends _$OnboardingSessionController {
  @override
  FutureOr<OnboardingSession?> build() => null;

  /// Reuse the current session if one exists; mint an anonymous one only when
  /// there is none. Returns the resulting [OnboardingSession] (also exposed
  /// via [state]), or null when session establishment failed — callers let
  /// onboarding proceed regardless, matching the pre-fix swallow behavior the
  /// router's /privacy-consent anti-loop guard relies on (see app_router).
  /// Publishing state is BEST-EFFORT. This provider is auto-dispose and the
  /// Welcome screen reaches it with a bare `ref.read(...notifier)` — nothing
  /// listens, so it is disposed while the `signInAnonymously()` round-trip is
  /// still in flight. A bare `state =` then throws "Cannot use the Ref ...
  /// after it has been disposed", and because that assignment sits OUTSIDE
  /// AsyncValue.guard it escapes the method, past the caller, and the
  /// navigation line after the await never runs: the athlete taps
  /// "Build My Plan" and nothing happens, while the anonymous user IS created
  /// server-side. Reported from device 2026-09-21, after sign-out.
  void _publish(AsyncValue<OnboardingSession?> value) {
    if (ref.mounted) state = value;
  }

  Future<OnboardingSession?> ensureOnboardingSession() async {
    _publish(const AsyncLoading());
    final result = await AsyncValue.guard(() async {
      final deps = ref.read(appExternalDepsProvider);
      final supabase = deps.supabaseClient;

      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        // Reuse. This uid is `public.users.id` and everything local and
        // remote is keyed to it — replacing it orphans the athlete's work.
        final outcome = currentUser.isAnonymous
            ? OnboardingSessionOutcome.reusedAnonymous
            : OnboardingSessionOutcome.keptAuthenticated;
        deps.logger.info(
          'Onboarding session: reusing existing session',
          context: 'AUTH',
          data: {'user_id': currentUser.id, 'outcome': outcome.name},
        );
        // Clear the temp user id from any previous onboarding attempt; the
        // restarted flow rewrites it for the current run.
        await deps.sharedPreferences.remove(_onboardingTempUserIdKey);
        return OnboardingSession(userId: currentUser.id, outcome: outcome);
      }

      // No session at all — mint the anonymous session onboarding runs under.
      final response = await supabase.auth.signInAnonymously();
      final user = response.user;
      if (user == null) {
        throw StateError('signInAnonymously returned no user');
      }
      deps.logger.info(
        'Onboarding session: no existing session, minted anonymous session',
        context: 'AUTH',
        data: {'user_id': user.id},
      );
      await deps.sharedPreferences.remove(_onboardingTempUserIdKey);
      return OnboardingSession(
        userId: user.id,
        outcome: OnboardingSessionOutcome.mintedAnonymous,
      );
    });
    _publish(result);
    // Returned from the local result, never from `state` — after disposal
    // `state` is unreadable, and the caller still needs the answer.
    return result.value;
  }
}
