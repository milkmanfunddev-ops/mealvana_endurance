import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../nutrition_plan/domain/nutrition_target_overrides.dart';
import '../../domain/onboarding_draft.dart';
import '../../domain/onboarding_plan_preview.dart';
import '../providers/onboarding_controller.dart';
import '../providers/onboarding_preview_providers.dart';
import '../theme/onboarding_design_tokens.dart';
import '../widgets/onboarding_build_loader.dart';
import '../widgets/onboarding_step_scaffold.dart';

/// Plan Reveal Screen - Step 8 of Onboarding (2026-08 redesign)
///
/// The centerpiece: after a "Building your plan…" loader (≥1.5 s perceived
/// work; awaits the imported-workout digest — with its 10 s timeout — when a
/// platform was connected), reveals the computed fueling targets from
/// [onboardingPlanPreviewProvider] with per-target edit affordances. Edits go
/// through `applyPlanEdits` (only touched fields non-null). The carb-target
/// sliders clamp to their own editable range (30-120 g/hr run, 30-130 g/hr
/// ride); fluid/sodium clamp to the shared `NutritionTargetGuardrails`
/// constants the save path applies.
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
  /// Minimum loader time — long enough for the spec's four build lines to
  /// play at their 700ms cadence (the prototype's transition length).
  static const _minLoaderDuration = Duration(milliseconds: 2800);

  Timer? _minDelayTimer;
  bool _minDelayElapsed = false;
  bool _revealTracked = false;

  /// Slider bounds for the carb-target cards — deliberately not the shared
  /// `NutritionTargetGuardrails` during-workout constants (those also gate
  /// the unrelated activity-detail carb-rate editor); the onboarding
  /// reveal slider gets its own editable range.
  static const double _runCarbMin = 30;
  static const double _runCarbMax = 120;
  static const double _rideCarbMin = 30;
  static const double _rideCarbMax = 130;

  /// Which carb-target card has its slider open — spec `editingHero`
  /// ('run' | 'ride' | null). Single field so opening one closes the other.
  String? _editingHero;

  /// Which compact row has its slider open — spec `editingHydra`
  /// ('fluid' | 'sodium' | null).
  String? _editingHydra;

  void _toggleHero(String key) =>
      setState(() => _editingHero = _editingHero == key ? null : key);

  void _toggleHydra(String key) =>
      setState(() => _editingHydra = _editingHydra == key ? null : key);

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
    // Spec BUILDING state: full-bleed gradient, spinner ring, cycling teal
    // build lines, 220x5 progress bar — no header or footer chrome.
    return const Scaffold(
      backgroundColor: OnbTokens.bg,
      body: OnboardingBuildLoader(),
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
      eyebrow: 'YOUR FUELING PLAN',
      title: firstName != null && firstName.isNotEmpty
          ? 'We built your plan, $firstName.'
          : 'We built your plan.',
      // Spec: the reveal title is CREAM Sansita 27, not the step orange.
      titleStyle: const TextStyle(
        fontFamily: OnbTokens.fontDisplay,
        fontSize: 27,
        fontWeight: FontWeight.w700,
        height: 1.05,
        color: OnbTokens.cream,
      ),
      subtitle: 'Every number traces back to what you told us.',
      titleKey: const ValueKey('plan_reveal.title'),
      stepIndex: widget.stepIndex,
      // Spec: the reveal drops the progress segments (back circle only)
      // and labels its CTA with the destination.
      showProgress: false,
      continueLabel: 'Continue to See My Daily Plan',
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
            recommended: preview.longRun!.carbGph.round(),
            unit: 'g/hr',
            sliderUnitLabel: 'g',
            kind: 'run',
            insightLine: preview.longRun!.insightDescriptor != null
                ? 'Built around ${preview.longRun!.insightDescriptor}.'
                : null,
            editKey: const ValueKey('plan_reveal.edit_long_run'),
            sliderKey: const ValueKey('plan_reveal.slider_long_run'),
            resetKey: const ValueKey('plan_reveal.reset_long_run'),
            isEditing: _editingHero == 'run',
            onToggleEdit: () => _toggleHero('run'),
            min: _runCarbMin,
            max: _runCarbMax,
            step: 5,
            onCommit: (value) => _commitEdit(
              field: 'long_run_carb_gph',
              current: edits.longRunCarbGph ?? preview.longRun!.carbGph,
              value: value,
              min: _runCarbMin,
              max: _runCarbMax,
              apply: (v) => edits.copyWith(longRunCarbGph: () => v),
            ),
            onReset: () => _resetEdit(
              edits.copyWith(longRunCarbGph: () => null),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (preview.longRide != null) ...[
          _TargetCard(
            label: 'LONG-RIDE CARB TARGET',
            value: (edits.longRideCarbGph ?? preview.longRide!.carbGph).round(),
            recommended: preview.longRide!.carbGph.round(),
            unit: 'g/hr',
            sliderUnitLabel: 'g',
            kind: 'ride',
            insightLine: preview.longRide!.insightDescriptor != null
                ? 'Built around ${preview.longRide!.insightDescriptor}.'
                : null,
            editKey: const ValueKey('plan_reveal.edit_long_ride'),
            sliderKey: const ValueKey('plan_reveal.slider_long_ride'),
            resetKey: const ValueKey('plan_reveal.reset_long_ride'),
            isEditing: _editingHero == 'ride',
            onToggleEdit: () => _toggleHero('ride'),
            min: _rideCarbMin,
            max: _rideCarbMax,
            step: 5,
            onCommit: (value) => _commitEdit(
              field: 'long_ride_carb_gph',
              current: edits.longRideCarbGph ?? preview.longRide!.carbGph,
              value: value,
              min: _rideCarbMin,
              max: _rideCarbMax,
              apply: (v) => edits.copyWith(longRideCarbGph: () => v),
            ),
            onReset: () => _resetEdit(
              edits.copyWith(longRideCarbGph: () => null),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (preview.fluidMlPerHr != null && preview.sodiumMgPerHr != null) ...[
          const SizedBox(height: 12),
          // Spec: sentence-case Sansita 700 16 cream section header.
          const Text(
            'Fluids & Sodium',
            style: TextStyle(
              fontFamily: OnbTokens.fontDisplay,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: OnbTokens.cream,
            ),
          ),
          const SizedBox(height: 10),
          _CompactTargetRow(
            label: 'FLUID',
            value: (edits.fluidMlPerHr ?? preview.fluidMlPerHr!.toDouble())
                .round(),
            unit: 'ml/hr',
            sliderUnitLabel: 'ml',
            editKey: const ValueKey('plan_reveal.edit_fluid'),
            sliderKey: const ValueKey('plan_reveal.slider_fluid'),
            isEditing: _editingHydra == 'fluid',
            onToggleEdit: () => _toggleHydra('fluid'),
            min: NutritionTargetGuardrails.duringMinFluidRateMlPerH,
            max: NutritionTargetGuardrails.duringMaxFluidRateMlPerH,
            step: 50,
            onCommit: (value) => _commitEdit(
              field: 'fluid_ml_per_hr',
              current: edits.fluidMlPerHr ?? preview.fluidMlPerHr!.toDouble(),
              value: value,
              min: NutritionTargetGuardrails.duringMinFluidRateMlPerH,
              max: NutritionTargetGuardrails.duringMaxFluidRateMlPerH,
              apply: (v) => edits.copyWith(fluidMlPerHr: () => v),
            ),
          ),
          const SizedBox(height: 10),
          _CompactTargetRow(
            label: 'SODIUM',
            value: (edits.sodiumMgPerHr ?? preview.sodiumMgPerHr!.toDouble())
                .round(),
            unit: 'mg/hr',
            sliderUnitLabel: 'mg',
            editKey: const ValueKey('plan_reveal.edit_sodium'),
            sliderKey: const ValueKey('plan_reveal.slider_sodium'),
            isEditing: _editingHydra == 'sodium',
            onToggleEdit: () => _toggleHydra('sodium'),
            min: NutritionTargetGuardrails.duringMinSodiumRateMgPerH,
            max: NutritionTargetGuardrails.duringMaxSodiumRateMgPerH,
            step: 50,
            onCommit: (value) => _commitEdit(
              field: 'sodium_mg_per_hr',
              current: edits.sodiumMgPerHr ?? preview.sodiumMgPerHr!.toDouble(),
              value: value,
              min: NutritionTargetGuardrails.duringMinSodiumRateMgPerH,
              max: NutritionTargetGuardrails.duringMaxSodiumRateMgPerH,
              apply: (v) => edits.copyWith(sodiumMgPerHr: () => v),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _buildSweatTestTile(),
      ],
    );
  }

  Widget _buildSweatTestTile() {
    // Spec tile: 1px dashed cream-25%, radius 15, transparent fill,
    // padding 14; centered flask + Apercu 13 cream label.
    return InkWell(
      key: const ValueKey('plan_reveal.sweat_test_tile'),
      onTap: _onSweatTestTap,
      borderRadius: BorderRadius.circular(OnbTokens.rCard),
      child: CustomPaint(
        painter: OnboardingDashedBorderPainter(
          color: OnbTokens.creamA(0.25),
          radius: OnbTokens.rCard,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const FaIcon(
                FontAwesomeIcons.flaskVial,
                size: 14,
                color: OnbTokens.orange,
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Personalize with a sweat test',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: OnbTokens.fontBody,
                    fontSize: 13,
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

  /// Commits a slider's released value to the draft (clamped, no-op if
  /// unchanged) and fires the edit analytics event. `current` is the
  /// pre-edit value (possibly already-edited) used for the `from` property.
  void _commitEdit({
    required String field,
    required double current,
    required double value,
    required double min,
    required double max,
    required OnboardingPlanEdits Function(double value) apply,
  }) {
    final clamped = value.clamp(min, max);
    if (clamped == current) return;

    _controller.applyPlanEdits(apply(clamped));
    try {
      ref
          .read(appExternalDepsProvider)
          .analytics
          .track(
            'plan_target_edited',
            properties: {
              'field': field,
              'from': current.round(),
              'to': clamped.round(),
            },
          );
    } catch (_) {
      // Analytics must never block onboarding.
    }
  }

  /// "Reset to our recommendation" — clears the touched field back to null
  /// so the algorithm default takes over again.
  void _resetEdit(OnboardingPlanEdits cleared) {
    _controller.applyPlanEdits(cleared);
  }
}

/// One editable target card: label, big value + unit, pencil affordance,
/// optional "Built around your…" insight line — spec's inline bounded
/// slider expand (not a dialog): tapping the pencil opens a slider bounded
/// to [min]..[max] under the caption; the big number and caption only
/// update once the slider is released (spec binds them to the app's
/// on-change/committed state, not the drag position), matching
/// `editingHero`/`onEditRun`/`onRunSlide`/`runMsg`/`onRunReset`.
class _TargetCard extends StatefulWidget {
  const _TargetCard({
    required this.label,
    required this.value,
    required this.recommended,
    required this.unit,
    required this.sliderUnitLabel,
    required this.kind,
    required this.editKey,
    required this.sliderKey,
    required this.resetKey,
    required this.isEditing,
    required this.onToggleEdit,
    required this.min,
    required this.max,
    required this.step,
    required this.onCommit,
    required this.onReset,
    this.insightLine,
  });

  final String label;
  final int value;

  /// The algorithm's unedited recommendation (rounded) — the slider's
  /// "home" value and the deviation-message baseline.
  final int recommended;
  final String unit;

  /// Bare unit for the slider's min/max endpoint labels (e.g. 'g', no
  /// '/hr' suffix — spec: "30 g" / "120 g").
  final String sliderUnitLabel;

  /// 'run' or 'ride' — feeds the deviation message's "...long {kind}s".
  final String kind;
  final Key editKey;
  final Key sliderKey;
  final Key resetKey;
  final bool isEditing;
  final VoidCallback onToggleEdit;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onCommit;
  final VoidCallback onReset;
  final String? insightLine;

  @override
  State<_TargetCard> createState() => _TargetCardState();
}

class _TargetCardState extends State<_TargetCard> {
  late double _dragValue = widget.value.toDouble();

  @override
  void didUpdateWidget(covariant _TargetCard old) {
    super.didUpdateWidget(old);
    // Re-sync the thumb to the committed value whenever it changes
    // externally (a fresh commit, or a reset) — never mid-drag.
    if (old.value != widget.value) {
      _dragValue = widget.value.toDouble();
    }
  }

  /// Spec `carbMsg`: at the recommendation, prefer a training insight line
  /// when one is available; off it, describe how aggressive/conservative
  /// the edit is rather than repeating the (no-longer-applicable) rationale
  /// for the original recommendation.
  String get _message {
    final delta = widget.value - widget.recommended;
    if (delta == 0) {
      return widget.insightLine ??
          'Our recommendation for you: ACSM guidance at your body weight, '
              'scaled to your gut-training level.';
    }
    if (delta <= -20) {
      return 'Well under your ${widget.recommended} g/hr recommendation — '
          'expect to fade in the back half of long ${widget.kind}s.';
    }
    if (delta < 0) {
      return 'A little conservative. Reasonable if your gut is still '
          'adapting, but leaves headroom.';
    }
    if (delta <= 20) {
      return 'Above your recommendation. Achievable, but practise this '
          'rate in training before race day.';
    }
    return 'Aggressive fueling. Needs multiple carb sources and weeks of '
        'gut training to absorb.';
  }

  @override
  Widget build(BuildContext context) {
    // Spec carb-target card: linear-gradient(150deg, #4a2143, #3a1835),
    // 1px orange-40% border, radius 20, padding 18/20; Apercu 500 11
    // ls 1.1 uppercase cream-60% label; Sansita 700 40 orange number with
    // Apercu 16 cream unit; Apercu 13 cream-72% caption; 30px cream-10%
    // pencil circle.
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [OnbTokens.cardRaised, OnbTokens.cardSubtle],
        ),
        borderRadius: BorderRadius.circular(OnbTokens.rLarge),
        border: Border.all(color: OnbTokens.orange40),
      ),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: OnbTokens.fontBody,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.1,
                    color: OnbTokens.creamA(0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${widget.value}',
                        style: const TextStyle(
                          fontFamily: OnbTokens.fontDisplay,
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                          color: OnbTokens.orange,
                        ),
                      ),
                      TextSpan(
                        text: ' ${widget.unit}',
                        style: const TextStyle(
                          fontFamily: OnbTokens.fontBody,
                          fontSize: 16,
                          color: OnbTokens.cream,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.isEditing) ...[
                  const SizedBox(height: 14),
                  _SpecSlider(
                    sliderKey: widget.sliderKey,
                    value: _dragValue,
                    min: widget.min,
                    max: widget.max,
                    onChanged: (v) => setState(() => _dragValue = v),
                    onChangeEnd: (v) => widget.onCommit(
                      (v / widget.step).round() * widget.step,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SliderEndpointLabel(
                        '${widget.min.round()} ${widget.sliderUnitLabel}',
                      ),
                      _SliderEndpointLabel(
                        '${widget.max.round()} ${widget.sliderUnitLabel}',
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  _message,
                  style: TextStyle(
                    fontFamily: OnbTokens.fontBody,
                    fontSize: 13,
                    height: 1.45,
                    color: OnbTokens.creamA(0.72),
                  ),
                ),
                if (widget.value != widget.recommended) ...[
                  const SizedBox(height: 12),
                  _ResetToRecommendationLink(
                    resetKey: widget.resetKey,
                    label:
                        'Reset to our recommendation · '
                        '${widget.recommended} ${widget.unit}',
                    onTap: widget.onReset,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          _PencilButton(editKey: widget.editKey, onEdit: widget.onToggleEdit),
        ],
      ),
    );
  }
}

/// Compact fluid/sodium row — spec: cream-5% fill, radius 15, cream-12%
/// border, padding 16/18; Apercu 10 ls .6 uppercase cream-50% label left;
/// Apercu Mono 27 cream value + mono 13 cream-50% unit right; pencil circle.
/// Same inline-slider-on-pencil-tap pattern as [_TargetCard], but per spec
/// carries no deviation message or reset link — just the bounded slider.
class _CompactTargetRow extends StatefulWidget {
  const _CompactTargetRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.sliderUnitLabel,
    required this.editKey,
    required this.sliderKey,
    required this.isEditing,
    required this.onToggleEdit,
    required this.min,
    required this.max,
    required this.step,
    required this.onCommit,
  });

  final String label;
  final int value;
  final String unit;
  final String sliderUnitLabel;
  final Key editKey;
  final Key sliderKey;
  final bool isEditing;
  final VoidCallback onToggleEdit;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onCommit;

  @override
  State<_CompactTargetRow> createState() => _CompactTargetRowState();
}

class _CompactTargetRowState extends State<_CompactTargetRow> {
  late double _dragValue = widget.value.toDouble();

  @override
  void didUpdateWidget(covariant _CompactTargetRow old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _dragValue = widget.value.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OnbTokens.creamA(0.05),
        borderRadius: BorderRadius.circular(OnbTokens.rCard),
        border: Border.all(color: OnbTokens.creamA(0.12)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: OnbTokens.fontBody,
                  fontSize: 10,
                  letterSpacing: 0.6,
                  color: OnbTokens.creamA(0.5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${widget.value}',
                            style: const TextStyle(
                              fontFamily: OnbTokens.fontMono,
                              fontSize: 27,
                              height: 1.0,
                              color: OnbTokens.cream,
                            ),
                          ),
                          TextSpan(
                            text: ' ${widget.unit}',
                            style: TextStyle(
                              fontFamily: OnbTokens.fontMono,
                              fontSize: 13,
                              color: OnbTokens.creamA(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _PencilButton(
                editKey: widget.editKey,
                onEdit: widget.onToggleEdit,
              ),
            ],
          ),
          if (widget.isEditing) ...[
            const SizedBox(height: 14),
            _SpecSlider(
              sliderKey: widget.sliderKey,
              value: _dragValue,
              min: widget.min,
              max: widget.max,
              onChanged: (v) => setState(() => _dragValue = v),
              onChangeEnd: (v) => widget.onCommit(
                (v / widget.step).round() * widget.step,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SliderEndpointLabel(
                  '${widget.min.round()} ${widget.sliderUnitLabel}',
                ),
                _SliderEndpointLabel(
                  '${widget.max.round()} ${widget.sliderUnitLabel}',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Spec pencil affordance: 30px cream-10% circle with a small edit glyph.
class _PencilButton extends StatelessWidget {
  const _PencilButton({required this.editKey, required this.onEdit});

  final Key editKey;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: editKey,
      customBorder: const CircleBorder(),
      onTap: onEdit,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: OnbTokens.creamA(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.edit_outlined,
          size: 14,
          color: OnbTokens.creamA(0.85),
        ),
      ),
    );
  }
}

/// Spec `.me-range`: flat 4px cream-18% track (no active-fill highlight),
/// bounded [min]..[max]. The thumb moves continuously while dragging (a
/// native mobile-slider expectation); the caller only applies the value on
/// release via [onChangeEnd] — matching the spec's on-change (not on-input)
/// commit and avoiding a preview recompute per drag pixel.
class _SpecSlider extends StatelessWidget {
  const _SpecSlider({
    required this.sliderKey,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final Key sliderKey;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: OnbTokens.creamA(0.18),
        inactiveTrackColor: OnbTokens.creamA(0.18),
        thumbShape: const _SpecThumbShape(),
        overlayShape: SliderComponentShape.noOverlay,
      ),
      child: Slider(
        key: sliderKey,
        value: value.clamp(min, max),
        min: min,
        max: max,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}

/// Spec thumb: 22px orange circle with a 3px plum (#3a1835) border, drawn
/// as two concentric filled circles (simpler and just as exact as a
/// stroke — the border color is opaque, so an inner-orange/outer-border
/// disc pair reads identically).
class _SpecThumbShape extends SliderComponentShape {
  const _SpecThumbShape();

  static const double _outerRadius = 11;
  static const double _innerRadius = 8;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(_outerRadius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(
      center,
      _outerRadius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.drawCircle(center, _outerRadius, Paint()..color = OnbTokens.cardSubtle);
    canvas.drawCircle(center, _innerRadius, Paint()..color = OnbTokens.orange);
  }
}

/// Slider min/max endpoint caption — spec: Apercu 10.5 cream-35%.
class _SliderEndpointLabel extends StatelessWidget {
  const _SliderEndpointLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: OnbTokens.fontBody,
        fontSize: 10.5,
        color: OnbTokens.creamA(0.35),
      ),
    );
  }
}

/// "Reset to our recommendation · X" — spec: teal refresh glyph (13px) +
/// Apercu 500 12.5 teal label, shown only when the value differs from the
/// recommendation.
class _ResetToRecommendationLink extends StatelessWidget {
  const _ResetToRecommendationLink({
    required this.resetKey,
    required this.label,
    required this.onTap,
  });

  final Key resetKey;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: resetKey,
      onTap: onTap,
      child: Row(
        children: [
          const Icon(Icons.refresh, size: 13, color: OnbTokens.teal),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: OnbTokens.fontBody,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: OnbTokens.teal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
