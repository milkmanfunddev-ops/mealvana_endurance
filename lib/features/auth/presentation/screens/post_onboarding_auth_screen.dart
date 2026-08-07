import 'dart:async' show unawaited;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/auth/auth_listener_service.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../../shared/services/sync/sync_coordinator.dart';
import '../../../content/application/content_service.dart';
import '../../../onboarding/presentation/providers/onboarding_controller.dart';
import '../../../onboarding/presentation/theme/onboarding_design_tokens.dart';
import '../../../onboarding/presentation/widgets/onboarding_step_scaffold.dart';
import '../../application/auth_service.dart';
import '../providers/post_onboarding_auth_controller.dart';
import '../../domain/auth_exceptions.dart';
import '../../../coach_mode/application/coach_service.dart';

/// Post-Onboarding Authentication Screen
/// Shown after the daily-plan preview (2026-08 onboarding redesign) to
/// encourage account creation: "Your plan is ready. Don't leave it behind."
/// Offers Apple Sign-In, Google Sign-In, Email/Password, or Skip.
/// Visual language matches the redesigned onboarding steps (dark blackberry
/// scaffold, Sansita/orange title); controller wiring (credential linking,
/// saveAllOnboardingData, background upload, Settings anon→upgrade branch)
/// is unchanged from the pre-redesign screen.
class PostOnboardingAuthScreen extends ConsumerStatefulWidget {
  const PostOnboardingAuthScreen({super.key, this.mode = 'signup'});

  final String mode;

  @override
  ConsumerState<PostOnboardingAuthScreen> createState() =>
      _PostOnboardingAuthScreenState();
}

