import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';
import '../../../../shared/services/app_external_deps.dart';

/// Welcome Screen - Design System
/// First screen in onboarding flow
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.blackberry,
      body: _buildContent(context, ref),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: AppSpacing.xxxl),
            // Hero image
            _buildHeroImage(context),
            const SizedBox(height: AppSpacing.lg),
            // Logo and title
            _buildHeader(context),


            

            const SizedBox(height: AppSpacing.xxxl),
            const SizedBox(height: AppSpacing.xxxl),

            // Welcome message
            _buildWelcomeMessage(context),

            const Spacer(),

            // Get Started button
            KylePrimaryButton(
              text: 'Get Started',
              onPressed: () => _getStarted(context, ref),
              isFullWidth: false,
            ),

            const SizedBox(height: AppSpacing.md),

            // Login button
            KyleSecondaryButton(
              text: 'Log In',
              onPressed: () => _goToLogin(context, ref),
              isFullWidth: false,
            ),

            const SizedBox(height: AppSpacing.lg),

            // // Skip link
            // InkWell(
            //   onTap: () => _skipOnboarding(context, ref),
            //   child: Text(
            //     'Skip for now',
            //     style: AppTextStyles.buttonTertiary.copyWith(
            //       color: AppColors.dragonfruit,
            //       decoration: TextDecoration.underline,
            //     ),
            //   ),
            // ),
          ],
        ),
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
        //     FontAwesomeIcons.personRunning,
        //     size: AppIconSizes.xl,
        //     color: AppColors.cream,
        //   ),
        // ),

        // const SizedBox(height: AppSpacing.lg),

        // App title
        Text(
          'Mealvana',
          style: AppTextStyles.pageTitle.copyWith(
            color: AppColors.cream,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Subtitle
        Text(
          'Endurance',
          style: AppTextStyles.subtitle.copyWith(
            color: AppColors.cream.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroImage(BuildContext context) {
    // scale the image down
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgRadius,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.lgRadius,
        child: Image.asset(
          'assets/images/welcome_inverted.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildWelcomeMessage(BuildContext context) {
    return Column(
      children: [
        Text(
          'Welcome to Your Personal\nNutrition Coach',
          style: AppTextStyles.sectionTitle.copyWith(
            color: AppColors.cream,
            fontSize: 24,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: AppSpacing.lg),

        Text(
          'Get personalized nutrition plans tailored to your endurance activities. Track your fueling, optimize your performance, and achieve your goals.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.cream.withOpacity(0.9),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _getStarted(BuildContext context, WidgetRef ref) {
    // Track get started
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('welcome_get_started_tapped');

    // Navigate to profile setup
    context.push('/onboarding/profile');
  }

  void _goToLogin(BuildContext context, WidgetRef ref) {
    // Track login button tap
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('welcome_login_tapped');

    // Navigate to post-onboarding auth screen in login mode
    context.push('/auth/post-onboarding?mode=login');
  }

  void _skipOnboarding(BuildContext context, WidgetRef ref) {
    // Track skip onboarding
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('welcome_skip_tapped');

    // Navigate to main app
    context.push('/main');
  }
}
