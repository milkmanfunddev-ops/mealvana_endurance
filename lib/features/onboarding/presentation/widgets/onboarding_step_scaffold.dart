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
    this.eyebrow,
    this.titleStyle,
    this.subtitle,
    required this.children,
    required this.onContinue,
    this.onBack,
    this.canContinue = true,
    this.isLoading = false,
    this.stepIndex,
    this.showProgress = true,
    this.titleKey,
    this.continueButtonKey,
    this.backButtonKey,
    this.continueLabel = 'Continue',
  });

  final String title;

  /// Teal letterspaced kicker above the title (spec: Apercu 500 11,
  /// ls 1.54, uppercase, #1cf9cf) — the reveal/daily screens use it.
  final String? eyebrow;

  /// Overrides the default orange title style (the reveal titles are cream).
  final TextStyle? titleStyle;

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

  /// Spec: the reveal/daily screens drop the progress segments and keep
  /// only the back circle.
  final bool showProgress;

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
            if (showProgress)
              OnboardingStepHeader(
                stepIndex: stepIndex ?? 0,
                onBack: onBack,
                backButtonKey: backButtonKey,
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 6),
                child: Row(
                  children: [
                    if (onBack != null)
                      InkWell(
                        key: backButtonKey,
                        customBorder: const CircleBorder(),
                        onTap: onBack,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: OnbTokens.creamA(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chevron_left,
                            size: 18,
                            color: OnbTokens.creamA(0.8),
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 32),
                  ],
                ),
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
                    if (eyebrow != null) ...[
                      Text(
                        eyebrow!.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: OnbTokens.fontBody,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.54,
                          color: OnbTokens.teal,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      title,
                      key: titleKey,
                      style: titleStyle ?? kOnboardingTitleStyle,
                    ),
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

/// Connect-nudge card shown on the plan reveal and daily preview when
/// onboarding finished without a connect — spec port.
///
/// Reveal variant: 1px DASHED cream-20% border, cream-4% fill, radius 15,
/// padding 16; teal-tinted 34px icon box; Apercu 13.5/500 cream title;
/// 12px cream-55% body; teal 13/500 underlined "Connect now".
/// The daily preview passes its own copy and the spec's larger icon box
/// (40px, radius 12, watch glyph — its card is Garmin-specific).
class OnboardingConnectNudgeCard extends StatelessWidget {
  const OnboardingConnectNudgeCard({
    super.key,
    required this.onConnectNow,
    this.connectButtonKey,
    this.title = 'No training platform connected yet',
    this.body =
        "These targets stand on their own — connect a platform and we'll "
        'fuel each scheduled session too.',
    this.icon = Icons.monitor_heart_outlined,
    this.iconBoxSize = 34,
    this.iconBoxRadius = 8,
  });

  final VoidCallback onConnectNow;
  final Key? connectButtonKey;
  final String title;
  final String body;
  final IconData icon;
  final double iconBoxSize;
  final double iconBoxRadius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: OnboardingDashedBorderPainter(
        color: const Color(0x33F8F6EB), // cream 20%
        radius: 15,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: OnbTokens.creamA(0.04),
          borderRadius: BorderRadius.circular(OnbTokens.rCard),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: iconBoxSize,
              height: iconBoxSize,
              decoration: BoxDecoration(
                color: const Color(0x261CF9CF), // teal 15%
                borderRadius: BorderRadius.circular(iconBoxRadius),
              ),
              child: Icon(
                icon,
                size: iconBoxSize > 34 ? 20 : 18,
                color: OnbTokens.teal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: OnbTokens.fontBody,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: OnbTokens.cream,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: TextStyle(
                      fontFamily: OnbTokens.fontBody,
                      fontSize: 12,
                      height: 1.4,
                      color: OnbTokens.creamA(0.55),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    key: connectButtonKey,
                    onTap: onConnectNow,
                    child: const Text(
                      'Connect now',
                      style: TextStyle(
                        fontFamily: OnbTokens.fontBody,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: OnbTokens.teal,
                        decoration: TextDecoration.underline,
                        decorationColor: OnbTokens.teal,
                      ),
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
}

/// Dashed rounded-rect border (spec nudge card + sweat-test tile).
class OnboardingDashedBorderPainter extends CustomPainter {
  const OnboardingDashedBorderPainter({
    required this.color,
    required this.radius,
  });

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
  bool shouldRepaint(OnboardingDashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
