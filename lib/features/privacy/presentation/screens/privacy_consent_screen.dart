import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import '../../../../shared/services/privacy/analytics_consent.dart';
import '../../../../shared/services/privacy/privacy_links.dart';
import '../../../../shared/services/privacy/privacy_region.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../app_startup/application/app_startup_service.dart';

/// First-run analytics disclosure.
///
/// Shown once, before anything is collected, to every user — signed-in or
/// anonymous — whenever [analyticsConsentProvider] reports `unknown`. It is the
/// only screen that can appear ahead of `/welcome`, because it has to precede
/// both `signInAnonymously()` and the deferred analytics init.
///
/// The regime ([ConsentRegime]) changes only how the choice is *presented*:
/// - [ConsentRegime.standard] — toggle starts ON. Disclosure plus an easy
///   opt-out, which is what US (ex-Washington) and most-of-world law asks for.
/// - [ConsentRegime.strict] — toggle starts OFF, and the user must turn it on.
///   GDPR/ePrivacy and Washington's MHMDA require an affirmative act; a
///   pre-checked box is not consent there.
///
/// Either way the user leaves with an explicit decision on file and nothing is
/// sent before they make it — which is what Apple Guideline 5.1.1(ii) requires
/// everywhere, regardless of regime.
class PrivacyConsentScreen extends ConsumerStatefulWidget {
  const PrivacyConsentScreen({super.key});

  @override
  ConsumerState<PrivacyConsentScreen> createState() =>
      _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends ConsumerState<PrivacyConsentScreen> {
  bool? _shareUsageData;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final regime = ref.watch(analyticsConsentProvider).regime;

    // Default the toggle from the regime: pre-set ON is a lawful disclosure +
    // opt-out under `standard`, and is specifically NOT valid consent under
    // `strict`.
    final shareUsageData = _shareUsageData ?? !regime.isStrict;

    return AdaptivePageScaffold(
      backgroundColor: AppColors.blackberry,
      contentWidth: AdaptiveContentWidth.narrow,
      body: AdaptiveScrollableBody(
        safeAreaTop: true,
        safeAreaBottom: true,
        padding: AppSpacing.screenPadding,
        footer: _buildFooter(context, regime, shareUsageData),
        child: _buildContent(context, regime, shareUsageData),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ConsentRegime regime,
    bool shareUsageData,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xxxl),
        Text(
          'Your privacy',
          style: AppTextStyles.pageTitle.copyWith(color: AppColors.cream),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Mealvana is a nutrition app, so the data you put in it is personal. '
          "Here's exactly what we do with it — before you start, not buried in "
          'a policy.',
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.cream.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _buildAlwaysOnCard(),
        const SizedBox(height: AppSpacing.md),
        _buildUsageDataCard(regime, shareUsageData),
        const SizedBox(height: AppSpacing.lg),
        _buildPolicyLinks(context),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  /// What runs regardless of the toggle — stated plainly, so the consent we do
  /// ask for is honest about its scope.
  Widget _buildAlwaysOnCard() {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'To run the app',
                  style: AppTextStyles.sectionTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your profile, workouts and meal logs are stored in your account so '
            'the app can plan your fueling. We also collect crash reports to '
            'keep the app working. This is what the app needs to do its job, '
            "and it isn't used for advertising — we run no ad SDKs and don't "
            'sell or share your data.',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildUsageDataCard(ConsentRegime regime, bool shareUsageData) {
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
                key: const ValueKey('privacy_consent.usage_toggle'),
                value: shareUsageData,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _shareUsageData = value),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Optional. Shares which screens and features you use — via Mixpanel '
            "— so we can see what's working and what isn't. It never includes "
            'your meals, weights or health data.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            regime.isStrict
                ? 'Off by default where you are. The app works exactly the same '
                    'either way, and you can change this any time in '
                    'Settings → Privacy.'
                : 'You can turn this off now, or any time in '
                    'Settings → Privacy.',
            style: AppTextStyles.smallLabel,
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyLinks(BuildContext context) {
    return Row(
      children: [
        KyleTertiaryButton(
          text: 'Privacy Policy',
          onPressed: () => openPrivacyPolicy(context),
        ),
        const SizedBox(width: AppSpacing.md),
        KyleTertiaryButton(
          text: 'Terms',
          onPressed: () => openTermsOfService(context),
        ),
      ],
    );
  }

  Widget _buildFooter(
    BuildContext context,
    ConsentRegime regime,
    bool shareUsageData,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: AppSpacing.lg,
      ),
      child: KylePrimaryButton(
        key: const ValueKey('privacy_consent.continue_button'),
        text: 'Continue',
        onPressed: _saving ? null : () => _submit(shareUsageData),
        isFullWidth: false,
      ),
    );
  }

  Future<void> _submit(bool shareUsageData) async {
    setState(() => _saving = true);

    await ref
        .read(analyticsConsentProvider.notifier)
        .record(granted: shareUsageData);

    // Deferred startup already ran and skipped analytics (consent was unknown),
    // so start it now rather than leaving the user untracked until next launch.
    if (shareUsageData) {
      await ref
          .read(appStartupServiceProvider)
          .initializeAnalyticsAfterConsent();
    }

    // The redirect is not reactive to consent, so navigate explicitly to make
    // it re-evaluate. With a decision now on file the gate falls through and
    // startup state decides where they actually land (/welcome, /main, ...).
    if (!mounted) return;
    context.go('/');
  }
}
