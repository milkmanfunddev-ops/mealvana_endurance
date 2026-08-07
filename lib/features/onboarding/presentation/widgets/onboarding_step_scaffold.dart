import 'package:flutter/material.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../theme/onboarding_design_tokens.dart';
import 'onboarding_multi_select_step.dart';

/// Serif page title used across the redesigned onboarding steps
/// (HTML-spec values: Sansita 700 26, line-height 1.05, #f78b14, left).
const kOnboardingTitleStyle = TextStyle(
  fontFamily: OnbTokens.fontDisplay,
  fontSize: 26,
  fontWeight: FontWeight.w700,
  color: OnbTokens.orange,
  height: 1.05,
);

/// Subcopy line under the title (spec: Apercu 14, lh 1.45, cream 62%).
const kOnboardingSubtitleStyle = TextStyle(
  fontFamily: OnbTokens.fontBody,
  fontSize: 14,
  fontWeight: FontWeight.w400,
  color: Color(0x9EF8F6EB),
  height: 1.45,
);

/// Small-caps section label inside cards (e.g. "PERSONAL INFORMATION").
const kOnboardingSectionLabelStyle = TextStyle(
  fontFamily: 'Apercu',
  fontSize: 12,
  fontWeight: FontWeight.w700,
  color: AppColors.textDarkSecondary,
  letterSpacing: 1.2,
);

/// Secondary body text on the dark scaffold.
const kOnboardingBodyMutedStyle = TextStyle(
  fontFamily: 'Apercu',
  fontSize: 13,
  fontWeight: FontWeight.w400,
  color: AppColors.textDarkSecondary,
  height: 1.3,
);

/// Card container used by the onboarding form steps on the dark scaffold.
BoxDecoration onboardingCardDecoration() => BoxDecoration(
  color: AppColors.blackberryLight,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: AppColors.cream.withValues(alpha: 0.12)),
);

/// Shared layout for the onboarding form/reveal steps (personal info, body
/// composition, nutrition settings, plan reveal, daily preview): 9-segment
/// progress bar, serif title, subcopy, a scrollable content column, and the
/// standard footer. Same visual language as [OnboardingMultiSelectStep]
/// (dark blackberry scaffold, Sansita/orange title).
///
/// Pure-UI: all state lives in the owning screen.
class OnboardingStepScaffold extends StatelessWidget {
  const OnboardingStepScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    required this.onContinue,
    this.onBack,
    this.canContinue = true,
    this.isLoading = false,
    this.stepIndex,
    this.titleKey,
    this.continueButtonKey,
    this.backButtonKey,
    this.continueLabel = 'Continue',
  });

  final String title;
  final String? subtitle;

  /// Content rendered below the title/subtitle inside the scrollable body.
  final List<Widget> children;

  final VoidCallback? onContinue;
  final VoidCallback? onBack;
  final bool canContinue;
  final bool isLoading;

  /// Position in the onboarding flow (0-based); drives the progress bar.
  /// Null outside the PageView (standalone/test usage) — renders as step 1.
  final int? stepIndex;

  final Key? titleKey;
  final Key? continueButtonKey;
  final Key? backButtonKey;

  /// Footer button label ("Continue" everywhere except the final step's
  /// "Save My Plan").
  final String continueLabel;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: OnbTokens.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            OnboardingStepHeader(
              stepIndex: stepIndex ?? 0,
              onBack: onBack,
              backButtonKey: backButtonKey,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Spec: ~54px segment-bottom → title-top (6 is header
                    // bottom padding), matching the multi-select steps.
                    const SizedBox(height: 48),
                    Text(title, key: titleKey, style: kOnboardingTitleStyle),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(subtitle!, style: kOnboardingSubtitleStyle),
                    ],
                    const SizedBox(height: 26),
                    ...children,
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                8,
                24,
                bottomInset > 34 ? bottomInset : 34,
              ),
              child: OnboardingSpecCta(
                label: continueLabel,
                buttonKey: continueButtonKey,
                enabled: canContinue && !isLoading,
                onTap: () => onContinue?.call(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashed "no training platform connected yet" nudge card shown on the plan
/// reveal and daily preview when onboarding finished without a connect.
/// "Connect now" pops the PageView back to the connect step.
class OnboardingConnectNudgeCard extends StatelessWidget {
  const OnboardingConnectNudgeCard({
    super.key,
    required this.onConnectNow,
    this.connectButtonKey,
  });

  final VoidCallback onConnectNow;
  final Key? connectButtonKey;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: AppColors.cream.withValues(alpha: 0.4),
        radius: 16,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'No training platform connected yet',
              textAlign: TextAlign.center,
              style: kOnboardingBodyMutedStyle,
            ),
            const SizedBox(height: 4),
            TextButton(
              key: connectButtonKey,
              onPressed: onConnectNow,
              child: const Text(
                'Connect now',
                style: TextStyle(
                  fontFamily: 'Apercu',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.orange,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    const dashLength = 6.0;
    const gapLength = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashLength),
          paint,
        );
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
