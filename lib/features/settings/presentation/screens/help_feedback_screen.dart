import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../../../shared/services/app_external_deps.dart';

/// Help & Feedback Screen - Kyle's Design System
/// Support and feedback collection screen with Sentry bug reporting
class HelpFeedbackScreen extends ConsumerWidget {
  const HelpFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: _buildContent(context, ref),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(
          FontAwesomeIcons.arrowLeft,
          size: AppIconSizes.md,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'Help & Feedback',
        style: AppTextStyles.sectionTitle.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: AppSpacing.screenPaddingHorizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),

          // Bug report section
          _buildBugReportSection(context, ref),

          const SizedBox(height: AppSpacing.lg),

          // Help section
          _buildHelpSection(context, ref),

          const SizedBox(height: AppSpacing.lg),

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
            'Report a Bug',
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Bug report option
          _buildBugReportOption(
            context: context,
            icon: FontAwesomeIcons.bug,
            title: 'Report a Bug',
            subtitle: 'Help us improve by reporting issues',
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
          Text(
            'Help Center',
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Help options
          _buildHelpOption(
            context: context,
            icon: FontAwesomeIcons.book,
            title: 'Getting Started Guide',
            subtitle: 'Learn the basics of Mealvana Endurance',
            onTap: () => _openGettingStarted(context, ref),
          ),

          const SizedBox(height: AppSpacing.sm),

          _buildHelpOption(
            context: context,
            icon: FontAwesomeIcons.personRunning,
            title: 'Sport Training Tips',
            subtitle: 'Improve your endurance performance',
            onTap: () => _openTrainingTips(context, ref),
          ),

          const SizedBox(height: AppSpacing.sm),

          _buildHelpOption(
            context: context,
            icon: FontAwesomeIcons.utensils,
            title: 'Nutrition Guide',
            subtitle: 'Fueling strategies and meal planning',
            onTap: () => _openNutritionGuide(context, ref),
          ),

          const SizedBox(height: AppSpacing.sm),

          _buildHelpOption(
            context: context,
            icon: FontAwesomeIcons.circleQuestion,
            title: 'FAQs',
            subtitle: 'Frequently asked questions',
            onTap: () => _openFAQs(context, ref),
          ),
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
            'Contact Us',
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Contact options
          _buildContactOption(
            context: context,
            icon: FontAwesomeIcons.envelope,
            title: 'Email Support',
            subtitle: 'support@mealvana.com',
            onTap: () => _sendEmail(context, ref),
          ),

          const SizedBox(height: AppSpacing.sm),

          _buildContactOption(
            context: context,
            icon: FontAwesomeIcons.globe,
            title: 'Website',
            subtitle: 'www.mealvana.com',
            onTap: () => _openWebsite(context, ref),
          ),

          const SizedBox(height: AppSpacing.sm),

          _buildContactOption(
            context: context,
            icon: FontAwesomeIcons.shareNodes,
            title: 'Community Forum',
            subtitle: 'Connect with other athletes',
            onTap: () => _openForum(context, ref),
          ),
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
                color: AppColors.dragonfruit.withOpacity(0.2),
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
            Icon(
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
                color: AppColors.electrolyte.withOpacity(0.2),
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
            Icon(
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
                color: AppColors.electrolyte.withOpacity(0.2),
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

  // Bug report with Sentry integration
  // Uses Sentry's built-in feedback widget with screenshot capture capability
  //
  // Flow:
  // 1. User taps "Report a Bug" -> Opens SentryFeedbackWidget
  // 2. User describes the bug in the feedback form
  // 3. User can tap "Capture Screenshot" button in the form
  // 4. Form dismisses temporarily, "Take Screenshot" button appears over the app
  // 5. User navigates to the problematic screen and taps the button
  // 6. Screenshot is captured and attached to the feedback
  // 7. Feedback form reopens with screenshot attached
  void _showBugReport(BuildContext context, WidgetRef ref) {
    // Track bug report
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('help_bug_report_tapped');

    if (!context.mounted) return;

    // Show Sentry feedback widget using the static show method
    // This properly integrates with the navigator key and screenshot system
    // Don't pass a screenshot here - let users capture it from within the form
    // so they can navigate to the screen where the bug occurred first
    SentryFeedbackWidget.show(context);
  }

  void _openGettingStarted(BuildContext context, WidgetRef ref) {
    // Track getting started guide
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('help_getting_started_tapped');

    // TODO: Implement getting started guide or link to external documentation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Getting started guide coming soon!'),
        backgroundColor: AppColors.electrolyte,
      ),
    );
  }

  void _openTrainingTips(BuildContext context, WidgetRef ref) {
    // Track training tips
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('help_training_tips_tapped');

    // TODO: Implement training tips or link to external documentation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Training tips coming soon!'),
        backgroundColor: AppColors.electrolyte,
      ),
    );
  }

  void _openNutritionGuide(BuildContext context, WidgetRef ref) {
    // Track nutrition guide
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('help_nutrition_guide_tapped');

    // TODO: Implement nutrition guide or link to external documentation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Nutrition guide coming soon!'),
        backgroundColor: AppColors.electrolyte,
      ),
    );
  }

  void _openFAQs(BuildContext context, WidgetRef ref) {
    // Track FAQs
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('help_faqs_tapped');

    // TODO: Implement FAQs or link to external documentation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('FAQs coming soon!'),
        backgroundColor: AppColors.electrolyte,
      ),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open email app'),
          backgroundColor: AppColors.dragonfruit,
        ),
      );
    }
  }

  void _openWebsite(BuildContext context, WidgetRef ref) async {
    // Track website
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('help_website_tapped');

    final websiteUri = Uri.parse('https://www.mealvana.com');

    if (await canLaunchUrl(websiteUri)) {
      await launchUrl(websiteUri);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open website'),
          backgroundColor: AppColors.dragonfruit,
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open community forum'),
          backgroundColor: AppColors.dragonfruit,
        ),
      );
    }
  }
}
