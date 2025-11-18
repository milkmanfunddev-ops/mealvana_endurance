import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../content/application/content_service.dart';
import '../providers/post_onboarding_auth_controller.dart';

/// Post-Onboarding Authentication Screen
/// Shown after food preferences to encourage account creation
/// Offers Apple Sign-In, Google Sign-In, Email/Password, or Skip
class PostOnboardingAuthScreen extends ConsumerStatefulWidget {
  const PostOnboardingAuthScreen({super.key});

  @override
  ConsumerState<PostOnboardingAuthScreen> createState() => _PostOnboardingAuthScreenState();
}

class _PostOnboardingAuthScreenState extends ConsumerState<PostOnboardingAuthScreen> {
  @override
  void initState() {
    super.initState();

    ref.read(appExternalDepsProvider).analytics.track('screen_viewed', properties: {
      'screen_name': 'Post-Onboarding Auth',
    });
  }

  Future<void> _handleAppleSignIn() async {
    final controller = ref.read(postOnboardingAuthControllerProvider.notifier);
    final success = await controller.linkAppleAccount();

    // Note: Success handled by auth state change listener in app_startup_service
    // which will navigate to main app automatically after linking

    if (!success && mounted) {
      final contentService = ref.read(contentServiceProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            contentService.getValue(
              'auth.post_onboarding.error_oauth_failed',
              defaultValue: 'Sign in failed. Please try again.',
            ),
          ),
          backgroundColor: AppColors.dragonfruit,
        ),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final controller = ref.read(postOnboardingAuthControllerProvider.notifier);
    final success = await controller.linkGoogleAccount();

    // Note: Success handled by auth state change listener in app_startup_service
    // which will navigate to main app automatically after linking

    if (!success && mounted) {
      final contentService = ref.read(contentServiceProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            contentService.getValue(
              'auth.post_onboarding.error_oauth_failed',
              defaultValue: 'Sign in failed. Please try again.',
            ),
          ),
          backgroundColor: AppColors.dragonfruit,
        ),
      );
    }
  }

  Future<void> _handleEmailSignUp() async {
    // Navigate to email signup screen (to be created next)
    final result = await context.push('/auth/email-signup');

    // If email signup successful, auth state listener will handle navigation
    if (result == true && mounted) {
      // Success message shown by email signup screen
      // Navigation handled by auth state listener
    }
  }

  Future<void> _handleSkip() async {
    final controller = ref.read(postOnboardingAuthControllerProvider.notifier);
    await controller.skipAuthentication();

    if (mounted) {
      context.go('/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(postOnboardingAuthControllerProvider);
    final contentService = ref.watch(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPaddingHorizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),

              // Title
              Text(
                contentService.getValue(
                  'auth.post_onboarding.title',
                  defaultValue: 'Create Your Account',
                ),
                style: AppTextStyles.sectionTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 28,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.sm),

              // Subtitle
              Text(
                contentService.getValue(
                  'auth.post_onboarding.subtitle',
                  defaultValue: 'Secure your data and sync across devices',
                ),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Hero text
              Text(
                contentService.getValue(
                  'auth.post_onboarding.hero_text',
                  defaultValue: 'Save your nutrition plans, training progress, and preferences with a free account.',
                ),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Benefits card
              _buildBenefitsCard(context, contentService, isDark),

              const SizedBox(height: AppSpacing.xxxl),

              // Apple Sign-In button
              _buildOAuthButton(
                context: context,
                label: contentService.getValue(
                  'auth.post_onboarding.apple_button',
                  defaultValue: 'Continue with Apple',
                ),
                icon: FontAwesomeIcons.apple,
                onPressed: asyncState.isLoading ? null : _handleAppleSignIn,
                isLoading: asyncState.isLoading,
              ),

              const SizedBox(height: AppSpacing.md),

              // Google Sign-In button
              _buildOAuthButton(
                context: context,
                label: contentService.getValue(
                  'auth.post_onboarding.google_button',
                  defaultValue: 'Continue with Google',
                ),
                icon: FontAwesomeIcons.google,
                onPressed: asyncState.isLoading ? null : _handleGoogleSignIn,
                isLoading: asyncState.isLoading,
              ),

              const SizedBox(height: AppSpacing.md),

              // Email signup button
              KylePrimaryButton(
                text: contentService.getValue(
                  'auth.post_onboarding.email_button',
                  defaultValue: 'Sign up with Email',
                ),
                onPressed: asyncState.isLoading ? null : _handleEmailSignUp,
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Skip button
              TextButton(
                onPressed: asyncState.isLoading ? null : _handleSkip,
                child: Text(
                  contentService.getValue(
                    'auth.post_onboarding.skip_button',
                    defaultValue: 'Continue without signing in',
                  ),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Skip reminder text
              Text(
                contentService.getValue(
                  'auth.post_onboarding.skip_reminder',
                  defaultValue: 'You can always create an account later in Settings',
                ),
                style: AppTextStyles.smallLabel.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          // Custom back button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                FontAwesomeIcons.arrowLeft,
                size: AppIconSizes.controlIcon,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () => context.pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsCard(BuildContext context, ContentService contentService, bool isDark) {
    // Get benefits list from content service
    final benefitsList = [
      contentService.getValue(
        'auth.post_onboarding.benefits[0]',
        defaultValue: 'Sync your data across all your devices',
      ),
      contentService.getValue(
        'auth.post_onboarding.benefits[1]',
        defaultValue: 'Never lose your nutrition plans and training history',
      ),
      contentService.getValue(
        'auth.post_onboarding.benefits[2]',
        defaultValue: 'Get personalized recommendations based on your progress',
      ),
      contentService.getValue(
        'auth.post_onboarding.benefits[3]',
        defaultValue: 'Share plans with coaches and training partners',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark
          ? AppColors.blackberry.withOpacity(0.3)
          : AppColors.electrolyte.withOpacity(0.1),
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: AppColors.electrolyte.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Benefits title
          Row(
            children: [
              Icon(
                FontAwesomeIcons.circleCheck,
                size: AppIconSizes.md,
                color: AppColors.electrolyte,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                contentService.getValue(
                  'auth.post_onboarding.benefits_card_title',
                  defaultValue: 'Account Benefits',
                ),
                style: AppTextStyles.sectionTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Benefits list
          ...benefitsList.map((benefit) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  FontAwesomeIcons.check,
                  size: AppIconSizes.sm,
                  color: AppColors.electrolyte,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    benefit,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildOAuthButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isLoading,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: double.infinity,
      height: AppSizes.buttonHeightPrimary,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark
            ? AppColors.blackberry.withOpacity(0.5)
            : Colors.white,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          elevation: isDark ? 0 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
            side: BorderSide(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: AppIconSizes.button,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: AppTextStyles.buttonText.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
