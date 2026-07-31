import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wiredash/wiredash.dart';
import 'package:mealvana_endurance/features/auth/application/auth_service.dart';
import 'package:mealvana_endurance/shared/services/support/support_identity.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// Help & Feedback Screen - Kyle's Design System
/// Support and feedback collection screen with Wiredash integration
class HelpFeedbackScreen extends ConsumerWidget {
  const HelpFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdaptivePageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      contentWidth: AdaptiveContentWidth.standard,
      body: _buildContent(context, ref),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: const CustomAppBarBackButton(key: ValueKey('help.back_button')),
      title: Text(
        key: const ValueKey('help.title'),
        'Help & Feedback',
        style: AppTextStyles.sectionTitle.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    return AdaptiveScrollableBody(
      padding: AppSpacing.screenPaddingHorizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),

          // Bug report section
          _buildBugReportSection(context, ref),

          const SizedBox(height: AppSpacing.lg),

          // Help section
          // _buildHelpSection(context, ref),

          // const SizedBox(height: AppSpacing.lg),

          // Contact section
          _buildContactSection(context, ref),

          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  Widget _buildBugReportSection(BuildContext context, WidgetRef ref) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            key: const ValueKey('help.feedback_section'),
            'Feedback',
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Rate experience - NPS Promoter Survey
          _buildFeedbackOption(
            rowKey: const ValueKey('help.rate_row'),
            context: context,
            icon: FontAwesomeIcons.star.data,
            title: 'Rate Your Experience',
            subtitle: 'How likely are you to recommend us?',
            onTap: () => _showRatingsSurvey(context, ref),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Bug report option
          _buildBugReportOption(
            rowKey: const ValueKey('help.report_bug_row'),
            context: context,
            icon: FontAwesomeIcons.bug.data,
            title: 'Report a Bug',
            subtitle: 'Help us fix issues you encounter',
            onTap: () => _showBugReport(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection(BuildContext context, WidgetRef ref) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text(
          //   'Help Center',
          //   style: AppTextStyles.subtitle.copyWith(
          //     color: Theme.of(context).colorScheme.onSurface,
          //   ),
          // ),

          // const SizedBox(height: AppSpacing.md),

          // Help options
          // _buildHelpOption(
          //   context: context,
          //   icon: FontAwesomeIcons.book.data,
          //   title: 'Getting Started Guide',
          //   subtitle: 'Learn the basics of Mealvana Endurance',
          //   onTap: () => _openGettingStarted(context, ref),
          // ),

          // const SizedBox(height: AppSpacing.sm),

          // _buildHelpOption(
          //   context: context,
          //   icon: FontAwesomeIcons.personRunning.data,
          //   title: 'Sport Training Tips',
          //   subtitle: 'Improve your endurance performance',
          //   onTap: () => _openTrainingTips(context, ref),
          // ),

          // const SizedBox(height: AppSpacing.sm),

          // _buildHelpOption(
          //   context: context,
          //   icon: FontAwesomeIcons.utensils.data,
          //   title: 'Nutrition Guide',
          //   subtitle: 'Fueling strategies and meal planning',
          //   onTap: () => _openNutritionGuide(context, ref),
          // ),

          // const SizedBox(height: AppSpacing.sm),

          // _buildHelpOption(
          //   context: context,
          //   icon: FontAwesomeIcons.circleQuestion.data,
          //   title: 'FAQs',
          //   subtitle: 'Frequently asked questions',
          //   onTap: () => _openFAQs(context, ref),
          // ),
        ],
      ),
    );
  }

  Widget _buildContactSection(BuildContext context, WidgetRef ref) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            key: const ValueKey('help.contact_section'),
            'Contact Us',
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Contact options
          _buildContactOption(
            rowKey: const ValueKey('help.email_row'),
            context: context,
            icon: FontAwesomeIcons.envelope.data,
            title: 'Email Support',
            subtitle: 'support@mealvana.com',
            onTap: () => _sendEmail(context, ref),
          ),

          const SizedBox(height: AppSpacing.sm),

          _buildContactOption(
            rowKey: const ValueKey('help.website_row'),
            context: context,
            icon: FontAwesomeIcons.globe.data,
            title: 'Website',
            subtitle: 'endurance.mealvana.io',
            onTap: () => _openWebsite(context, ref),
          ),

          // const SizedBox(height: AppSpacing.sm),

          // _buildContactOption(
          //   context: context,
          //   icon: FontAwesomeIcons.shareNodes.data,
          //   title: 'Community Forum',
          //   subtitle: 'Connect with other athletes',
          //   onTap: () => _openForum(context, ref),
          // ),
        ],
      ),
    );
  }

  Widget _buildBugReportOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Key? rowKey,
  }) {
    return InkWell(
      key: rowKey,
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.dragonfruit.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: AppIconSizes.controlIcon,
                color: AppColors.dragonfruit,
              ),
            ),

            const SizedBox(width: AppSpacing.md),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow icon
            FaIcon(
              FontAwesomeIcons.chevronRight,
              size: AppIconSizes.controlIcon,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Key? rowKey,
  }) {
    return InkWell(
      key: rowKey,
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // Icon - electrolyte color for feedback (positive action)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.electrolyte.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: AppIconSizes.controlIcon,
                color: AppColors.electrolyte,
              ),
            ),

            const SizedBox(width: AppSpacing.md),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow icon
            FaIcon(
              FontAwesomeIcons.chevronRight,
              size: AppIconSizes.controlIcon,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.electrolyte.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: AppIconSizes.controlIcon,
                color: AppColors.electrolyte,
              ),
            ),

            const SizedBox(width: AppSpacing.md),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow icon
            FaIcon(
              FontAwesomeIcons.chevronRight,
              size: AppIconSizes.controlIcon,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Key? rowKey,
  }) {
    return InkWell(
      key: rowKey,
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.electrolyte.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: AppIconSizes.controlIcon,
                color: AppColors.electrolyte,
              ),
            ),

            const SizedBox(width: AppSpacing.md),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NPS Promoter Score Survey using Wiredash
  // Opens the "How likely are you to recommend?" survey (0-10 scale)
  // Always shows when user explicitly taps it (force: true)
  Future<void> _showRatingsSurvey(BuildContext context, WidgetRef ref) async {
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('help_rate_experience_tapped');

    if (!context.mounted) return;

    debugPrint('[Ratings] Opening Wiredash Promoter Score survey...');

    // Prefill user properties for Wiredash survey — prefer the real profile
    // email over an Apple private-relay address.
    final supabaseClient = ref.read(appExternalDepsProvider).supabaseClient;
    final currentUser = supabaseClient.auth.currentUser;
    if (currentUser != null) {
      final profile = await ref.read(currentUserProvider.future);
      if (!context.mounted) return;
      Wiredash.of(context).setUserProperties(
        userEmail: resolveSupportEmail([profile?.email, currentUser.email]),
        userId: currentUser.id,
      );
    }

    // Always show the NPS survey when user explicitly requests it
    Wiredash.of(context).showPromoterSurvey(
      inheritMaterialTheme: true,
      force: true, // Always show - user explicitly tapped to rate
    );

    debugPrint('[Ratings] Wiredash.showPromoterSurvey() called');
  }

  // Bug report with Wiredash integration
  // Uses Wiredash for screenshot annotation + Wiredash cloud upload
  //
  // Flow:
  // 1. User taps "Report a Bug" -> Opens Wiredash feedback overlay
  // 2. User can draw/annotate on the current screen (circle issues, arrows, etc.)
  // 3. User writes description in the feedback form
  // 4. Feedback is uploaded to Wiredash dashboard
  Future<void> _showBugReport(BuildContext context, WidgetRef ref) async {
    // Track bug report
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('help_bug_report_tapped');

    if (!context.mounted) return;

    debugPrint('[BugReport] Opening Wiredash feedback widget...');

    // Prefill user properties for Wiredash feedback — prefer the real profile
    // email over an Apple private-relay address.
    final supabaseClient = ref.read(appExternalDepsProvider).supabaseClient;
    final currentUser = supabaseClient.auth.currentUser;
    if (currentUser != null) {
      final profile = await ref.read(currentUserProvider.future);
      if (!context.mounted) return;
      Wiredash.of(context).setUserProperties(
        userEmail: resolveSupportEmail([profile?.email, currentUser.email]),
        userId: currentUser.id,
      );
    }

    // Open Wiredash with bug report flow
    // Labels are configured in RootAppWidget
    Wiredash.of(context).show(inheritMaterialTheme: true);

    debugPrint('[BugReport] Wiredash.show() called');
  }

  void _openGettingStarted(BuildContext context, WidgetRef ref) {
    // Track getting started guide
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('help_getting_started_tapped');

    // TODO: Implement getting started guide or link to external documentation
    MealvanaSnackbar.showSuccess(context, 'Getting started guide coming soon!');
  }

  void _openTrainingTips(BuildContext context, WidgetRef ref) {
    // Track training tips
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('help_training_tips_tapped');

    // TODO: Implement training tips or link to external documentation
    MealvanaSnackbar.showSuccess(context, 'Training tips coming soon!');
  }

  void _openNutritionGuide(BuildContext context, WidgetRef ref) {
    // Track nutrition guide
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('help_nutrition_guide_tapped');

    // TODO: Implement nutrition guide or link to external documentation
    MealvanaSnackbar.showSuccess(context, 'Nutrition guide coming soon!');
  }

  void _openFAQs(BuildContext context, WidgetRef ref) {
    // Track FAQs
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('help_faqs_tapped');

    // TODO: Implement FAQs or link to external documentation
    MealvanaSnackbar.showSuccess(context, 'FAQs coming soon!');
  }

  void _sendEmail(BuildContext context, WidgetRef ref) async {
    // Track email support
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('help_email_support_tapped');

    final emailUri = Uri.parse('mailto:support@mealvana.com');

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (!context.mounted) return;
      MealvanaSnackbar.showError(context, 'Could not open email app');
    }
  }

  void _openWebsite(BuildContext context, WidgetRef ref) async {
    // Track website
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('help_website_tapped');

    final websiteUri = Uri.parse('https://endurance.mealvana.io');

    if (await canLaunchUrl(websiteUri)) {
      await launchUrl(websiteUri);
    } else {
      if (!context.mounted) return;
      MealvanaSnackbar.showError(context, 'Could not open website');
    }
  }

  void _openForum(BuildContext context, WidgetRef ref) async {
    // Track community forum
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('help_forum_tapped');

    final forumUri = Uri.parse('https://community.mealvana.com');

    if (await canLaunchUrl(forumUri)) {
      await launchUrl(forumUri);
    } else {
      if (!context.mounted) return;
      MealvanaSnackbar.showError(context, 'Could not open community forum');
    }
  }
}
