import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
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
            'Feedback',
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Send feedback option
          _buildFeedbackOption(
            context: context,
            icon: FontAwesomeIcons.commentDots,
            title: 'Send Feedback',
            subtitle: 'Share ideas, suggestions, or comments',
            onTap: () => _showFeedback(context, ref),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Bug report option
          _buildBugReportOption(
            context: context,
            icon: FontAwesomeIcons.bug,
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

  Widget _buildFeedbackOption({
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
            // Icon - electrolyte color for feedback (positive action)
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

  // General feedback form - simple text input dialog
  // Sends directly to Sentry's User Feedback section
  void _showFeedback(BuildContext context, WidgetRef ref) {
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('help_send_feedback_tapped');

    if (!context.mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final textController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Title
                Text(
                  'Send Feedback',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Subtitle
                Text(
                  'Share your ideas, suggestions, or comments to help us improve.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Text field
                TextField(
                  controller: textController,
                  maxLines: 4,
                  minLines: 3,
                  autofocus: true,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'What would you like to share with us?',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(AppSpacing.md),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final feedbackText = textController.text.trim();
                      if (feedbackText.isEmpty) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Please enter some feedback before submitting.',
                              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                            ),
                            backgroundColor: AppColors.dragonfruit,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }

                      // Close the bottom sheet
                      Navigator.of(bottomSheetContext).pop();

                      // Submit feedback asynchronously
                      _submitGeneralFeedback(
                        feedbackText: feedbackText,
                        analytics: analytics,
                        scaffoldMessenger: scaffoldMessenger,
                      );

                      // Show immediate confirmation
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(FontAwesomeIcons.circleCheck, color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Thank you for your feedback!',
                                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: AppColors.electrolyte,
                          duration: const Duration(seconds: 3),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.electrolyte,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Submit Feedback',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Submits general feedback to Sentry's User Feedback section
  ///
  /// Note: According to Sentry docs, `message` is the only required field.
  /// The `associatedEventId` is optional for standalone feedback.
  /// Feedback should appear in Sentry's /feedback page.
  Future<void> _submitGeneralFeedback({
    required String feedbackText,
    required dynamic analytics,
    required ScaffoldMessengerState scaffoldMessenger,
  }) async {
    try {
      debugPrint('[Feedback] Submitting general feedback to Sentry...');
      debugPrint('[Feedback] Message length: ${feedbackText.length} chars');

      // Send to Sentry User Feedback with additional context for better visibility
      final feedbackId = await Sentry.captureFeedback(
        SentryFeedback(
          message: feedbackText,
          // Note: name and contactEmail are optional but help with filtering in Sentry
        ),
        withScope: (scope) {
          // Add tags to help filter/identify feedback in Sentry
          scope.setTag('feedback_source', 'in_app_form');
          scope.setTag('feedback_type', 'general_feedback');
        },
      );

      // Check if feedback was accepted or silently dropped
      if (feedbackId == SentryId.empty()) {
        debugPrint('[Feedback] WARNING: Feedback may have been dropped by Sentry SDK');
      } else {
        debugPrint('[Feedback] Successfully submitted to Sentry! Feedback ID: $feedbackId');
      }

      analytics.analytics.track('help_feedback_submitted');
    } catch (e, stackTrace) {
      debugPrint('[Feedback] ERROR submitting to Sentry: $e');
      debugPrint('[Feedback] Stack trace: $stackTrace');

      analytics.analytics.track('help_feedback_error', properties: {
        'error': e.toString(),
      });

      // Show error snackbar if upload fails
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(FontAwesomeIcons.circleExclamation, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Failed to submit feedback. Please try again.',
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.dragonfruit,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Bug report with Sentry integration via feedback package
  // Uses BetterFeedback for screenshot annotation + Sentry upload
  //
  // Flow:
  // 1. User taps "Report a Bug" -> Opens BetterFeedback overlay
  // 2. User can draw/annotate on the current screen (circle issues, arrows, etc.)
  // 3. User writes description in the feedback form
  // 4. Feedback is uploaded to Sentry asynchronously (non-blocking)
  // 5. User sees confirmation snackbar immediately
  void _showBugReport(BuildContext context, WidgetRef ref) {
    // Track bug report
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('help_bug_report_tapped');

    if (!context.mounted) return;

    debugPrint('[BugReport] Opening BetterFeedback widget...');

    // Capture the ScaffoldMessenger before showing feedback
    // This ensures we can show snackbars even after the overlay closes
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    BetterFeedback.of(context).show((UserFeedback feedback) async {
      debugPrint('[BugReport] Callback received! Text: "${feedback.text}", Screenshot bytes: ${feedback.screenshot.length}');

      // IMPORTANT: Don't await the Sentry upload - fire and forget
      // This prevents the UI from hanging during upload
      _uploadFeedbackToSentry(
        feedback: feedback,
        analytics: analytics,
        scaffoldMessenger: scaffoldMessenger,
      );

      // Show immediate confirmation (upload happens in background)
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(FontAwesomeIcons.circleCheck, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Thank you! Your feedback is being submitted.',
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.electrolyte,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });

    debugPrint('[BugReport] BetterFeedback.show() called');
  }

  /// Uploads feedback to Sentry asynchronously (fire-and-forget)
  /// This runs in the background and doesn't block the UI
  ///
  /// IMPORTANT: Sentry User Feedback requires an associatedEventId to appear
  /// in the User Feedback dashboard. We first capture a message event, then
  /// associate the feedback with that event ID.
  Future<void> _uploadFeedbackToSentry({
    required UserFeedback feedback,
    required dynamic analytics,
    required ScaffoldMessengerState scaffoldMessenger,
  }) async {
    try {
      debugPrint('[BugReport] Starting async upload to Sentry...');

      // Step 1: Capture a message event to get an event ID
      // User feedback MUST be associated with an event to appear in Sentry's
      // User Feedback dashboard. Without this, feedback silently disappears.
      final eventId = await Sentry.captureMessage(
        'User Bug Report: ${feedback.text.length > 50 ? '${feedback.text.substring(0, 50)}...' : feedback.text}',
        level: SentryLevel.info,
        withScope: (scope) {
          scope.setTag('feedback_type', 'bug_report');
          scope.setContexts('user_feedback', feedback.extra ?? {});
          // Attach screenshot to the event
          scope.addAttachment(
            SentryAttachment.fromUint8List(
              feedback.screenshot,
              'screenshot.png',
              contentType: 'image/png',
            ),
          );
        },
      );

      debugPrint('[BugReport] Created event with ID: $eventId');

      // Step 2: Capture user feedback associated with that event
      final feedbackId = await Sentry.captureFeedback(
        SentryFeedback(
          message: feedback.text,
          associatedEventId: eventId,
        ),
      );

      debugPrint('[BugReport] Successfully submitted feedback to Sentry! Feedback ID: $feedbackId, Event ID: $eventId');
      analytics.analytics.track('help_bug_report_submitted');
    } catch (e, stackTrace) {
      debugPrint('[BugReport] ERROR submitting to Sentry: $e');
      debugPrint('[BugReport] Stack trace: $stackTrace');

      analytics.analytics.track('help_bug_report_error', properties: {
        'error': e.toString(),
      });

      // Show error snackbar if upload fails
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(FontAwesomeIcons.circleExclamation, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Failed to submit feedback. Please try again.',
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.dragonfruit,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
