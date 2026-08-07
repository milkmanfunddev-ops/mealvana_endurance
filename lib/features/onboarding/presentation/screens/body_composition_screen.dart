import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mealvana_endurance/shared/utils/unit_formatter.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../integrations/presentation/widgets/garmin_attribution_message.dart';
import '../providers/onboarding_controller.dart';
import '../providers/onboarding_preview_providers.dart';
import '../theme/onboarding_design_tokens.dart';
import '../widgets/onboarding_spec_wheel.dart';
import '../widgets/onboarding_step_scaffold.dart';

/// Body Composition Screen - Step 6 of Onboarding (2026-08 redesign)
///
/// Imperial/Metric toggle plus height and weight wheels. Canonical values
/// are stored imperial (feet/inches + pounds) exactly like the draft and
/// UserProfile; the metric wheels are display conversions. Wheels default to
/// 5 ft 8 in / 150 lb so Continue is always enabled — the defaults are
/// pushed into the draft on entry.
///
/// Weight autofill (lifted from the old user_profile_screen): when an
/// integration connected during onboarding reports a weight — Garmin scale
/// data preferred over TP/FS profile weight — and the user hasn't set one,
/// the weight wheel pre-fills from it with a Garmin attribution line.
class BodyCompositionScreen extends ConsumerStatefulWidget {
  const BodyCompositionScreen({
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
  ConsumerState<BodyCompositionScreen> createState() =>
      _BodyCompositionScreenState();
}

class _BodyCompositionScreenState extends ConsumerState<BodyCompositionScreen> {
  /// Sensible wheel defaults so the step never blocks.
  static const int _defaultHeightFeet = 5;
  static const int _defaultHeightInches = 8;
  static const double _defaultWeightPounds = 150;

  // Canonical (imperial) state, mirrored into the draft on every change.
  late bool _useMetric;
  late int _heightFeet;
  late int _heightInches;
  late double _weightPounds;

  /// Once the user touches the weight wheel, integration autofill backs off.
  bool _userAdjustedWeight = false;
  bool _weightFromGarmin = false;

  /// Bumped on *external* value changes (unit toggle, integration autofill)
  /// to rebuild the wheels at their new positions via value-bearing keys.
  /// Deliberately NOT bumped on user scrolls — recreating a wheel mid-drag
  /// would kill the gesture.
  int _wheelEpoch = 0;

  OnboardingController get _controller =>
      ref.read(onboardingControllerProvider.notifier);

  int get _totalInches => (_heightFeet * 12) + _heightInches;
  int get _heightCm => UnitFormatter.totalInchesToCm(_totalInches);
  int get _weightKg => UnitFormatter.poundsToKg(_weightPounds).round();

  @override
  void initState() {
    super.initState();

    // Seeded from the draft so revisiting the step restores prior answers.
    final draft = _controller.draft;
    _useMetric = draft.useMetricUnits;
    _heightFeet = draft.heightFeet ?? _defaultHeightFeet;
    _heightInches = draft.heightInches ?? _defaultHeightInches;
    _weightPounds = draft.weightPounds ?? _defaultWeightPounds;
    _userAdjustedWeight = draft.weightPounds != null;

    // Push the (possibly default) values into the draft so Continue always
    // yields a complete body composition. Post-frame: draft mutation
    // notifies provider listeners, which is illegal during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pushToDraft();
    });

    // Integration weight autofill — fireImmediately so an already-resolved
    // (keepAlive) provider value still lands.
    ref.listenManual(onboardingIntegrationWeightLbsProvider, (previous, next) {
      final lbs = next.value;
      if (lbs == null || _userAdjustedWeight || !mounted) return;
      setState(() {
        _weightPounds = lbs;
        _weightFromGarmin = true;
        _wheelEpoch++;
      });
      _pushToDraft();
    }, fireImmediately: true);

    ref
        .read(appExternalDepsProvider)
        .analytics
        .track(
          'screen_viewed',
          properties: {
            'screen_name': 'Body Composition Onboarding',
            if (widget.stepIndex != null) 'step_index': widget.stepIndex,
          },
        );
  }

