import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import '../../../../shared/services/privacy/analytics_consent.dart';
import '../../../../shared/services/privacy/privacy_links.dart';
import '../../../app_startup/application/app_startup_service.dart';

/// Settings → Privacy.
///
/// Two jobs, both compliance requirements rather than nice-to-haves:
/// 1. **Withdraw consent.** Apple 5.1.1(ii) requires "an easily accessible and
///    understandable way to withdraw consent" — this toggle is it, and it is
///    reachable in one tap from Settings, not behind a 7-tap easter egg.
/// 2. **Surface the policy.** 5.1.1(i) expects the privacy policy to be
///    reachable inside the app, not only from the store listing.
class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consent = ref.watch(analyticsConsentProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _buildUsageDataCard(context, ref, consent),
          const SizedBox(height: AppSpacing.md),
          _buildAlwaysOnCard(),
          const SizedBox(height: AppSpacing.md),
          _buildLegalCard(context),
        ],
      ),
    );
  }

  Widget _buildUsageDataCard(
    BuildContext context,
    WidgetRef ref,
    AnalyticsConsent consent,
  ) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Share anonymous usage data',
                  style: AppTextStyles.sectionTitle,
                ),
              ),
              KyleSwitch(
                key: const ValueKey('privacy_settings.usage_toggle'),
                value: consent.allowsAnalytics,
                onChanged: (value) => _setConsent(context, ref, value),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Shares which screens and features you use — via Mixpanel — so we '
            "can see what's working. It never includes your meals, weights or "
            'health data, and we run no advertising SDKs.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            consent.allowsAnalytics
                ? 'Turning this off stops usage data immediately.'
                : 'Usage data is off. The app works exactly the same.',
            style: AppTextStyles.smallLabel,
          ),
        ],
      ),
    );
  }

  Widget _buildAlwaysOnCard() {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('To run the app', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your profile, workouts and meal logs are stored in your account so '
            'the app can plan your fueling, and we collect crash reports to keep '
            'it working. These are needed to provide the service and are not '
            'covered by the toggle above. We never sell or share your data, and '
            'we run no advertising SDKs.',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildLegalCard(BuildContext context) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Legal', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          _buildLinkRow(
            context,
            icon: Icons.shield_outlined,
            label: 'Privacy Policy',
            rowKey: 'privacy_settings.policy_link',
            onTap: () => openPrivacyPolicy(context),
          ),
          _buildLinkRow(
            context,
            icon: Icons.description_outlined,
            label: 'Terms of Service',
            rowKey: 'privacy_settings.terms_link',
            onTap: () => openTermsOfService(context),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String rowKey,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: ValueKey(rowKey),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: AppTextStyles.bodyLarge)),
            const Icon(Icons.open_in_new, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _setConsent(
    BuildContext context,
    WidgetRef ref,
    bool granted,
  ) async {
    await ref.read(analyticsConsentProvider.notifier).record(granted: granted);

    if (granted) {
      // Opting back in mid-session: start Mixpanel now rather than waiting for
      // the next cold start.
      await ref
          .read(appStartupServiceProvider)
          .initializeAnalyticsAfterConsent();
      if (!context.mounted) return;
      MealvanaSnackbar.showSuccess(context, 'Usage data sharing is on');
    } else {
      // Withdrawal takes effect immediately for Mixpanel — analyticsTracker
      // rebuilds to a Noop. Sentry session replay is armed at SentryFlutter.init
      // and so stays configured until the next launch; crash reporting is
      // unaffected either way.
      if (!context.mounted) return;
      MealvanaSnackbar.showSuccess(context, 'Usage data sharing is off');
    }
  }
}