class _PostOnboardingAuthScreenState
    extends ConsumerState<PostOnboardingAuthScreen> {
  @override
  void initState() {
    super.initState();

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

  Future<void> _handleAppleSignIn() async {
    final controller = ref.read(postOnboardingAuthControllerProvider.notifier);
    final isLogin = widget.mode == 'login';
    final supabase = ref.read(appExternalDepsProvider).supabaseClient;
    final authListenerService = ref.read(authListenerServiceProvider);

    if (!isLogin) {
      // For signup mode, we LINK to the existing anonymous session to preserve onboarding data.
      // If we don't have an anonymous session (unexpected), create one to link against.
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null || !currentUser.isAnonymous) {
        // Preserve cached onboarding data while resetting the auth session.
        authListenerService.markOnboardingSignOut();
        await supabase.auth.signOut();
        final response = await supabase.auth.signInAnonymously();
        if (response.user == null) {
          if (mounted) {
            _handleError(context, 'Apple');
          }
          return;
        }
      }
    }

    // Signup mode: link to anonymous user (throws AccountAlreadyExistsException if provider exists)
    // Login mode: sign in to existing account (or create if none exists)
    final bool success = isLogin
        ? await controller.signInWithApple()
        : await controller.linkAppleAccount();

    if (!mounted) return;

    if (success) {
      // On web, the OAuth flow triggers a redirect, so we shouldn't navigate manually.
      // The browser will reload the app after the user authenticates.
      if (kIsWeb) return;

      // Login mode: Navigate directly (no onboarding data to save)
      // Signup mode: Save cached onboarding data before navigating
      if (isLogin) {
        await _navigateToMain();
      } else {
        await _saveOnboardingDataAndNavigate(
          authProvider: 'apple',
          isAnonymous: false,
        );
      }
    } else {
      _handleError(context, 'Apple');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final controller = ref.read(postOnboardingAuthControllerProvider.notifier);
    final isLogin = widget.mode == 'login';
    final supabase = ref.read(appExternalDepsProvider).supabaseClient;
    final authListenerService = ref.read(authListenerServiceProvider);

    if (!isLogin) {
      // For signup mode, we LINK to the existing anonymous session to preserve onboarding data.
      // If we don't have an anonymous session (unexpected), create one to link against.
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null || !currentUser.isAnonymous) {
        // Preserve cached onboarding data while resetting the auth session.
        authListenerService.markOnboardingSignOut();
        await supabase.auth.signOut();
        final response = await supabase.auth.signInAnonymously();
        if (response.user == null) {
          if (mounted) {
            _handleError(context, 'Google');
          }
          return;
        }
      }
    }

    // Signup mode: link to anonymous user (throws AccountAlreadyExistsException if provider exists)
    // Login mode: sign in to existing account (or create if none exists)
    final bool success = isLogin
        ? await controller.signInWithGoogle()
        : await controller.linkGoogleAccount();

    if (!mounted) return;

    if (success) {
      // On web, the OAuth flow triggers a redirect, so we shouldn't navigate manually.
      // The browser will reload the app after the user authenticates.
      if (kIsWeb) return;

      // Login mode: Navigate directly (no onboarding data to save)
      // Signup mode: Save cached onboarding data before navigating
      if (isLogin) {
        await _navigateToMain();
      } else {
        await _saveOnboardingDataAndNavigate(
          authProvider: 'google',
          isAnonymous: false,
        );
      }
    } else {
      _handleError(context, 'Google');
    }
  }

  void _handleError(BuildContext context, String providerName) {
    // Check if the error is because the account already exists
    final state = ref.read(postOnboardingAuthControllerProvider);
    if (state.hasError && state.error is AccountAlreadyExistsException) {
      final exception = state.error as AccountAlreadyExistsException;
      _showAccountExistsDialog(context, providerName, exception.email);
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
          contentService.getValue(
            'auth.error.account_exists_message',
            defaultValue:
                'This $provider account ${email != null ? "($email) " : ""}is already linked to another user.',
          ),
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
      // This is always a sign-in (orphaning anonymous user), so navigate directly
      await _navigateToMain();
    }
  }

  Future<void> _signInWithApple() async {
    final controller = ref.read(postOnboardingAuthControllerProvider.notifier);
    final success = await controller.signInWithApple();

    // On web, the OAuth flow triggers a redirect, so we shouldn't navigate manually
    if (kIsWeb) return;

    if (success && mounted) {
      // This is always a sign-in (orphaning anonymous user), so navigate directly
      await _navigateToMain();
    }
  }

  Future<void> _handleEmailSignUp() async {
    final logger = ref.read(appExternalDepsProvider).logger;

    // Navigate to email signup screen
    logger.info('Navigating to email signup screen', context: 'NAV');
    final result = await context.push('/auth/email-signup');

    logger.info(
      'Email signup returned',
      context: 'NAV',
      data: {'result': result, 'mounted': mounted},
    );

    // If email signup successful, save onboarding data and navigate to main app
    if (result == true && mounted) {
      logger.info(
        'Email signup successful, saving onboarding data',
        context: 'NAV',
      );
      await _saveOnboardingDataAndNavigate(
        authProvider: 'email',
        isAnonymous: false,
      );
    } else {
      logger.info(
        'Email signup did not return true or widget unmounted',
        context: 'NAV',
        data: {'result': result, 'mounted': mounted},
      );
    }
  }

  Future<void> _handleEmailLogin() async {
    // Navigate to email login screen
    final result = await context.push('/auth/email-login');

    // If email login successful, navigate directly (no onboarding data to save)
    if (result == true && mounted) {
      await _navigateToMain();
    }
  }

  Future<void> _handleSkip() async {
    final controller = ref.read(postOnboardingAuthControllerProvider.notifier);
    await controller.skipAuthentication();

    if (mounted) {
      // Save all cached onboarding data before navigating as guest (anonymous user)
      await _saveOnboardingDataAndNavigate(
        authProvider: 'anonymous',
        isAnonymous: true,
      );
    }
  }

  /// Navigate directly to main app (for login mode - no onboarding data to save)
  /// On web, coaches are redirected to the coach portal instead.
  Future<void> _navigateToMain() async {
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

  /// Save all cached onboarding data and navigate to main app
  /// IMPORTANT: This now saves locally only and triggers background sync for Supabase upload
  /// [authProvider] - 'anonymous', 'email', 'google', 'apple'
  /// [isAnonymous] - false when user signs up with email/OAuth
  Future<void> _saveOnboardingDataAndNavigate({
    String authProvider = 'anonymous',
    bool isAnonymous = true,
  }) async {
    final logger = ref.read(appExternalDepsProvider).logger;
    final onboardingController = ref.read(
      onboardingControllerProvider.notifier,
    );
    // Read before the async gaps below: this screen navigates away mid-flow, so
    // `ref.read` after that point can throw on a disposed ConsumerState.
    final syncCoordinator = ref.read(syncCoordinatorProvider.notifier);
    final contentService = ref.read(contentServiceProvider);

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
        context.go('/main');

        unawaited(
          _uploadOnboardingDataInBackground(
            userId: existingUser.id,
            onboardingController: onboardingController,
            syncCoordinator: syncCoordinator,
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
      data: {'authProvider': authProvider, 'isAnonymous': isAnonymous},
    );

    // Save all cached onboarding data (saves to Drift only, marks for background upload)
    final success = await onboardingController.saveAllOnboardingData(
      authProvider: authProvider,
      isAnonymous: isAnonymous,
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
        'Navigating to /main',
        context: 'NAV',
        data: {'hasUser': currentUser != null, 'userId': currentUser?.id},
      );

      // Navigate to main app immediately after local save. The upload below
      // still runs if this screen was disposed during the lookup above — the
      // data is saved either way and must reach Supabase.
      if (mounted) context.go('/main');

      // Push the onboarding data to Supabase in the background.
      //
      // This runs for EVERY user, including anonymous ones who skipped account
      // creation (authProvider == 'anonymous') — as of the 2026-07-29 policy
      // there is no local-only tier. Non-blocking so an offline or slow
      // network never holds up the app; the rows stay dirty and retry.
      if (currentUser != null) {
        unawaited(
          _uploadOnboardingDataInBackground(
            userId: currentUser.id,
            onboardingController: onboardingController,
            syncCoordinator: syncCoordinator,
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
    final asyncState = ref.watch(postOnboardingAuthControllerProvider);
    final contentService = ref.watch(contentServiceProvider);
    final isLogin = widget.mode == 'login';

    return AdaptivePageScaffold(
      backgroundColor: OnbTokens.bg,
      appBar: _buildAppBar(
        context,
        isLoading: asyncState.isLoading,
        isLogin: isLogin,
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

                // Subtitle (spec: Apercu 14 cream-62%, left-aligned)
                Text(
                  key: ValueKey(
                    isLogin
                        ? 'login_options.subtitle'
                        : 'post_onboarding.subtitle',
                  ),
                  contentService.getValue(
                    isLogin
                        ? 'auth.login.subtitle'
                        : 'auth.post_onboarding.subtitle',
                    defaultValue: isLogin
                        ? 'Welcome back'
                        : 'Save it in seconds. Free through launch month, '
                              'no card needed.',
                  ),
                  style: kOnboardingSubtitleStyle,
                ),

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

                // Skip button (only for signup mode)
                if (!isLogin) ...[
                  const SizedBox(height: 16),

                  TextButton(
                    key: const ValueKey('create_account.skip_button'),
                    onPressed: asyncState.isLoading ? null : _handleSkip,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.all(10),
                    ),
                    child: Text(
                      contentService.getValue(
                        'auth.post_onboarding.skip_button',
                        defaultValue: 'Continue without an account',
                      ),
                      style: const TextStyle(
                        fontFamily: OnbTokens.fontBody,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: OnbTokens.cream,
                        decoration: TextDecoration.underline,
                        decorationColor: OnbTokens.cream,
                      ),
                    ),
                  ),

                  const SizedBox(height: 2),

                  // Skip reminder text (local-only note)
                  Text(
                    contentService.getValue(
                      'auth.post_onboarding.skip_reminder',
                      defaultValue:
                          'Your plan stays on this device only — save it to '
                          'keep it if you switch phones.',
                    ),
                    style: TextStyle(
                      fontFamily: OnbTokens.fontBody,
                      fontSize: 11.5,
                      height: 1.4,
                      color: OnbTokens.creamA(0.4),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

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
          Opacity(
            opacity: isLoading ? 0.5 : 1.0,
            child: InkWell(
              key: ValueKey(
                isLogin
                    ? 'login_options.back_button'
                    : 'create_account.back_button',
              ),
              customBorder: const CircleBorder(),
              onTap: isLoading
                  ? null
                  : () {
                      // Sentry MEALVANA-ENDURANCE-DEV-5R: this screen can be
                      // reached via context.go() (post-onboarding flow) as
                      // well as push(), so guard against GoError "There is
                      // nothing to pop".
                      if (context.canPop()) {
                        context.pop();
                        return;
                      }
                      // Nothing to pop. In LOGIN mode the person is not
                      // signed in and just asked to go back — dropping them
                      // into /main is the opposite of that, and lands an
                      // unauthenticated user in the app. Send them to the
                      // welcome screen they came from. Signup mode keeps
                      // /main: it is only reachable there once onboarding
                      // has been saved.
                      context.go(isLogin ? '/welcome' : '/main');
                    },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: OnbTokens.creamA(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_left,
                  size: 18,
                  color: OnbTokens.creamA(0.8),
                ),
              ),
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
    final line = Expanded(child: Container(height: 1, color: OnbTokens.creamA(0.15)));
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
