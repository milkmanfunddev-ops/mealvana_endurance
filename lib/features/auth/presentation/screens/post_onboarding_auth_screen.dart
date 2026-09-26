import 'dart:async' show unawaited;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../../shared/services/sync/sync_coordinator.dart';
import '../../../content/application/content_service.dart';
import '../../../daily_macros/application/daily_macro_service.dart';
import '../../../daily_macros/data/daily_macro_targets_repository.dart';
import '../../../daily_macros/presentation/providers/daily_macros_controller.dart';
import '../../../onboarding/presentation/providers/onboarding_controller.dart';
import '../../../onboarding/presentation/theme/onboarding_design_tokens.dart';
import '../../../onboarding/presentation/widgets/onboarding_multi_select_step.dart';
import '../../../onboarding/presentation/widgets/onboarding_step_scaffold.dart';
import '../../../content/domain/content_keys.dart';
import '../../application/email_auth_handoff.dart';
import '../../../subscription/application/pro_gate.dart';
import '../../../subscription/application/pro_paywall_controller.dart';
import '../../../subscription/presentation/pro_gate_redirect.dart';
import '../../application/auth_service.dart';
import '../../application/grace_claim_service.dart';
import '../providers/post_onboarding_auth_controller.dart';
import '../../domain/auth_exceptions.dart';
import '../../../coach_mode/application/coach_service.dart';

/// Post-Onboarding Authentication Screen
/// Shown after the daily-plan preview (2026-08 onboarding redesign). The
/// account is required: it holds the plan and the subscription the paywall
/// sells next (mp-279 maps the purchase onto the auth id), so there is no
/// guest path (Lee, 2026-09-16). Offers Apple Sign-In, Google Sign-In and
/// Email/Password; the one line under the title states the trial terms so
/// the plan screen that follows is expected, not a surprise.
/// Visual language matches the redesigned onboarding steps (dark blackberry
/// scaffold, Sansita/orange title).
///
/// Sign-up creates the account first and writes the waiting onboarding
/// draft to it (mp-459); the screen never starts a session. The one place
/// it still meets an anonymous user is an install left anonymous from
/// before the paywall (mp-455): that user is linked onto, never replaced,
/// so its data survives. The pre-paywall wiring that opened an anonymous
/// session to link against is kept in
/// lib/features/_archived/anonymous_session/.
class PostOnboardingAuthScreen extends ConsumerStatefulWidget {
  const PostOnboardingAuthScreen({super.key, this.mode = 'signup'});

  final String mode;

  @override
  ConsumerState<PostOnboardingAuthScreen> createState() =>
      _PostOnboardingAuthScreenState();
}

