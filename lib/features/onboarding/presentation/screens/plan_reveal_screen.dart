import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/navigation/figma_onboarding_footer.dart';
import '../../../nutrition_plan/domain/nutrition_target_overrides.dart';
import '../../domain/onboarding_draft.dart';
import '../../domain/onboarding_plan_preview.dart';
import '../providers/onboarding_analytics.dart';
import '../providers/onboarding_controller.dart';
import '../providers/onboarding_preview_providers.dart';
import '../widgets/onboarding_progress_bar.dart';
import '../widgets/onboarding_step_scaffold.dart';

/// Plan Reveal Screen - Step 8 of Onboarding (2026-08 redesign)
///
/// The centerpiece: after a "Building your plan…" loader (≥1.5 s perceived
/// work; awaits the imported-workout digest — with its 10 s timeout — when a
/// platform was connected), reveals the computed fueling targets from
/// [onboardingPlanPreviewProvider] with per-target edit affordances. Edits go
/// through `applyPlanEdits` (only touched fields non-null) and are clamped in
/// the UI by the same `NutritionTargetGuardrails` constants the save path
/// applies.
class PlanRevealScreen extends ConsumerStatefulWidget {
  const PlanRevealScreen({
    super.key,
    this.onContinue,
    this.onBack,
    this.stepIndex,
    this.onConnectTap,
  });

  /// Callback to advance to next page (optional for PageView mode)
  final VoidCallback? onContinue;

  /// Callback to go back to previous page (optional for PageView mode)
  final VoidCallback? onBack;

  /// Position in the onboarding flow, stamped onto `screen_viewed` so the
  /// drop-off funnel can order the steps. Null outside onboarding.
  final int? stepIndex;

  /// Pops the PageView back to the connect step (page 3). Wired by the
  /// pageview; null outside it (nudge card hides its action then).
  final VoidCallback? onConnectTap;

  @override
  ConsumerState<PlanRevealScreen> createState() => _PlanRevealScreenState();
}

class _PlanRevealScreenState extends ConsumerState<PlanRevealScreen> {
  /// Minimum loader time — perceived work even for the no-connect path,
  /// where the preview computes instantly.
  static const _minLoaderDuration = Duration(milliseconds: 1500);

  Timer? _minDelayTimer;
  bool _minDelayElapsed = false;
  bool _revealTracked = false;

  OnboardingController get _controller =>
      ref.read(onboardingControllerProvider.notifier);

  @override
  void initState() {
    super.initState();

    _minDelayTimer = Timer(_minLoaderDuration, () {
      if (mounted) setState(() => _minDelayElapsed = true);
    });

    ref
        .read(appExternalDepsProvider)
        .analytics
        .track(
          'screen_viewed',
          properties: {
            'screen_name': 'Plan Reveal Onboarding',
            if (widget.stepIndex != null) 'step_index': widget.stepIndex,
          },
        );
  }

  @override
  void dispose() {
    _minDelayTimer?.cancel();
    super.dispose();
  }

