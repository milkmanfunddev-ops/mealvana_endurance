import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/database/database_provider.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';

/// Coach Registration Screen
/// Simple info screen that opens external Tally form for coach applications
class CoachRegistrationScreen extends ConsumerWidget {
  const CoachRegistrationScreen({super.key});

  // Notion form for coach applications
  // The user_id will be appended as a query parameter
  static const String _baseFormUrl = 'https://zenith-echinodon-4ee.notion.site/2e0e3fdb754c8078aa46e1e01471bfde?pvs=105';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(FontAwesomeIcons.chevronLeft),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Become a Coach',
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.screenPaddingHorizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: AppSpacing.xl),

            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.electrolyte.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                FontAwesomeIcons.userTie,
                color: AppColors.electrolyte,
                size: 36,
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Title
            Text(
              'Join Our Coach Network',
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.md),

            // Description
            Text(
              'Help endurance athletes reach their nutrition goals. '
              'Apply to become a certified Mealvana coach.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.xl),

            // Benefits list
            _buildBenefitItem(
              context,
              FontAwesomeIcons.users,
              'Connect with Athletes',
              'Build your client base through the app',
            ),
            const SizedBox(height: AppSpacing.md),
            _buildBenefitItem(
              context,
              FontAwesomeIcons.chartLine,
              'Track Progress',
              'Monitor athlete activities and nutrition plans',
            ),
            const SizedBox(height: AppSpacing.md),
            _buildBenefitItem(
              context,
              FontAwesomeIcons.comment,
              'Provide Feedback',
              'Give personalized guidance to your athletes',
            ),

            const SizedBox(height: AppSpacing.xxxl),

            // Apply button
            SizedBox(
              width: double.infinity,
              child: KylePrimaryButton(
                text: 'Apply Now',
                onPressed: () => _openApplicationForm(context, ref),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Note about process
            Text(
              'After submitting your application, we\'ll review it and get back to you via email.',
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.electrolyte.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: AppColors.electrolyte,
            size: 20,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.subtitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                description,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openApplicationForm(BuildContext context, WidgetRef ref) async {
    try {
      // Get current user profile to pass user_id to the form
      final db = ref.read(appDatabaseProvider);
      final profile = await db.getCurrentUserProfile();

      // Build URL with user_id as query parameter
      // This allows you to identify the user when reviewing applications
      String formUrl = _baseFormUrl;
      if (profile != null) {
        final separator = _baseFormUrl.contains('?') ? '&' : '?';
        formUrl = '$_baseFormUrl${separator}user_id=${profile.id}';
      }

      final uri = Uri.parse(formUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open application form'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening form: $e'),
          ),
        );
      }
    }
  }
}