class _PostOnboardingAuthScreenState
    extends ConsumerState<PostOnboardingAuthScreen> {
  /// Whether this screen opened on an install left anonymous from before the
  /// paywall (mp-455 §4). Taken once, on arrival: after the link the session
  /// is no longer anonymous, and the email path reports back later.
  late final bool _openedOnOldAnonymousInstall;

  @override
  void initState() {
    super.initState();
    _openedOnOldAnonymousInstall =
        widget.mode != 'login' && _linksOldAnonymousInstall;

    ref
        .read(appExternalDepsProvider)
        .analytics
        .track(
          'screen_viewed',
          properties: {
            'screen_name': 'Post-Onboarding Auth',
            'mode': widget.mode,
          },
        );
  }

  /// Whether sign-up must link onto an anonymous user already on this
  /// install (mp-455: an install left anonymous from before the paywall).
  /// Linking keeps the uid, so everything synced under it survives. A fresh
  /// install has no session at all and signs in outright.
  bool get _linksOldAnonymousInstall {
    final currentUser = ref
        .read(appExternalDepsProvider)
        .supabaseClient
        .auth
        .currentUser;
    return currentUser != null && currentUser.isAnonymous;
  }

  Future<void> _handleAppleSignIn() async {
    final controller = ref.read(postOnboardingAuthControllerProvider.notifier);
    final isLogin = widget.mode == 'login';
    final linksOldInstall = !isLogin && _linksOldAnonymousInstall;

    // Link (throws AccountAlreadyExistsException if the provider is taken)
    // or sign in: the sign-in creates the account when none exists.
    final bool success = linksOldInstall
        ? await controller.linkAppleAccount()
        : await controller.signInWithApple();

    if (!mounted) return;

    if (success) {
      // On web, the OAuth flow triggers a redirect, so we shouldn't navigate manually.
      // The browser will reload the app after the user authenticates.
      if (kIsWeb) return;

      if (isLogin) {
        await _navigateToMain();
      } else if (linksOldInstall) {
        await _saveOnboardingDataAndNavigate(
          authProvider: 'apple',
          claimGrace: true,
        );
      } else {
        // A new account takes the waiting draft; an existing, set-up account
        // keeps its own settings.
        await _finishLoginPreservingDraft(authProvider: 'apple');
      }
    } else {
      _handleError(context, 'Apple');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final controller = ref.read(postOnboardingAuthControllerProvider.notifier);
    final isLogin = widget.mode == 'login';
    final linksOldInstall = !isLogin && _linksOldAnonymousInstall;

    // Link (throws AccountAlreadyExistsException if the provider is taken)
    // or sign in: the sign-in creates the account when none exists.
    final bool success = linksOldInstall
        ? await controller.linkGoogleAccount()
        : await controller.signInWithGoogle();

    if (!mounted) return;

    if (success) {
      // On web, the OAuth flow triggers a redirect, so we shouldn't navigate manually.
      // The browser will reload the app after the user authenticates.
      if (kIsWeb) return;

      if (isLogin) {
        await _navigateToMain();
      } else if (linksOldInstall) {
        await _saveOnboardingDataAndNavigate(
          authProvider: 'google',
          claimGrace: true,
        );
      } else {
        // A new account takes the waiting draft; an existing, set-up account
        // keeps its own settings.
        await _finishLoginPreservingDraft(authProvider: 'google');
      }
    } else {
      _handleError(context, 'Google');
    }
  }

  void _handleError(BuildContext context, String providerName) {
    final state = ref.read(postOnboardingAuthControllerProvider);

    // The athlete closed the provider's sheet (125-003): nothing failed, so
    // nothing is said.
    if (state.hasError && state.error is OAuthCancelledException) return;

    // Check if the error is because the account already exists
    if (state.hasError && state.error is AccountAlreadyExistsException) {
      final exception = state.error as AccountAlreadyExistsException;
      _showAccountExistsDialog(context, providerName, exception.email);
      return;
    }

    // LOGIN mode reached no existing account for this provider identity (the
    // sign-in that would have minted an empty account was refused). Say which
    // way is home instead of a generic failure — the athlete's data lives
    // under the provider or email they originally signed up with.
    if (state.hasError && state.error is OAuthAccountNotFoundException) {
      final contentService = ref.read(contentServiceProvider);
      MealvanaSnackbar.showError(
        context,
        contentService.getValue(
          'auth.error.no_account_for_provider',
          defaultValue:
              'No account was found for this $providerName account. '
              'Try logging in with the provider or email you originally '
              'signed up with.',
        ),
      );
      return;
    }

    // Show generic error message
    final contentService = ref.read(contentServiceProvider);
    MealvanaSnackbar.showError(
      context,
      contentService.getValue(
        'auth.post_onboarding.error_oauth_failed',
        defaultValue: 'Sign in failed. Please try again.',
      ),
    );
  }

  Future<void> _showAccountExistsDialog(
    BuildContext context,
    String provider,
    String? email,
  ) async {
    final contentService = ref.read(contentServiceProvider);

    // Dialog implementation using standard showDialog for now
    // In the future we should use a styled dialog from Kyle design system
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          contentService.getValue(
            'auth.error.account_exists_title',
            defaultValue: 'Account Already Exists',
          ),
        ),
        content: Text(
          [
            contentService.getValue(
              'auth.error.account_exists_message',
              defaultValue:
                  'This $provider account ${email != null ? "($email) " : ""}is already linked to another user.',
            ),
            // Be honest about what "Log In" does to the just-finished
            // onboarding: an already-set-up account keeps its own settings.
            if (ref
                .read(onboardingControllerProvider.notifier)
                .hasCompletedProfileDraft)
              contentService.getValue(
                'auth.error.account_exists_draft_note',
                defaultValue:
                    'If you log in and that account is already set up, its '
                    'saved settings will be used instead of the answers you '
                    'just entered.',
              ),
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Cancel
            },
            child: Text(
              contentService.getValue('common.cancel', defaultValue: 'Cancel'),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/auth/email-signup');
            },
            child: Text(
              contentService.getValue(
                'auth.error.use_email',
                defaultValue: 'Use Email Instead',
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Trigger sign in (orphaning current user)
              if (provider == 'Google') {
                await _signInWithGoogle();
              } else {
                await _signInWithApple();
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.dragonfruit),
            child: Text(
              contentService.getValue(
                'auth.error.login_lose_data',
                defaultValue: 'Log In',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    final controller = ref.read(postOnboardingAuthControllerProvider.notifier);
    final success = await controller.signInWithGoogle();

    // On web, the OAuth flow triggers a redirect, so we shouldn't navigate manually
    if (kIsWeb) return;

    if (success && mounted) {
      await _finishLoginPreservingDraft(authProvider: 'google');
    }
  }

  Future<void> _signInWithApple() async {
    final controller = ref.read(postOnboardingAuthControllerProvider.notifier);
    final success = await controller.signInWithApple();

    // On web, the OAuth flow triggers a redirect, so we shouldn't navigate manually
    if (kIsWeb) return;

    if (success && mounted) {
      await _finishLoginPreservingDraft(authProvider: 'apple');
    }
  }

  /// Complete a LOGIN (sign-in to an existing account) without discarding a
  /// completed onboarding draft.
  ///
  /// The old behavior navigated straight to /main on every login — but a user
  /// who walked all nine onboarding steps and then tapped "Log In" (or hit the
  /// account-already-exists dialog) still had their entire draft in memory
  /// only, and navigation silently threw it away.
  ///
  /// Policy:
  ///  - If the signed-in account has NOT completed onboarding (no profile, or
  ///    a stub), the draft the user just filled in is saved onto it.
  ///  - If the account already has a completed profile, the account's saved
  ///    settings win (they may be older but were deliberately configured on
  ///    another device); the user is told their answers were not applied.
  Future<void> _finishLoginPreservingDraft({
    required String authProvider,
  }) async {
    final onboardingController = ref.read(
      onboardingControllerProvider.notifier,
    );

    if (onboardingController.hasCompletedProfileDraft) {
      final authService = ref.read(authServiceProvider);
      final contentService = ref.read(contentServiceProvider);
      final existingUser = await authService.getCurrentUser();
      if (!mounted) return;

      if (existingUser == null || !existingUser.onboardingCompleted) {
        // Fresh or stub account: the just-completed onboarding is the best
        // data we have — persist it under the signed-in uid.
        await _saveOnboardingDataAndNavigate(authProvider: authProvider);
        return;
      }

      // Existing, fully-onboarded account: its settings win. Say so instead
      // of silently dropping the user's answers.
      MealvanaSnackbar.showInfo(
        context,
        contentService.getValue(
          'auth.post_onboarding.existing_account_settings_used',
          defaultValue:
              "You're signed in to your existing account, so its saved "
              'settings are being used instead of the answers you just '
              'entered. You can adjust anything in Settings.',
        ),
      );
    }

    await _navigateToMain();
  }

  /// The email screens report success through [emailAuthHandoffProvider],
  /// never through the future `push` returns (see that provider for why).
  /// Wired from [build] with `ref.listen`.
  Future<void> _onEmailAuthSucceeded(EmailAuthHandoffEvent event) async {
    final logger = ref.read(appExternalDepsProvider).logger;
    logger.info(
      'Email auth finished',
      context: 'NAV',
      data: {'kind': event.kind.name, 'seq': event.seq, 'mounted': mounted},
    );
    if (!mounted) return;
    switch (event.kind) {
      case EmailAuthKind.login:
        // Finish without discarding any onboarding draft still in memory.
        await _finishLoginPreservingDraft(authProvider: 'email');
      case EmailAuthKind.signup:
        // The email screen links onto the anonymous user when there is one.
        await _saveOnboardingDataAndNavigate(
          authProvider: 'email',
          claimGrace: _openedOnOldAnonymousInstall,
        );
    }
  }

  void _handleEmailSignUp() {
    ref
        .read(appExternalDepsProvider)
        .logger
        .info('Navigating to email signup screen', context: 'NAV');
    // The result is reported through emailAuthHandoffProvider; the future
    // this returns is not awaited on purpose.
    unawaited(context.push('/auth/email-signup'));
  }

  void _handleEmailLogin() {
    unawaited(context.push('/auth/email-login'));
  }

  /// Navigate directly to main app (for login mode - no onboarding data to save)
  /// On web, coaches are redirected to the coach portal instead.
  Future<void> _navigateToMain() async {
    if (!mounted) return;
    // The gate must be settled for this user before the router is asked
    // (see settleAppGate); otherwise the navigation is dropped mid-redirect.
    final logger = ref.read(appExternalDepsProvider).logger;
    logger.info('Settling the app gate before /main', context: 'NAV');
    final access = await ref.read(appGateProvider.notifier).settle();
    logger.info(
      'App gate settled',
      context: 'NAV',
      data: {'access': access.name, 'mounted': mounted},
    );
    if (!mounted) return;

    // On web, check if user is a coach and redirect to coach portal
    if (kIsWeb) {
      try {
        final isCoach = await ref
            .read(coachServiceProvider)
            .isCurrentUserCoach();
        if (!mounted) return;
        if (isCoach) {
          context.go('/coach-portal');
          return;
        }
      } catch (_) {
        // Fall through to normal /main navigation
      }
    }

    context.go('/main');
  }

  /// Write the waiting onboarding draft to the signed-in account and move
  /// on to the paywall. Saves locally, then uploads in the background.
  /// [authProvider] - 'email', 'google', 'apple'
  /// [claimGrace] - the sign-up just linked onto an install left anonymous
  /// from before the paywall: claim its grace month (mp-455 §4) before the
  /// gate is settled, so a granted account moves on into the app.
  Future<void> _saveOnboardingDataAndNavigate({
    required String authProvider,
    bool claimGrace = false,
  }) async {
    final logger = ref.read(appExternalDepsProvider).logger;
    final onboardingController = ref.read(
      onboardingControllerProvider.notifier,
    );
    // Read before the async gaps below: this screen navigates away mid-flow, so
    // `ref.read` after that point can throw on a disposed ConsumerState.
    final syncCoordinator = ref.read(syncCoordinatorProvider.notifier);
    final contentService = ref.read(contentServiceProvider);
    final graceClaim = claimGrace ? ref.read(graceClaimServiceProvider) : null;
    // For the post-sync macro-cache bust below. The container (not `ref`) is
    // captured because the background upload outlives this screen, and the
    // root container outlives every screen. The macro repository itself is
    // read lazily off the container in there — constructing it eagerly here
    // touches Supabase before some callers (and tests) have initialized it.
    final container = ProviderScope.containerOf(context, listen: false);

    // This screen serves two arrivals:
    //
    //  - FIRST-RUN onboarding, where the draft profile answers are still in
    //    memory and must be written out here.
    //  - Settings -> "Create Account", where onboarding finished long ago.
    //    There is no draft (it is per-run and in-memory), the profile is
    //    already persisted, and the link preserved the uid — so there is
    //    nothing to save and nothing to migrate. Calling saveAllOnboardingData
    //    here returned false on the empty draft and showed the user "Failed to
    //    save your preferences" on an upgrade that had actually succeeded.
    final authService = ref.read(authServiceProvider);
    if (!onboardingController.hasCompletedProfileDraft) {
      final existingUser = await authService.getCurrentUser();
      if (!mounted) return;

      if (existingUser != null) {
        logger.info(
          'Upgrading an already-onboarded account — skipping onboarding save',
          context: 'NAV',
          data: {'authProvider': authProvider, 'userId': existingUser.id},
        );

        // The identity fields were already flipped (locally and in Supabase)
        // by AuthMigrationService.completeAuthentication during the link.
        await graceClaim?.claim();
        if (!mounted) return;
        await ref.read(appGateProvider.notifier).settle();
        if (!mounted) return;
        context.go('/main');

        unawaited(
          _uploadOnboardingDataInBackground(
            userId: existingUser.id,
            onboardingController: onboardingController,
            syncCoordinator: syncCoordinator,
            container: container,
            logger: logger,
          ),
        );
        return;
      }
      // No cache AND no profile: genuinely nothing to work with. Fall through
      // so saveAllOnboardingData reports the failure to the user.
    }

    logger.info(
      'Starting saveAllOnboardingData',
      context: 'NAV',
      data: {'authProvider': authProvider},
    );

    // Save all cached onboarding data (saves to Drift only, marks for background upload)
    final success = await onboardingController.saveAllOnboardingData(
      authProvider: authProvider,
    );

    logger.info(
      'saveAllOnboardingData completed',
      context: 'NAV',
      data: {'success': success, 'mounted': mounted},
    );

    if (!mounted) {
      logger.info(
        'Widget unmounted after save, aborting navigation',
        context: 'NAV',
      );
      return;
    }

    if (success) {
      // Get current user ID for background sync
      final currentUser = await authService.getCurrentUser();

      logger.info(
        'Navigating to the paywall (onboarding mode)',
        context: 'NAV',
        data: {'hasUser': currentUser != null, 'userId': currentUser?.id},
      );

      // Navigate straight after the local save. A new account has no
      // entitlement, so the next step is the plan screen in its onboarding
      // shape (mp-297: onboarding ends on the paywall); the gate's redirect
      // moves an already-unlocked account (admin, restored) on to /main. The
      // upload below still runs if this screen was disposed during the
      // lookup above — the data is saved either way and must reach Supabase.
      if (!mounted) return;
      await graceClaim?.claim();
      if (!mounted) return;
      await ref.read(appGateProvider.notifier).settle();
      if (mounted) context.go(kOnboardingPaywallLocation);

      // Push the onboarding data to Supabase in the background. Non-blocking
      // so an offline or slow network never holds up the app; the rows stay
      // dirty and retry.
      if (currentUser != null) {
        unawaited(
          _uploadOnboardingDataInBackground(
            userId: currentUser.id,
            onboardingController: onboardingController,
            syncCoordinator: syncCoordinator,
            container: container,
            logger: logger,
          ),
        );
      }
    } else {
      // Show error if save failed
      logger.error(
        'saveAllOnboardingData FAILED - NOT navigating to /main',
        context: 'NAV',
      );
      MealvanaSnackbar.showError(
        context,
        contentService.getValue(
          'auth.post_onboarding.error_save_failed',
          defaultValue: 'Failed to save your preferences. Please try again.',
        ),
      );
    }
  }

  /// Upload the just-saved onboarding data, then run a full sync.
  ///
  /// Deliberately result-checked at both steps: `uploadDirtyRecords()` reports
  /// failure by returning `UploadResult.failed()` rather than throwing, and
  /// `sync()` returns false instead of throwing, so a fire-and-forget call with
  /// no inspection cannot distinguish "uploaded" from "silently lost".
  ///
  /// Takes its collaborators as parameters rather than reading them off `ref`:
  /// it is started unawaited straight after `context.go('/main')`, by which
  /// point this ConsumerState can already be disposed and `ref.read` would
  /// throw. Both notifiers outlive the screen (SyncCoordinator is keepAlive,
  /// OnboardingController calls `ref.keepAlive()`).
  static Future<void> _uploadOnboardingDataInBackground({
    required String userId,
    required OnboardingController onboardingController,
    required SyncCoordinator syncCoordinator,
    required ProviderContainer container,
    required AppLogger logger,
  }) async {
    try {
      final failedRepos = await onboardingController
          .uploadOnboardingDataToSupabase(userId);

      if (failedRepos.isNotEmpty) {
        logger.error(
          'Onboarding data upload incomplete',
          context: 'ONBOARDING_SYNC',
          data: {'userId': userId, 'failedRepos': failedRepos},
        );
      }

      // Follow with a full sync so the download half runs too (and so any
      // repository not covered by the dirty-record walk gets its chance).
      final synced = await syncCoordinator.sync(
        userId: userId,
        trigger: SyncTrigger.manual,
      );

      if (!synced) {
        logger.warning(
          'Post-onboarding sync did not complete — onboarding rows remain '
          'marked needs_upload and will retry',
          context: 'ONBOARDING_SYNC',
          data: {'userId': userId},
        );
      }

      // Bust the daily-macro cache now that the full activity picture is in
      // Drift. The dashboard mounts (and fires its one edge-function calc)
      // BEFORE this background sync lands the user's workouts, so the first
      // cached row is computed session-less — a rest-day TDEE (e.g. 0/2380)
      // that sticks until a manual refresh, because `daily_macro_targets`
      // rows have no TTL and nothing in the sync path invalidates them. The
      // user has at most days of cache at this point, so the blanket wipe
      // costs one recompute. Invalidating the controller through the root
      // container (this screen is disposed by now) triggers that recompute.
      //
      // Bump the week revisions FIRST: the dashboard's mount-time calc may
      // still be in flight, and without a revision bump the recreated
      // controller would JOIN that session-less pass (single-flight) and its
      // late save would re-cache the exact stale rows this wipe removes.
      final now = DateTime.now();
      container
          .read(dailyMacroServiceProvider)
          .markMacroInputsChanged(
            userId,
            List.generate(14, (i) => now.add(Duration(days: i - 7))),
          );
      await container
          .read(dailyMacroTargetsRepositoryProvider)
          .invalidateAllForUser(userId);
      container.invalidate(dailyMacrosControllerProvider);
    } catch (e, stackTrace) {
      logger.error(
        'Post-onboarding upload failed',
        context: 'ONBOARDING_SYNC',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<EmailAuthHandoffEvent?>(emailAuthHandoffProvider, (
      previous,
      next,
    ) {
      if (next != null && next != previous) _onEmailAuthSucceeded(next);
    });
    final asyncState = ref.watch(postOnboardingAuthControllerProvider);
    final contentService = ref.watch(contentServiceProvider);
    final isLogin = widget.mode == 'login';

    return AdaptivePageScaffold(
      backgroundColor: OnbTokens.bg,
      appBar: _buildAppBar(
        context,
        isLoading: asyncState.isLoading,
        isLogin: isLogin,
        // An old anonymous install sent here by the router (mp-455) has no
        // onboarding to go back to and no account yet: sign-up is the way on.
        showBack:
            !(_openedOnOldAnonymousInstall &&
                !context.canPop() &&
                !ref
                    .read(onboardingControllerProvider.notifier)
                    .hasCompletedProfileDraft),
      ),
      contentWidth: AdaptiveContentWidth.narrow,
      body: Stack(
        children: [
          // Main content
          AdaptiveScrollableBody(
            padding: AppSpacing.screenPaddingHorizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xl),

                // Title (spec: cream Sansita 27, left-aligned)
                Text(
                  key: ValueKey(
                    isLogin ? 'login_options.title' : 'post_onboarding.title',
                  ),
                  contentService.getValue(
                    isLogin ? 'auth.login.title' : 'auth.post_onboarding.title',
                    defaultValue: isLogin
                        ? 'Log In'
                        : "Your plan is ready. Don't leave it behind.",
                  ),
                  style: const TextStyle(
                    fontFamily: OnbTokens.fontDisplay,
                    fontSize: 27,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                    color: OnbTokens.cream,
                  ),
                ),

                const SizedBox(height: 8),

                // Subtitle (spec: Apercu 14 cream-62%, left-aligned). In
                // signup mode it is the trial line: the terms of what the
                // next screen sells, from store prices when they load.
                if (isLogin)
                  Text(
                    key: const ValueKey('login_options.subtitle'),
                    contentService.getValue(
                      'auth.login.subtitle',
                      defaultValue: 'Welcome back',
                    ),
                    style: kOnboardingSubtitleStyle,
                  )
                else
                  const _TrialLine(key: ValueKey('post_onboarding.subtitle')),

                const SizedBox(height: 16),

                // Testimonial card (spec content, verbatim).
                if (!isLogin) ...const [
                  _TestimonialCard(),
                  SizedBox(height: 18),
                ],

                // Apple Sign-In button (iOS/Android only) — spec primary:
                // orange filled pill.
                if (!kIsWeb) ...[
                  _SpecAuthButton(
                    key: ValueKey(
                      isLogin
                          ? 'login_options.apple_button'
                          : 'post_onboarding.apple_button',
                    ),
                    label: contentService.getValue(
                      'auth.post_onboarding.apple_button',
                      defaultValue: 'Continue with Apple',
                    ),
                    icon: FontAwesomeIcons.apple.data,
                    background: OnbTokens.orange,
                    foreground: OnbTokens.bg,
                    onPressed: asyncState.isLoading ? null : _handleAppleSignIn,
                    isLoading: asyncState.isLoading,
                  ),

                  // Spec "or" divider between the primary and the rest.
                  const SizedBox(height: 12),
                  const _OrDivider(),
                  const SizedBox(height: 12),
                ],

                // Google Sign-In button — spec: cream filled pill.
                _SpecAuthButton(
                  key: ValueKey(
                    isLogin
                        ? 'login_options.google_button'
                        : 'post_onboarding.google_button',
                  ),
                  label: contentService.getValue(
                    'auth.post_onboarding.google_button',
                    defaultValue: 'Continue with Google',
                  ),
                  icon: FontAwesomeIcons.google.data,
                  background: OnbTokens.cream,
                  foreground: OnbTokens.bg,
                  onPressed: asyncState.isLoading ? null : _handleGoogleSignIn,
                  isLoading: asyncState.isLoading,
                ),

                const SizedBox(height: 10),

                // Email button — spec: outlined pill, cream-75% label.
                _SpecAuthButton(
                  key: ValueKey(
                    isLogin
                        ? 'login_options.email_button'
                        : 'post_onboarding.email_button',
                  ),
                  label: contentService.getValue(
                    isLogin
                        ? 'auth.login.email_button'
                        : 'auth.post_onboarding.email_button',
                    defaultValue: isLogin
                        ? 'Log in with email'
                        : 'Sign up with email',
                  ),
                  background: Colors.transparent,
                  foreground: OnbTokens.creamA(0.75),
                  outlineColor: OnbTokens.creamA(0.2),
                  onPressed: asyncState.isLoading
                      ? null
                      : (isLogin ? _handleEmailLogin : _handleEmailSignUp),
                  isLoading: false,
                ),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),

          // Loading overlay for OAuth sign-in flows
          if (asyncState.isLoading)
            Container(
              color: OnbTokens.bg.withValues(alpha: 0.9),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.orange,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Text(
                    //   contentService.getValue(
                    //     'auth.login.syncing_message',
                    //     defaultValue: 'Signing in and syncing your data...',
                    //   ),
                    //   style: AppTextStyles.bodyMedium.copyWith(
                    //     color: Theme.of(context).colorScheme.onSurface,
                    //   ),
                    //   textAlign: TextAlign.center,
                    // ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context, {
    bool isLoading = false,
    bool isLogin = false,
    bool showBack = true,
  }) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          // Back button (disabled during loading) — spec: the same 32px
          // cream-10% chevron circle as the onboarding step headers.
          if (showBack)
            Opacity(
              opacity: isLoading ? 0.5 : 1.0,
              // A button named "Back" (124-005: the AppBar title merged it
              // out of the accessibility tree).
              child: OnboardingBackCircle(
                key: ValueKey(
                  isLogin
                      ? 'login_options.back_button'
                      : 'create_account.back_button',
                ),
                enabled: !isLoading,
                onTap: () {
                  // Sentry MEALVANA-ENDURANCE-DEV-5R: this screen can be
                  // reached via context.go() (post-onboarding flow) as
                  // well as push(), so guard against GoError "There is
                  // nothing to pop". The go() arrival replaces the stack,
                  // so in the redesigned flow canPop() is false for EVERY
                  // new user landing here — the fallback must return to
                  // the flow they came from, not /main: going to /main
                  // would silently abandon all nine onboarding steps
                  // before saveAllOnboardingData ever runs.
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    // Nothing to pop. LOGIN mode: the person is not
                    // signed in and just asked to go back, so /main
                    // would strand an unauthenticated user in the app.
                    // SIGNUP mode: return to the flow AT ITS LAST PAGE
                    // (?page=last) — a bare /onboarding builds a fresh
                    // PageView at page 0, rewinding the athlete nine
                    // answered steps when they were one tap from saving.
                    context.go(isLogin ? '/welcome' : '/onboarding?page=last');
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Spec testimonial card: cream-5% fill, 1px teal-28% border, radius 15,
/// 14/16 padding. Orange stars, Compadre 15 quote (uppercased for the
/// unicase face), Apercu 11.5 cream-55% attribution. Content is the spec's,
/// verbatim.
class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('post_onboarding.testimonial'),
      decoration: BoxDecoration(
        color: OnbTokens.creamA(0.05),
        borderRadius: BorderRadius.circular(OnbTokens.rCard),
        border: Border.all(color: const Color(0x471CF9CF)), // teal 28%
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      // Spec: stars sit in a left column BESIDE the quote block.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '★★★★★',
            style: TextStyle(
              fontFamily: OnbTokens.fontBody,
              fontSize: 15,
              color: OnbTokens.orange,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '“GETTING NUTRITION RIGHT IS HOW I FINISH MY TRAINING '
                  'BLOCK STRONG AND TOE THE START LINE HEALTHY, FIT, '
                  'AND READY.”',
                  style: TextStyle(
                    fontFamily: OnbTokens.fontLabel,
                    fontSize: 15,
                    height: 1.4,
                    color: OnbTokens.cream,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Xuan H. · 6x marathoner · 2x half IM',
                  style: TextStyle(
                    fontFamily: OnbTokens.fontBody,
                    fontSize: 11.5,
                    color: OnbTokens.creamA(0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Spec "or" divider: cream-15% hairlines flanking an 11.5 cream-40% "or",
/// 12px gaps.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(height: 1, color: OnbTokens.creamA(0.15)),
    );
    return Row(
      children: [
        line,
        const SizedBox(width: 12),
        Text(
          'or',
          style: TextStyle(
            fontFamily: OnbTokens.fontBody,
            fontSize: 11.5,
            color: OnbTokens.creamA(0.4),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: OnbTokens.creamA(0.15))),
      ],
    );
  }
}

/// Spec auth pill: radius 100, 14px vertical padding, Sansita 15/700 label,
/// optional 16px leading icon with a 10px gap. Filled (orange/cream) or
/// outlined (transparent + cream-20% hairline).
class _SpecAuthButton extends StatelessWidget {
  const _SpecAuthButton({
    super.key,
    required this.label,
    this.icon,
    required this.background,
    required this.foreground,
    this.outlineColor,
    required this.onPressed,
    required this.isLoading,
  });

  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final Color? outlineColor;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OnbTokens.rPill),
        side: outlineColor != null
            ? BorderSide(color: outlineColor!)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(OnbTokens.rPill),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: isLoading
              ? Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: foreground),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: OnbTokens.fontDisplay,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: foreground,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// The one line of terms above the sign-in buttons: "{days} days free, then
/// {monthly} a month or {annual} a year. Cancel any time." from the store's
/// prices and introductory offer; the price-free fallback while the store
/// answers or when it cannot. Reads the same plans the paywall renders, so
/// the two screens never disagree.
class _TrialLine extends ConsumerWidget {
  const _TrialLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentServiceProvider);
    final plans = ref.watch(paywallPlansProvider).value;
    final monthly = plans?.monthly;
    final annual = plans?.annual;
    final String text;
    if (monthly == null || annual == null) {
      text = content.getValue(ContentKeys.postOnboardingTrialFallback);
    } else {
      final offer = plans!.introOfferFor(monthly);
      final prices = {
        'monthly': monthly.storeProduct.priceString,
        'annual': annual.storeProduct.priceString,
      };
      text = offer == null
          ? ContentKeys.format(
              content.getValue(ContentKeys.postOnboardingPlansLine),
              prices,
            )
          : ContentKeys.format(
              content.getValue(ContentKeys.postOnboardingTrialLine),
              {...prices, 'days': offer.freeDays},
            );
    }
    return Text(text, style: kOnboardingSubtitleStyle);
  }
}
