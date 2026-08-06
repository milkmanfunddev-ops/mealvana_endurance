import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_controller.dart';
import '../../domain/onboarding_draft.dart';
import '../widgets/onboarding_multi_select_step.dart';
import '../../../../shared/services/app_external_deps.dart';

/// Goals Screen - Step 2 of Onboarding (2026-08 redesign)
///
/// Multi-select over [OnboardingGoal]. Non-blocking: zero selections is a
/// valid answer, so Continue is always enabled. Selections are mirrored into
/// the controller draft on every toggle.
class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key, this.onContinue, this.onBack, this.stepIndex});

  /// Callback to advance to next page (optional for PageView mode)
  final VoidCallback? onContinue;

  /// Callback to go back to previous page (optional for PageView mode)
  final VoidCallback? onBack;

  /// Position in the onboarding flow, stamped onto `screen_viewed` so the
  /// drop-off funnel can order the steps. Null outside onboarding.
  final int? stepIndex;

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  /// Seeded from the draft so revisiting the step restores prior answers.
  late Set<OnboardingGoal> _selected;

  @override
  void initState() {
    super.initState();

    _selected = Set.of(
      ref.read(onboardingControllerProvider.notifier).draft.goals,
    );

    ref
        .read(appExternalDepsProvider)
        .analytics
        .track(
          'screen_viewed',
          properties: {
            'screen_name': 'Goals Onboarding',
            if (widget.stepIndex != null) 'step_index': widget.stepIndex,
          },
        );
  }

  void _toggle(OnboardingGoal goal) {
    setState(() {
      if (!_selected.remove(goal)) {
        _selected.add(goal);
      }
    });
    ref.read(onboardingControllerProvider.notifier).updateGoals(_selected);
  }

  void _continue() async {
    final analytics = ref.read(appExternalDepsProvider).analytics;
    await analytics.track(
      'goals_selected',
      properties: {
        'goals': _selected.map((g) => g.dbValue).toList()..sort(),
        'count': _selected.length,
      },
    );

    if (!mounted) return;
    widget.onContinue?.call();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingMultiSelectStep<OnboardingGoal>(
      title: "What's your goal?",
      subtitle: 'Pick as many as you like — your plan serves them together.',
      titleKey: const ValueKey('goals.title'),
      stepIndex: widget.stepIndex,
      options: [
        for (final goal in OnboardingGoal.values)
          OnboardingMultiSelectOption(
            value: goal,
            label: goal.displayName,
            itemKey: ValueKey('goals.${goal.dbValue}_chip'),
          ),
      ],
      selected: _selected,
      onToggle: _toggle,
      onContinue: _continue,
      onBack: widget.onBack,
      continueButtonKey: const ValueKey('goals.continue_button'),
      backButtonKey: const ValueKey('goals.back_button'),
    );
  }
}