  void _trackRevealOnce(OnboardingPlanPreview preview) {
    if (_revealTracked) return;
    _revealTracked = true;
    // Fired from build — defer so analytics never interferes with the frame.
    final analytics = ref.read(appExternalDepsProvider).analytics;
    scheduleMicrotask(() {
      analytics.track(
        'plan_preview_viewed',
        properties: {
          'is_generic': preview.isGeneric,
          'used_training_data': preview.usedTrainingData,
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild on draft changes (plan edits, connect state).
    ref.watch(onboardingControllerProvider);
    final bundleAsync = ref.watch(onboardingPlanPreviewProvider);
    // `.value` keeps the previous bundle visible through in-place
    // recomputes (draft edits) instead of flashing the loader.
    final bundle = bundleAsync.value;

    // The provider degrades to a generic preview on any failure, so the only
    // long-lived loading state is the digest await (bounded at 10 s).
    if (!_minDelayElapsed || bundle == null) {
      return _buildLoader();
    }

    _trackRevealOnce(bundle.preview);
    return _buildReveal(bundle);
  }

  // ---------------------------------------------------------------------
  // Loader
  // ---------------------------------------------------------------------

  Widget _buildLoader() {
    return AdaptivePageScaffold(
      backgroundColor: AppColors.blackberry,
      contentWidth: AdaptiveContentWidth.narrow,
      body: Column(
        children: [
          Container(
            color: AppColors.blackberry,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
            child: OnboardingProgressBar(
              currentSegment: (widget.stepIndex ?? 0) + 1,
              totalSegments: kOnboardingStepNames.length,
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/endurance_welcome_logo.png',
                    width: 120,
                  ),
                  const SizedBox(height: 28),
                  const CircularProgressIndicator(color: AppColors.orange),
                  const SizedBox(height: 20),
                  const Text(
                    'Building your plan…',
                    key: ValueKey('plan_reveal.loader'),
                    textAlign: TextAlign.center,
                    style: kOnboardingTitleStyle,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Crunching your carbs, fluids and sodium.',
                    textAlign: TextAlign.center,
                    style: kOnboardingBodyMutedStyle,
                  ),
                ],
              ),
            ),
          ),
          // Footer stays visible but disabled so the layout doesn't jump.
          FigmaOnboardingFooter(
            onContinue: widget.onContinue,
            onBack: widget.onBack,
            canContinue: false,
            continueButtonKey: const ValueKey('plan_reveal.continue_button'),
            backButtonKey: const ValueKey('plan_reveal.back_button'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Reveal
  // ---------------------------------------------------------------------

  Widget _buildReveal(OnboardingPreviewBundle bundle) {
    final preview = bundle.preview;
    final draft = _controller.draft;
    final edits = draft.planEdits;
    final firstName = draft.firstName?.trim();

    return OnboardingStepScaffold(
      title: firstName != null && firstName.isNotEmpty
          ? 'We built your plan, $firstName.'
          : 'We built your plan.',
      subtitle: 'Every number traces back to what you told us.',
      titleKey: const ValueKey('plan_reveal.title'),
      stepIndex: widget.stepIndex,
      onContinue: widget.onContinue,
      onBack: widget.onBack,
      continueButtonKey: const ValueKey('plan_reveal.continue_button'),
      backButtonKey: const ValueKey('plan_reveal.back_button'),
      children: [
        if (preview.isGeneric) ...[
          const Text(
            'Estimates — add your details for accuracy.',
            key: ValueKey('plan_reveal.generic_caption'),
            textAlign: TextAlign.center,
            style: kOnboardingBodyMutedStyle,
          ),
          const SizedBox(height: 16),
        ],
        if (draft.connectedProvider == null && widget.onConnectTap != null) ...[
          OnboardingConnectNudgeCard(
            key: const ValueKey('plan_reveal.connect_nudge'),
            onConnectNow: widget.onConnectTap!,
            connectButtonKey: const ValueKey('plan_reveal.connect_now'),
          ),
          const SizedBox(height: 16),
        ],
        if (preview.longRun != null) ...[
          _TargetCard(
            label: 'LONG-RUN CARB TARGET',
            value: (edits.longRunCarbGph ?? preview.longRun!.carbGph).round(),
            unit: 'g/hr',
            insightLine: preview.longRun!.insightDescriptor != null
                ? 'Built around ${preview.longRun!.insightDescriptor}.'
                : null,
            editKey: const ValueKey('plan_reveal.edit_long_run'),
            onEdit: () => _editTarget(
              field: 'long_run_carb_gph',
              title: 'Long-run carb target',
              unit: 'g/hr',
              current: edits.longRunCarbGph ?? preview.longRun!.carbGph,
              min: NutritionTargetGuardrails.duringMinCarbRateGPerH,
              // Sport-specific ceiling — same constant the guardrails use
              // for run-context UI validation.
              max: NutritionTargetGuardrails.duringMaxCarbRateRunning,
              step: 5,
              apply: (value) => edits.copyWith(longRunCarbGph: () => value),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (preview.longRide != null) ...[
          _TargetCard(
            label: 'LONG-RIDE CARB TARGET',
            value: (edits.longRideCarbGph ?? preview.longRide!.carbGph).round(),
            unit: 'g/hr',
            insightLine: preview.longRide!.insightDescriptor != null
                ? 'Built around ${preview.longRide!.insightDescriptor}.'
                : null,
            editKey: const ValueKey('plan_reveal.edit_long_ride'),
            onEdit: () => _editTarget(
              field: 'long_ride_carb_gph',
              title: 'Long-ride carb target',
              unit: 'g/hr',
              current: edits.longRideCarbGph ?? preview.longRide!.carbGph,
              min: NutritionTargetGuardrails.duringMinCarbRateGPerH,
              max: NutritionTargetGuardrails.duringMaxCarbRateCycling,
              step: 5,
              apply: (value) => edits.copyWith(longRideCarbGph: () => value),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (preview.fluidMlPerHr != null && preview.sodiumMgPerHr != null) ...[
          const SizedBox(height: 8),
          const Text('FLUIDS & SODIUM', style: kOnboardingSectionLabelStyle),
          const SizedBox(height: 8),
          _TargetCard(
            label: 'FLUID',
            value: (edits.fluidMlPerHr ?? preview.fluidMlPerHr!.toDouble())
                .round(),
            unit: 'mL/hr',
            editKey: const ValueKey('plan_reveal.edit_fluid'),
            onEdit: () => _editTarget(
              field: 'fluid_ml_per_hr',
              title: 'Fluid target',
              unit: 'mL/hr',
              current: edits.fluidMlPerHr ?? preview.fluidMlPerHr!.toDouble(),
              min: NutritionTargetGuardrails.duringMinFluidRateMlPerH,
              max: NutritionTargetGuardrails.duringMaxFluidRateMlPerH,
              step: 50,
              apply: (value) => edits.copyWith(fluidMlPerHr: () => value),
            ),
          ),
          const SizedBox(height: 12),
          _TargetCard(
            label: 'SODIUM',
            value: (edits.sodiumMgPerHr ?? preview.sodiumMgPerHr!.toDouble())
                .round(),
            unit: 'mg/hr',
            editKey: const ValueKey('plan_reveal.edit_sodium'),
            onEdit: () => _editTarget(
              field: 'sodium_mg_per_hr',
              title: 'Sodium target',
              unit: 'mg/hr',
              current: edits.sodiumMgPerHr ?? preview.sodiumMgPerHr!.toDouble(),
              min: NutritionTargetGuardrails.duringMinSodiumRateMgPerH,
              max: NutritionTargetGuardrails.duringMaxSodiumRateMgPerH,
              step: 50,
              apply: (value) => edits.copyWith(sodiumMgPerHr: () => value),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _buildSweatTestTile(),
      ],
    );
  }

  Widget _buildSweatTestTile() {
    return InkWell(
      key: const ValueKey('plan_reveal.sweat_test_tile'),
      onTap: _onSweatTestTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: onboardingCardDecoration(),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const FaIcon(
              FontAwesomeIcons.droplet,
              size: 18,
              color: AppColors.orange,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Personalize with a sweat test',
                style: TextStyle(
                  fontFamily: 'Apercu',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textDark.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  void _onSweatTestTap() {
    _controller.recordSweatTestInterest();
    try {
      ref
          .read(appExternalDepsProvider)
          .analytics
          .track('sweat_test_link_tapped');
    } catch (_) {
      // Analytics must never block onboarding.
    }
    // Deliberately no deep link mid-onboarding — just point at Settings.
    MealvanaSnackbar.showInfo(
      context,
      'You can run a sweat test anytime in Settings → Sweat Profile',
    );
  }

  Future<void> _editTarget({
    required String field,
    required String title,
    required String unit,
    required double current,
    required double min,
    required double max,
    required double step,
    required OnboardingPlanEdits Function(double value) apply,
  }) async {
    final result = await showDialog<double>(
      context: context,
      builder: (_) => _TargetEditDialog(
        title: title,
        unit: unit,
        initial: current,
        min: min,
        max: max,
        step: step,
      ),
    );
    if (result == null || result == current) return;

    _controller.applyPlanEdits(apply(result));
    try {
      ref
          .read(appExternalDepsProvider)
          .analytics
          .track(
            'plan_target_edited',
            properties: {
              'field': field,
              'from': current.round(),
              'to': result.round(),
            },
          );
    } catch (_) {
      // Analytics must never block onboarding.
    }
    if (mounted) setState(() {});
  }
}

/// One editable target card: label, big value + unit, pencil affordance,
/// optional "Built around your…" insight line.
class _TargetCard extends StatelessWidget {
  const _TargetCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.editKey,
    required this.onEdit,
    this.insightLine,
  });

  final String label;
  final int value;
  final String unit;
  final Key editKey;
  final VoidCallback onEdit;
  final String? insightLine;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: onboardingCardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: kOnboardingSectionLabelStyle),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontFamily: 'Sansita',
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: AppColors.orange,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                unit,
                style: const TextStyle(
                  fontFamily: 'Apercu',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDarkSecondary,
                ),
              ),
              const Spacer(),
              IconButton(
                key: editKey,
                onPressed: onEdit,
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: AppColors.orange,
                ),
              ),
            ],
          ),
          if (insightLine != null) ...[
            const SizedBox(height: 4),
            Text(insightLine!, style: kOnboardingBodyMutedStyle),
          ],
        ],
      ),
    );
  }
}

/// Stepper dialog for adjusting one target. Values clamp to [min]..[max]
/// (the shared guardrail range for the field). Returns the new value on
/// Save, null on Cancel.
class _TargetEditDialog extends StatefulWidget {
  const _TargetEditDialog({
    required this.title,
    required this.unit,
    required this.initial,
    required this.min,
    required this.max,
    required this.step,
  });

  final String title;
  final String unit;
  final double initial;
  final double min;
  final double max;
  final double step;

  @override
  State<_TargetEditDialog> createState() => _TargetEditDialogState();
}

class _TargetEditDialogState extends State<_TargetEditDialog> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial.clamp(widget.min, widget.max);
  }

  void _adjust(double delta) {
    setState(() {
      _value = (_value + delta).clamp(widget.min, widget.max);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.blackberryLight,
      title: Text(
        widget.title,
        style: const TextStyle(
          fontFamily: 'Sansita',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            key: const ValueKey('plan_reveal.edit_minus'),
            onPressed: _value > widget.min ? () => _adjust(-widget.step) : null,
            icon: const Icon(Icons.remove_circle_outline),
            color: AppColors.orange,
            disabledColor: AppColors.disabled,
            iconSize: 32,
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_value.round()}',
                key: const ValueKey('plan_reveal.edit_value'),
                style: const TextStyle(
                  fontFamily: 'Sansita',
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.orange,
                ),
              ),
              Text(widget.unit, style: kOnboardingBodyMutedStyle),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            key: const ValueKey('plan_reveal.edit_plus'),
            onPressed: _value < widget.max ? () => _adjust(widget.step) : null,
            icon: const Icon(Icons.add_circle_outline),
            color: AppColors.orange,
            disabledColor: AppColors.disabled,
            iconSize: 32,
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('plan_reveal.edit_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textDarkSecondary),
          ),
        ),
        TextButton(
          key: const ValueKey('plan_reveal.edit_save'),
          onPressed: () => Navigator.of(context).pop(_value),
          child: const Text(
            'Save',
            style: TextStyle(
              color: AppColors.orange,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
