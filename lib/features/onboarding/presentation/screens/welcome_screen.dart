import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/privacy/analytics_consent.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../providers/onboarding_analytics.dart';

/// Welcome Screen (splash) - 2026-08 onboarding redesign
/// First screen in onboarding flow: logo, value-first headline, and the
/// "Build My Plan" / "I already have an account" entry points. Controller
/// wiring (fresh anonymous session, consent routing, funnel start mark) is
/// unchanged from the pre-redesign screen.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key, this.onContinue});

  /// Callback to advance to next page (optional for standalone use)
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdaptivePageScaffold(
      backgroundColor: AppColors.blackberry,
      contentWidth: AdaptiveContentWidth.narrow,
      body: AdaptiveScrollableBody(
        safeAreaTop: true,
        safeAreaBottom: true,
        padding: AppSpacing.screenPadding,
        footer: _buildFooter(context, ref),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: AdaptiveSpacing.byHeightClass(
            context,
            short: AppSpacing.lg,
            regular: AppSpacing.xxxl,
            tall: AppSpacing.huge,
          ),
        ),
        // Hero image
        _buildHeroImage(context),
        const SizedBox(height: AppSpacing.lg),
        // Logo and title
        _buildHeader(context),
        SizedBox(height: AdaptiveSpacing.sectionGap(context)),
        // Welcome message
        _buildWelcomeMessage(context),
      ],
    );
  }

  Widget _buildFooter(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Full-width orange pill, per the redesign prototype.
          KylePrimaryButton(
            key: const ValueKey('welcome.get_started_button'),
            text: 'Build My Plan',
            onPressed: () => _getStarted(context, ref),
            isFullWidth: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          // Plain text link (was a secondary button pre-redesign); same
          // login-mode auth route as before.
          TextButton(
            key: const ValueKey('welcome.log_in_button'),
            onPressed: () => _goToLogin(context, ref),
            child: Text(
              'I already have an account',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.cream.withValues(alpha: 0.9),
                decoration: TextDecoration.underline,
                decorationColor: AppColors.cream.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Text(
      key: const ValueKey('welcome.title'),
      'Get more out of every session.',
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontFamily: 'Sansita',
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.orange,
        height: 1.1,
      ),
    );
  }

  Widget _buildHeroImage(BuildContext context) {
    return Container(
      width: double.infinity,
      height: AdaptiveSpacing.heroHeight(
        context,
        short: 130,
        regular: 200,
        tall: 220,
      ),
      decoration: BoxDecoration(borderRadius: AppRadius.lgRadius),
      child: ClipRRect(
        borderRadius: AppRadius.lgRadius,
        child: Image.asset(
          'assets/images/welcome_inverted.png',
          fit: BoxFit.contain,
          semanticLabel: 'Mealvana Endurance logo',
        ),
      ),
    );
  }

  Widget _buildWelcomeMessage(BuildContext context) {
    return Text(
      key: const ValueKey('welcome.description'),
      'Fueling plans built for how you train — so you stop guessing your '
      'carbs mid-race.',
      style: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.cream.withValues(alpha: 0.9),
        height: 1.5,
      ),
      textAlign: TextAlign.center,
    );
  }

  void _getStarted(BuildContext context, WidgetRef ref) async {
    // Track get started
    final externalDeps = ref.read(appExternalDepsProvider);
    externalDeps.analytics.track('welcome_get_started_tapped');

    // Start of the onboarding funnel — read back at the final step to derive
    // `duration_sec` on `onboarding_completed`.
    OnboardingAnalytics.markStarted();

    // Capture navigation info before async operations
    final shouldUseCallback = onContinue != null;
    final callback = onContinue;
    final navigator = GoRouter.of(context);

    // CRITICAL: Create a fresh start for onboarding
    // 1. Sign out any existing session to ensure we start fresh
    // 2. Create new anonymous session for this onboarding flow
    // 3. Clear any temp user ID from previous attempts
    final supabase = externalDeps.supabaseClient;

    try {
      // Sign out existing session (if any) to start completely fresh
      await supabase.auth.signOut();

      // Create new anonymous session for onboarding
      await supabase.auth.signInAnonymously();

      // Clear temp user ID from any previous onboarding attempts
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('onboarding_temp_user_id');
    } catch (e) {
      // Log but continue - onboarding flow will handle auth if needed
      debugPrint('[WELCOME] Error creating fresh session: $e');
    }

    // Use callback if provided (PageView mode), otherwise navigate (standalone mode)
    if (shouldUseCallback && callback != null) {
      callback();
      return;
    }

    // Strict-regime users (EEA/UK, Washington) answer the analytics question
    // first, as the opening step of onboarding. Everyone else goes straight in
    // and never sees it — they get disclosure plus the Settings → Privacy
    // opt-out instead. `needsPrompt` already encodes that regional rule.
    //
    // The anonymous session created above is deliberately NOT gated on this:
    // it is how the app functions at all (contract performance), not analytics.
    final consent = ref.read(analyticsConsentProvider);
    navigator.push(
      consent.needsPrompt ? '/privacy-consent?next=/onboarding' : '/onboarding',
    );
  }

  void _goToLogin(BuildContext context, WidgetRef ref) {
    // Track login button tap
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('welcome_login_tapped');

    // Navigate to post-onboarding auth screen in login mode
    context.push('/auth/post-onboarding?mode=login');
  }
}
