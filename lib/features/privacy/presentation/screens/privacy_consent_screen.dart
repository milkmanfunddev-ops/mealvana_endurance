import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import '../../../../shared/services/privacy/analytics_consent.dart';
import '../../../../shared/services/privacy/privacy_links.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/navigation/figma_onboarding_footer.dart';
import '../../../app_startup/application/app_startup_service.dart';

/// The analytics consent step.
///
/// Shown ONLY to strict-regime users — EEA/UK (GDPR/ePrivacy) and Washington
/// (My Health My Data Act). Both require consent to be an affirmative act, so
/// the toggle starts OFF and the user has to turn it on; a pre-checked box is
/// not consent there, and MHMDA additionally forbids inferring consent from
/// acceptance of the ToS. Everywhere else, disclosure plus an accessible
/// opt-out is the standard — those users are never sent here and instead get
/// the always-available Settings → Privacy toggle.
///
/// Reached two ways, both of which route here explicitly rather than
/// intercepting: Welcome's "Get Started" (so it reads as the first step of
/// onboarding), and the startup redirect for existing users who were onboarded
/// before the prompt existed. [next] is where to go once a decision is on file.
///
/// Styled to match the onboarding steps (blackberry / Sansita title / Apercu
/// body / [FigmaOnboardingFooter]) rather than the Kyle card language, because
/// it now sits inside that flow.
class PrivacyConsentScreen extends ConsumerStatefulWidget {
  const PrivacyConsentScreen({super.key, this.next = '/'});

  /// Where to go once the decision is recorded.
  final String next;

  @override
  ConsumerState<PrivacyConsentScreen> createState() =>
      _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends ConsumerState<PrivacyConsentScreen> {
  // Starts OFF. Only strict-regime users reach this screen, and in a strict
  // regime a pre-set toggle is not a lawful default — consent has to be given,
  // not withheld.
  bool _shareUsageData = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return AdaptivePageScaffold(
      backgroundColor: AppColors.blackberry,
      contentWidth: AdaptiveContentWidth.narrow,
      body: AdaptiveScrollableBody(
        safeAreaTop: true,
        safeAreaBottom: true,
        padding: const EdgeInsets.all(20),
        footer: FigmaOnboardingFooter(
          continueButtonKey: const ValueKey('privacy_consent.continue_button'),
          onContinue: _saving ? null : _submit,
          isLoading: _saving,
          showBackButton: false,
        ),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 48),
        const Text(
          'Your privacy',
          style: TextStyle(
            fontFamily: 'Sansita',
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.orange,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'You choose what we can learn from how you use the app.',
          style: TextStyle(
            fontFamily: 'Apercu',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: AppColors.textDark,
            letterSpacing: 0.192,
          ),
        ),
        const SizedBox(height: 32),
        _buildUsageToggle(),
        const SizedBox(height: 24),
        _buildPolicyLinks(context),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildUsageToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Share usage data',
                style: TextStyle(
                  fontFamily: 'Sansita',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ),
            KyleSwitch(
              key: const ValueKey('privacy_consent.usage_toggle'),
              value: _shareUsageData,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _shareUsageData = value),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // This one line is the entire disclosure, so it has to be true and
        // complete. It must NAME the processor and NAME the health-adjacent
        // properties: identifyUser() sends Gender / Age / Weight (lbs) / Runs
        // With Water Bottle / Gut Training Level to Mixpanel People. Those
        // properties are precisely why Washington's MHMDA applies at all. An
        // earlier draft omitted them and was false. If they are ever removed
        // from analytics_tracker.dart, tighten this copy and the smoke test
        // together. Do not shorten this line further.
        const Text(
          'Optional. Sends which screens you use, plus basic profile details '
          '(age, gender, weight), to Mixpanel. Never your meal logs.',
          style: TextStyle(
            fontFamily: 'Apercu',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textDarkSecondary,
            height: 1.4,
          ),
        ),
      ],
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

  Future<void> _submit() async {
    setState(() => _saving = true);

    await ref
        .read(analyticsConsentProvider.notifier)
        .record(granted: _shareUsageData);

    // Deferred startup already ran and skipped analytics (consent was unknown),
    // so start it now rather than leaving the user untracked until next launch.
    if (_shareUsageData) {
      await ref
          .read(appStartupServiceProvider)
          .initializeAnalyticsAfterConsent();
    }

    if (!mounted) return;
    // pushReplacement, not go: keeps Welcome beneath us on the onboarding entry
    // path so the back gesture behaves, while still removing this screen.
    context.pushReplacement(widget.next);
  }
}
