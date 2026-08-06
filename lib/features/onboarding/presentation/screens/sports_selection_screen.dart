import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_controller.dart';
import '../../domain/onboarding_draft.dart';
import '../widgets/onboarding_multi_select_step.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';

/// Sports Selection Screen - Step 1 of Onboarding (2026-08 redesign)
///
/// Multi-select over [OnboardingSport] (Running, Cycling, Swimming,
/// Triathlon). Nothing is pre-selected; at least one selection is required to
/// continue. Selections are mirrored into the controller draft on every
/// toggle (plus the legacy sports cache, which older analytics/dynamic-page
/// code still reads until redesign phase 7 deletes it).
class SportsSelectionScreen extends ConsumerStatefulWidget {
  const SportsSelectionScreen({
    super.key,
    this.onContinue,
    this.onBack,
    this.onSportsChanged,
    this.stepIndex,
  });

  /// Callback to advance to next page (optional for PageView mode)
  final VoidCallback? onContinue;

  /// Callback to go back to previous page (optional for PageView mode)
  final VoidCallback? onBack;

  /// Position in the onboarding flow, stamped onto `screen_viewed` so the
  /// drop-off funnel can order the steps. Null outside onboarding.
  final int? stepIndex;

  /// Callback when sports selection changes. Legacy hook kept for callers
  /// that mirrored the selection (the pre-redesign PageView rebuilt its
  /// dynamic sport-detail pages from it); the current PageView is static and
  /// no longer passes it.
  final void Function(Set<String>)? onSportsChanged;

  @override
  ConsumerState<SportsSelectionScreen> createState() =>
      _SportsSelectionScreenState();
}

class _SportsSelectionScreenState extends ConsumerState<SportsSelectionScreen> {
  /// Local selection state, seeded from the draft so revisiting the step
  /// (back navigation, keep-alive eviction) restores prior answers.
  /// Deliberately NOT defaulted — nothing is pre-selected in the redesign.
  late Set<OnboardingSport> _selected;

  @override
  void initState() {
    super.initState();

    _selected = Set.of(
      ref.read(onboardingControllerProvider.notifier).draft.sports,
    );

    ref
        .read(appExternalDepsProvider)
        .analytics
        .track(
          'screen_viewed',
          properties: {
            'screen_name': 'Sports Selection Onboarding',
            if (widget.stepIndex != null) 'step_index': widget.stepIndex,
          },
        );
  }

  void _toggle(OnboardingSport sport) {
    setState(() {
      if (!_selected.remove(sport)) {
        _selected.add(sport);
      }
    });

    final controller = ref.read(onboardingControllerProvider.notifier);
    controller.updateSports(_selected);
    // Legacy bridge: cachedSelectedSports is still read by pre-redesign code
    // paths until phase 7 removes them. 'triathlon' round-trips through
    // OnboardingSport.fromDbValue inside the cache bridge.
    controller.cacheSelectedSports(_selected.map((s) => s.dbValue).toSet());
    widget.onSportsChanged?.call(_selected.map((s) => s.dbValue).toSet());
  }

  void _continue() async {
    // Defensive guard — the Continue button is already disabled while the
    // selection is empty, but a stale tap must not advance the flow.
    if (_selected.isEmpty) {
      MealvanaSnackbar.showInfo(context, 'Please select at least one sport');
      return;
    }

    final analytics = ref.read(appExternalDepsProvider).analytics;
    await analytics.track(
      'sports_selected',
      properties: {
        // Canonical shape for the redesigned funnel (§6): dbValue strings.
        'sports': _selected.map((s) => s.dbValue).toList()..sort(),
        // Legacy booleans kept so existing Mixpanel reports don't go dark.
        'running': _selected.contains(OnboardingSport.running),
        'cycling': _selected.contains(OnboardingSport.cycling),
        'swimming': _selected.contains(OnboardingSport.swimming),
        'triathlon': _selected.contains(OnboardingSport.triathlon),
        'count': _selected.length,
      },
    );

    if (!mounted) return;

    // PageView mode advances via callback. Standalone mode (widget tests,
    // deep links) has no follow-up step in the redesigned flow — the old
    // sport-detail routes are no longer part of onboarding.
    widget.onContinue?.call();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingMultiSelectStep<OnboardingSport>(
      title: 'Which sports do you train for?',
      subtitle: "We'll tune carb targets to each one. Nothing is pre-selected.",
      titleKey: const ValueKey('sport_selection.title'),
      stepIndex: widget.stepIndex,
      options: [
        for (final sport in OnboardingSport.values)
          OnboardingMultiSelectOption(
            value: sport,
            label: sport.displayName,
            itemKey: ValueKey('sport_selection.${sport.dbValue}_chip'),
          ),
      ],
      selected: _selected,
      onToggle: _toggle,
      onContinue: _continue,
      onBack: widget.onBack,
      canContinue: _selected.isNotEmpty,
      continueButtonKey: const ValueKey('sport_selection.continue_button'),
      backButtonKey: const ValueKey('sport_selection.back_button'),
    );
  }
}
