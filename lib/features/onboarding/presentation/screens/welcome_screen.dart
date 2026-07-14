import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../providers/onboarding_analytics.dart';

/// Welcome Screen - Design System
/// First screen in onboarding flow
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
          KylePrimaryButton(
            key: const ValueKey('welcome.get_started_button'),
            text: 'Get Started',
            onPressed: () => _getStarted(context, ref),
            isFullWidth: false,
          ),
          const SizedBox(height: AppSpacing.md),
          KyleSecondaryButton(
            key: const ValueKey('welcome.log_in_button'),
            text: 'Log In',
            onPressed: () => _goToLogin(context, ref),
            isFullWidth: false,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        // App logo
        // Container(
        //   width: 120,
        //   height: 120,
        //   decoration: BoxDecoration(
        //     color: AppColors.cream.withOpacity(0.2),
        //     shape: BoxShape.circle,
        //   ),
        //   child: Icon(
        //     FontAwesomeIcons.personRunning.data,
        //     size: AppIconSizes.xl,
        //     color: AppColors.cream,
        //   ),
        // ),

        // const SizedBox(height: AppSpacing.lg),

        // App title
        Text(
          key: const ValueKey('welcome.title'),
          'Mealvana',
          style: AppTextStyles.pageTitle.copyWith(color: AppColors.cream),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Subtitle
        Text(
          key: const ValueKey('welcome.subtitle'),
          'Endurance',
          style: AppTextStyles.subtitle.copyWith(
            color: AppColors.cream.withValues(alpha: 0.8),
          ),
        ),
      ],
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
      'Get personalized nutrition plans tailored to your endurance activities. Track your fueling, optimize your performance, and achieve your goals.',
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
    } else {
      navigator.push('/onboarding');
    }
  }

  void _goToLogin(BuildContext context, WidgetRef ref) {
    // Track login button tap
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('welcome_login_tapped');

    // Navigate to post-onboarding auth screen in login mode
    context.push('/auth/post-onboarding?mode=login');
  }
}
