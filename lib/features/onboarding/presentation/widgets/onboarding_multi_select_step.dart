import 'package:flutter/material.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/navigation/figma_onboarding_footer.dart';
import '../../../../shared/widgets/selection/figma_checkbox_card.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../providers/onboarding_analytics.dart';
import 'onboarding_progress_bar.dart';

/// One selectable row rendered by [OnboardingMultiSelectStep].
///
/// The row visuals themselves come from the existing shared
/// [FigmaCheckboxCard] (also used by the allergies screen) — this class only
/// carries the per-option value/label/test-key triple.
class OnboardingMultiSelectOption<T> {
  const OnboardingMultiSelectOption({
    required this.value,
    required this.label,
    required this.itemKey,
  });

  /// Domain value toggled in/out of the selection set.
  final T value;

  /// User-facing row label.
  final String label;

  /// Stable [ValueKey] for Patrol/widget tests.
  final Key itemKey;
}

/// Shared layout for the onboarding multi-select steps (sports / goals /
/// pitfalls): progress bar, serif title, subcopy, a scrollable column of
/// checkbox card rows, and the standard footer.
///
/// Pure-UI: selection state lives in the owning screen, which mirrors it into
/// the OnboardingController draft. The options column sits inside an
/// [AdaptiveScrollableBody], so long lists (the 8-row pitfalls step) scroll
/// while short lists stay centered.
class OnboardingMultiSelectStep<T> extends StatelessWidget {
  const OnboardingMultiSelectStep({
    super.key,
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.onContinue,
    this.onBack,
    this.canContinue = true,
    this.stepIndex,
    this.titleKey,
    this.continueButtonKey,
    this.backButtonKey,
  });

  final String title;
  final String subtitle;
  final List<OnboardingMultiSelectOption<T>> options;
  final Set<T> selected;
  final ValueChanged<T> onToggle;
  final VoidCallback onContinue;
  final VoidCallback? onBack;
  final bool canContinue;

  /// Position in the onboarding flow (0-based); drives the progress bar.
  /// Null outside the PageView (standalone/test usage) — renders as step 1.
  final int? stepIndex;

  final Key? titleKey;
  final Key? continueButtonKey;
  final Key? backButtonKey;

  @override
  Widget build(BuildContext context) {
    return AdaptivePageScaffold(
      backgroundColor: AppColors.blackberry,
      contentWidth: AdaptiveContentWidth.narrow,
      body: Column(
        children: [
          // Progress bar at the very top (no SafeArea padding), one segment
          // per funnel step so the bar stays aligned with the analytics names.
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
              child: Align(
                alignment: Alignment.center,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      key: titleKey,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Sansita',
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.orange,
                        height: 1.0,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Apercu',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textDark,
                        letterSpacing: 0.192,
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 20),

                    for (final option in options) ...[
                      FigmaCheckboxCard(
                        key: option.itemKey,
                        label: option.label,
                        isSelected: selected.contains(option.value),
                        onTap: () => onToggle(option.value),
                      ),
                      if (option != options.last) const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Footer navigation
          FigmaOnboardingFooter(
            onContinue: onContinue,
            onBack: onBack,
            canContinue: canContinue,
            continueButtonKey: continueButtonKey,
            backButtonKey: backButtonKey,
          ),
        ],
      ),
    );
  }
}
