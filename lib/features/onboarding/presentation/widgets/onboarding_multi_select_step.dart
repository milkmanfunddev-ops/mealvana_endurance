import 'package:flutter/material.dart';
import '../providers/onboarding_analytics.dart';
import '../theme/onboarding_design_tokens.dart';

/// One selectable row rendered by [OnboardingMultiSelectStep].
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
/// pitfalls) — pixel port of the HTML spec's step screens.
///
/// Spec values (computed styles read from the rendered prototype):
/// header row padding 16/22/6 with a 32px cream-10% back circle and 4px-high
/// progress segments (radius 2, gap 14, active #f78b14, inactive cream 14%);
/// left-aligned Sansita 700 26px orange title; Apercu 14px cream-62% subcopy
/// 8px below; option rows 26px later — radius 15, cream-5% fill, 1px
/// cream-12% border, padding 15/16, 11px row gap; 26px checkbox (radius 7,
/// 1.5px cream-35% border; checked: teal fill + dark 14px check, no border),
/// 14px to the Apercu 500 16.5px cream label; footer pill identical to the
/// splash CTA (orange, padding 16, Sansita 700 17, plum text).
///
/// Per spec the Continue pill is NEVER dimmed — steps that gate advancement
/// keep the gate behavioral (tap guard), not visual.
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
  final int? stepIndex;

  final Key? titleKey;
  final Key? continueButtonKey;
  final Key? backButtonKey;

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
                    // Spec: ~54px from segment bottom to title top (6 of it
                    // is the header's own bottom padding), measured off the
                    // rendered prototype.
                    const SizedBox(height: 48),
                    Text(
                      title,
                      key: titleKey,
                      style: const TextStyle(
                        fontFamily: OnbTokens.fontDisplay,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: OnbTokens.orange,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: OnbTokens.fontBody,
                        fontSize: 14,
                        height: 1.45,
                        color: OnbTokens.creamA(0.62),
                      ),
                    ),
                    const SizedBox(height: 26),
                    for (final option in options) ...[
                      _SpecOptionRow(
                        key: option.itemKey,
                        label: option.label,
                        isSelected: selected.contains(option.value),
                        onTap: () => onToggle(option.value),
                      ),
                      if (option != options.last) const SizedBox(height: 11),
                    ],
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
                label: 'Continue',
                buttonKey: continueButtonKey,
                onTap: onContinue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Spec header row: back circle + equal-width progress segments.
/// padding 16/22/6; 32px circle at cream 10%; segments 4px high, radius 2,
/// gap 14, active #f78b14, inactive cream 14%.
class OnboardingStepHeader extends StatelessWidget {
  const OnboardingStepHeader({
    super.key,
    required this.stepIndex,
    this.onBack,
    this.backButtonKey,
  });

  final int stepIndex;
  final VoidCallback? onBack;
  final Key? backButtonKey;

  @override
  Widget build(BuildContext context) {
    final totalSegments = kOnboardingStepNames.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 6),
      child: Row(
        children: [
          if (onBack != null) ...[
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
            ),
            const SizedBox(width: 14),
          ],
          for (var i = 0; i < totalSegments; i++) ...[
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: i <= stepIndex
                      ? OnbTokens.orange
                      : OnbTokens.creamA(0.14),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (i != totalSegments - 1) const SizedBox(width: 14),
          ],
        ],
      ),
    );
  }
}

/// Spec primary CTA pill, shared by the step screens (identical values to
/// the splash "Build My Plan" button, sans glow on step screens).
class OnboardingSpecCta extends StatelessWidget {
  const OnboardingSpecCta({
    super.key,
    required this.label,
    required this.onTap,
    this.buttonKey,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final Key? buttonKey;

  /// Spec disabled state (personal-info step): bg rgba(247,139,20,.22),
  /// cream-40% label, tap inert. Steps without a spec disabled state pass
  /// true and keep the gate behavioral.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: enabled ? OnbTokens.orange : const Color(0x38F78B14),
        borderRadius: BorderRadius.circular(OnbTokens.rPill),
        child: InkWell(
          key: buttonKey,
          borderRadius: BorderRadius.circular(OnbTokens.rPill),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: OnbTokens.fontDisplay,
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: enabled ? OnbTokens.bg : OnbTokens.creamA(0.4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Spec option row: radius 15, cream-5% fill, 1px cream-12% border,
/// padding 15/16; 26px checkbox (radius 7) + 14px gap + label.
class _SpecOptionRow extends StatelessWidget {
  const _SpecOptionRow({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OnbTokens.creamA(0.05),
      borderRadius: BorderRadius.circular(OnbTokens.rCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(OnbTokens.rCard),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(OnbTokens.rCard),
            border: Border.all(color: OnbTokens.creamA(0.12)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isSelected ? OnbTokens.teal : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: isSelected
                      ? null
                      : Border.all(color: OnbTokens.creamA(0.35), width: 1.5),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: Color(0xFF10221E),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: OnbTokens.fontBody,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w500,
                    color: OnbTokens.cream,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
