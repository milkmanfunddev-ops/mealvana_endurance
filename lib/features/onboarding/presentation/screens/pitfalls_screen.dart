import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_controller.dart';
import '../../domain/onboarding_draft.dart';
import '../widgets/onboarding_multi_select_step.dart';
import '../../../../shared/services/app_external_deps.dart';

/// Pitfalls Screen - Step 3 of Onboarding (2026-08 redesign)
///
/// Multi-select over [OnboardingPitfall] ("What's getting in the way?").
/// Non-blocking: zero selections is a valid answer, so Continue is always
/// enabled. The 8-row option list scrolls via the shared step layout's
/// AdaptiveScrollableBody. Selections are mirrored into the controller draft
/// on every toggle.
class PitfallsScreen extends ConsumerStatefulWidget {
  const PitfallsScreen({
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
  ConsumerState<PitfallsScreen> createState() => _PitfallsScreenState();
}

class _PitfallsScreenState extends ConsumerState<PitfallsScreen> {
  /// Seeded from the draft so revisiting the step restores prior answers.
  late Set<OnboardingPitfall> _selected;

  @override
  void initState() {
    super.initState();

    _selected = Set.of(
      ref.read(onboardingControllerProvider.notifier).draft.pitfalls,
    );

    ref
        .read(appExternalDepsProvider)
        .analytics
        .track(
          'screen_viewed',
          properties: {
            'screen_name': 'Pitfalls Onboarding',
            if (widget.stepIndex != null) 'step_index': widget.stepIndex,
          },
        );
  }

  void _toggle(OnboardingPitfall pitfall) {
    setState(() {
      if (!_selected.remove(pitfall)) {
        _selected.add(pitfall);
      }
    });
    ref.read(onboardingControllerProvider.notifier).updatePitfalls(_selected);
  }

  void _continue() async {
    final analytics = ref.read(appExternalDepsProvider).analytics;
    await analytics.track(
      'pitfalls_selected',
      properties: {
        'pitfalls': _selected.map((p) => p.dbValue).toList()..sort(),
        'count': _selected.length,
      },
    );

    if (!mounted) return;
    widget.onContinue?.call();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingMultiSelectStep<OnboardingPitfall>(
      title: "What's getting in the way?",
      subtitle:
          "Most athletes are winging some part of this — that's why we're "
          'here. Choose all that apply.',
      titleKey: const ValueKey('pitfalls.title'),
      stepIndex: widget.stepIndex,
      options: [
        for (final pitfall in OnboardingPitfall.values)
          OnboardingMultiSelectOption(
            value: pitfall,
            label: pitfall.displayName,
            itemKey: ValueKey('pitfalls.${pitfall.dbValue}_chip'),
          ),
      ],
      selected: _selected,
      onToggle: _toggle,
      onContinue: _continue,
      onBack: widget.onBack,
      continueButtonKey: const ValueKey('pitfalls.continue_button'),
      backButtonKey: const ValueKey('pitfalls.back_button'),
    );
  }
}
