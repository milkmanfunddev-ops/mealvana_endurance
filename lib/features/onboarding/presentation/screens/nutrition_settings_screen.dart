import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/services/app_external_deps.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../auth/domain/user_preferences.dart';
import '../providers/onboarding_controller.dart';
import '../widgets/onboarding_step_scaffold.dart';

/// Nutrition Settings Screen - Step 7 of Onboarding (2026-08 redesign)
///
/// The two dials the fueling formulas need but the old flow never asked for:
/// gut training level (carb-rate multiplier) and sweat rate (fluid/sodium
/// multiplier). Defaults (Moderate / Medium) are preselected — they match
/// the draft's defaults, so this step never blocks. Selections mirror into
/// the draft immediately.
class NutritionSettingsScreen extends ConsumerStatefulWidget {
  const NutritionSettingsScreen({
    super.key,
    this.onContinue,
    this.onBack,
    this.stepIndex,
  });

  /// Callback to advance to next page (optional for PageView mode)
  final VoidCallback? onContinue;

  /// Callback to go back to previous page (optional for PageView mode)
  final VoidCallback? onBack;

  /// Position in the onboarding flow, stamped onto `screen_viewed` so the
  /// drop-off funnel can order the steps. Null outside onboarding.
  final int? stepIndex;

  @override
  ConsumerState<NutritionSettingsScreen> createState() =>
      _NutritionSettingsScreenState();
}

class _NutritionSettingsScreenState
    extends ConsumerState<NutritionSettingsScreen> {
  late GutTraining _gutTraining;
  late SweatRateCat _sweatRate;

  OnboardingController get _controller =>
      ref.read(onboardingControllerProvider.notifier);

  @override
  void initState() {
    super.initState();

    // Seeded from the draft (defaults Moderate / Medium).
    final draft = _controller.draft;
    _gutTraining = draft.gutTraining;
    _sweatRate = draft.sweatRate;

    ref
        .read(appExternalDepsProvider)
        .analytics
        .track(
          'screen_viewed',
          properties: {
            'screen_name': 'Nutrition Settings Onboarding',
            if (widget.stepIndex != null) 'step_index': widget.stepIndex,
          },
        );
  }

  static String _gutCaption(GutTraining gut) {
    switch (gut) {
      case GutTraining.low:
        return "I rarely practice fueling during workouts.";
      case GutTraining.moderate:
        return "I'm regularly fueling my long workouts.";
      case GutTraining.high:
        return "I've trained my gut to handle high carb intake.";
    }
  }

  static String _gutMultiplier(GutTraining gut) {
    switch (gut) {
      case GutTraining.low:
        return '0.7×';
      case GutTraining.moderate:
        return '1.0×';
      case GutTraining.high:
        return '1.2×';
    }
  }

  static String _sweatCaption(SweatRateCat sweat) {
    switch (sweat) {
      case SweatRateCat.light:
        return 'I barely break a sweat on most sessions.';
      case SweatRateCat.medium:
        return 'A normal amount — damp after a hard session.';
      case SweatRateCat.heavy:
        return "I'm drenched — kit soaked after hard sessions.";
    }
  }

  static String _sweatMultiplier(SweatRateCat sweat) {
    switch (sweat) {
      case SweatRateCat.light:
        return '0.85×';
      case SweatRateCat.medium:
        return '1.0×';
      case SweatRateCat.heavy:
        return '1.2×';
    }
  }

  static String _gutLabel(GutTraining gut) {
    switch (gut) {
      case GutTraining.low:
        return 'Low';
      case GutTraining.moderate:
        return 'Moderate';
      case GutTraining.high:
        return 'High';
    }
  }

  void _selectGut(GutTraining gut) {
    setState(() => _gutTraining = gut);
    _controller.updateNutritionSettings(gutTraining: gut);
  }

  void _selectSweat(SweatRateCat sweat) {
    setState(() => _sweatRate = sweat);
    _controller.updateNutritionSettings(sweatRate: sweat);
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      title: 'Nutrition Settings',
      subtitle: 'Two dials that tune your per-hour targets.',
      titleKey: const ValueKey('nutrition_settings.title'),
      stepIndex: widget.stepIndex,
      onContinue: widget.onContinue,
      onBack: widget.onBack,
      continueButtonKey: const ValueKey('nutrition_settings.continue_button'),
      backButtonKey: const ValueKey('nutrition_settings.back_button'),
      children: [
        _SettingCard(
          label: 'GUT TRAINING LEVEL',
          sublabel: "Your gut's ability to absorb carbs during exercise",
          caption: _gutCaption(_gutTraining),
          segments: [
            for (final gut in GutTraining.values)
              _SegmentSpec(
                key: ValueKey('nutrition_settings.gut_${gut.name}'),
                label: _gutLabel(gut),
                multiplier: _gutMultiplier(gut),
                isSelected: gut == _gutTraining,
                onTap: () => _selectGut(gut),
              ),
          ],
        ),
        const SizedBox(height: 20),
        _SettingCard(
          label: 'SWEAT RATE',
          sublabel: 'How much you typically sweat during exercise',
          caption: _sweatCaption(_sweatRate),
          segments: [
            for (final sweat in SweatRateCat.values)
              _SegmentSpec(
                key: ValueKey('nutrition_settings.sweat_${sweat.name}'),
                label: sweat.displayName,
                multiplier: _sweatMultiplier(sweat),
                isSelected: sweat == _sweatRate,
                onTap: () => _selectSweat(sweat),
              ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          "Not sure? Keep the defaults — we'll refine both as you log "
          'sessions.',
          textAlign: TextAlign.center,
          style: kOnboardingBodyMutedStyle,
        ),
      ],
    );
  }
}

class _SegmentSpec {
  const _SegmentSpec({
    required this.key,
    required this.label,
    required this.multiplier,
    required this.isSelected,
    required this.onTap,
  });

  final Key key;
  final String label;
  final String multiplier;
  final bool isSelected;
  final VoidCallback onTap;
}

/// One dial card: small-caps label, explainer, a 3-segment selector, and a
/// plain-language caption for the current selection.
class _SettingCard extends StatelessWidget {
  const _SettingCard({
    required this.label,
    required this.sublabel,
    required this.caption,
    required this.segments,
  });

  final String label;
  final String sublabel;
  final String caption;
  final List<_SegmentSpec> segments;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: onboardingCardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: kOnboardingSectionLabelStyle),
          const SizedBox(height: 4),
          Text(sublabel, style: kOnboardingBodyMutedStyle),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < segments.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _SegmentChip(spec: segments[i])),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(caption, style: kOnboardingBodyMutedStyle),
        ],
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({required this.spec});

  final _SegmentSpec spec;

  @override
  Widget build(BuildContext context) {
    final foreground = spec.isSelected
        ? AppColors.blackberry
        : AppColors.cream.withValues(alpha: 0.7);

    return GestureDetector(
      key: spec.key,
      onTap: spec.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: spec.isSelected ? AppColors.cream : Colors.transparent,
          border: Border.all(color: AppColors.cream, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              spec.label,
              style: TextStyle(
                fontFamily: 'Apercu',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              spec.multiplier,
              style: TextStyle(
                fontFamily: 'Apercu',
                fontSize: 11,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
