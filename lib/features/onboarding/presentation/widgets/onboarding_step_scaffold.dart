import 'package:flutter/material.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/navigation/figma_onboarding_footer.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../providers/onboarding_analytics.dart';
import 'onboarding_progress_bar.dart';

/// Serif page title used across the redesigned onboarding steps.
const kOnboardingTitleStyle = TextStyle(
  fontFamily: 'Sansita',
  fontSize: 26,
  fontWeight: FontWeight.w700,
  color: AppColors.orange,
  height: 1.0,
);

/// Subcopy line under the title.
const kOnboardingSubtitleStyle = TextStyle(
  fontFamily: 'Apercu',
  fontSize: 16,
  fontWeight: FontWeight.w400,
  color: AppColors.textDark,
  letterSpacing: 0.192,
  height: 1.2,
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
    return AdaptivePageScaffold(
      backgroundColor: AppColors.blackberry,
      contentWidth: AdaptiveContentWidth.narrow,
      body: Column(
        children: [
          // Progress bar at the very top, one segment per funnel step so the
          // bar stays aligned with the analytics names.
          Container(
            color: AppColors.blackberry,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
            child: OnboardingProgressBar(
              currentSegment: (stepIndex ?? 0) + 1,
              totalSegments: kOnboardingStepNames.length,
            ),
          ),

          // Content
          Expanded(
            child: AdaptiveScrollableBody(
              safeAreaTop: false,
              safeAreaBottom: false,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    key: titleKey,
                    textAlign: TextAlign.center,
                    style: kOnboardingTitleStyle,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      style: kOnboardingSubtitleStyle,
                    ),
                  ],
                  const SizedBox(height: 20),
                  ...children,
                ],
              ),
            ),
          ),

          // Footer navigation
          FigmaOnboardingFooter(
            onContinue: onContinue,
            onBack: onBack,
            canContinue: canContinue,
            isLoading: isLoading,
            buttonText: continueLabel,
            continueButtonKey: continueButtonKey,
            backButtonKey: backButtonKey,
          ),
        ],
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