  void _pushToDraft() {
    _controller.updateBodyComposition(
      useMetricUnits: _useMetric,
      heightFeet: _heightFeet,
      heightInches: _heightInches,
      weightPounds: _weightPounds,
    );
  }

  void _setUnitSystem(bool useMetric) {
    if (useMetric == _useMetric) return;
    setState(() {
      _useMetric = useMetric;
      _wheelEpoch++;
    });
    _controller.updateBodyComposition(useMetricUnits: useMetric);
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      title: 'Basic body composition',
      subtitle:
          'We use the Mifflin-St Jeor model to estimate your resting '
          'metabolic rate.',
      titleKey: const ValueKey('body_comp.title'),
      stepIndex: widget.stepIndex,
      onContinue: widget.onContinue,
      onBack: widget.onBack,
      continueButtonKey: const ValueKey('body_comp.continue_button'),
      backButtonKey: const ValueKey('body_comp.back_button'),
      // Spec: this step's CTA reads 'Build My Plan' (the nutrition-settings
      // step that follows keeps plain 'Continue').
      continueLabel: 'Build My Plan',
      children: [
        _buildUnitToggle(),
        const SizedBox(height: 20),
        _buildHeightCard(),
        const SizedBox(height: 20),
        _buildWeightCard(),
      ],
    );
  }

  Widget _buildUnitToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Unit preferences', style: _specFieldLabelStyle),
        const SizedBox(height: 8),
        // Spec toggle: cream-6% pill track, padding 4, h40, content-hugging;
        // selected segment is an orange pill with plum 13/500 text.
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: OnbTokens.creamA(0.06),
            borderRadius: BorderRadius.circular(OnbTokens.rPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _UnitSegment(
                segmentKey: const ValueKey('body_comp.units_imperial_button'),
                label: 'Imperial',
                isSelected: !_useMetric,
                onTap: () => _setUnitSystem(false),
              ),
              _UnitSegment(
                segmentKey: const ValueKey('body_comp.units_metric_button'),
                label: 'Metric',
                isSelected: _useMetric,
                onTap: () => _setUnitSystem(true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeightCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Height', style: _specFieldLabelStyle),
        const SizedBox(height: 4),
        Column(
          children: [
            if (_useMetric)
              _WheelPicker(
                // Key includes the wheel epoch so external changes (unit
                // toggle, autofill) rebuild the wheel at the right position.
                key: ValueKey('body_comp.height_cm_wheel.e$_wheelEpoch'),
                wheelKey: const ValueKey('body_comp.height_cm_wheel'),
                // 91–244 cm ≈ the 3–8 ft imperial range.
                min: 91,
                max: 244,
                value: _heightCm,
                unit: 'cm',
                onChanged: (cm) {
                  final (feet, inches) = UnitFormatter.cmToFeetInches(cm);
                  setState(() {
                    _heightFeet = feet;
                    _heightInches = inches;
                  });
                  _pushToDraft();
                },
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _WheelPicker(
                      key: ValueKey('body_comp.height_ft_wheel.e$_wheelEpoch'),
                      wheelKey: const ValueKey('body_comp.height_ft_wheel'),
                      min: 3,
                      max: 8,
                      value: _heightFeet,
                      unit: 'ft',
                      onChanged: (feet) {
                        setState(() => _heightFeet = feet);
                        _pushToDraft();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _WheelPicker(
                      key: ValueKey('body_comp.height_in_wheel.e$_wheelEpoch'),
                      wheelKey: const ValueKey('body_comp.height_in_wheel'),
                      min: 0,
                      max: 11,
                      value: _heightInches,
                      unit: 'in',
                      onChanged: (inches) {
                        setState(() => _heightInches = inches);
                        _pushToDraft();
                      },
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeightCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Weight', style: _specFieldLabelStyle),
        if (_weightFromGarmin) ...[
          const SizedBox(height: 8),
          const Center(
            key: ValueKey('body_comp.garmin_badge'),
            child: GarminAttributionMessage(subject: 'Weight', compact: true),
          ),
        ],
        const SizedBox(height: 4),
        if (_useMetric)
          _WheelPicker(
            key: ValueKey('body_comp.weight_kg_wheel.e$_wheelEpoch'),
            wheelKey: const ValueKey('body_comp.weight_wheel'),
            // 36–181 kg ≈ the 80–400 lb imperial range.
            min: 36,
            max: 181,
            value: _weightKg,
            unit: 'kg',
            onChanged: (kg) {
              setState(() {
                _weightPounds = UnitFormatter.kgToPounds(kg.toDouble());
                _userAdjustedWeight = true;
                _weightFromGarmin = false;
              });
              _pushToDraft();
            },
          )
        else
          _WheelPicker(
            key: ValueKey('body_comp.weight_lb_wheel.e$_wheelEpoch'),
            wheelKey: const ValueKey('body_comp.weight_wheel'),
            min: 80,
            max: 400,
            value: _weightPounds.round(),
            unit: 'lb',
            onChanged: (lb) {
              setState(() {
                _weightPounds = lb.toDouble();
                _userAdjustedWeight = true;
                _weightFromGarmin = false;
              });
              _pushToDraft();
            },
          ),
      ],
    );
  }
}

/// Spec field label (Apercu 13/500 cream) shared by the three sections.
const _specFieldLabelStyle = TextStyle(
  fontFamily: OnbTokens.fontBody,
  fontSize: 13,
  fontWeight: FontWeight.w500,
  color: OnbTokens.cream,
);

/// One segment of the Imperial/Metric toggle — spec: selected is an orange
/// pill with plum 13/500 text; unselected is transparent cream-70% text.
class _UnitSegment extends StatelessWidget {
  const _UnitSegment({
    required this.segmentKey,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final Key segmentKey;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: segmentKey,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 22),
        decoration: BoxDecoration(
          color: isSelected ? OnbTokens.orange : Colors.transparent,
          borderRadius: BorderRadius.circular(OnbTokens.rPill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: OnbTokens.fontBody,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? OnbTokens.bg : OnbTokens.creamA(0.7),
          ),
        ),
      ),
    );
  }
}

/// Integer wheel with a trailing unit label. Owns its scroll controller
/// (created from the initial value, disposed with the widget); external
/// value changes rebuild it via the owner's value-bearing [Key].
class _WheelPicker extends StatefulWidget {
  const _WheelPicker({
    super.key,
    required this.wheelKey,
    required this.min,
    required this.max,
    required this.value,
    required this.unit,
    required this.onChanged,
  });

  /// Stable key for Patrol/widget tests (the widget's own [key] varies with
  /// the value to force rebuilds).
  final Key wheelKey;

  final int min;
  final int max;
  final int value;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  State<_WheelPicker> createState() => _WheelPickerState();
}

class _WheelPickerState extends State<_WheelPicker> {
  late final FixedExtentScrollController _scrollController;
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.value.clamp(widget.min, widget.max);
    _scrollController = FixedExtentScrollController(
      initialItem: _selected - widget.min,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Spec wheel (body-composition sizes 25/20): the unit rides inside the
    // SELECTED row's label ('5 ft'); neighbors show the bare number.
    return KeyedSubtree(
      key: widget.wheelKey,
      child: OnboardingSpecWheel(
        controller: _scrollController,
        itemCount: widget.max - widget.min + 1,
        selectedIndex: _selected - widget.min,
        centerFontSize: 25,
        adjacentFontSize: 20,
        labelFor: (index) {
          final v = widget.min + index;
          return v == _selected ? '$v ${widget.unit}' : '$v';
        },
        onChanged: (index) {
          setState(() => _selected = widget.min + index);
          widget.onChanged(widget.min + index);
        },
      ),
    );
  }
}
