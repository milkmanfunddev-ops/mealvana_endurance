import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mealvana_endurance/shared/utils/unit_formatter.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../integrations/presentation/widgets/garmin_attribution_message.dart';
import '../providers/onboarding_controller.dart';
import '../providers/onboarding_preview_providers.dart';
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
    return Row(
      children: [
        Expanded(
          child: _UnitSegment(
            segmentKey: const ValueKey('body_comp.units_imperial_button'),
            label: 'Imperial',
            isSelected: !_useMetric,
            onTap: () => _setUnitSystem(false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _UnitSegment(
            segmentKey: const ValueKey('body_comp.units_metric_button'),
            label: 'Metric',
            isSelected: _useMetric,
            onTap: () => _setUnitSystem(true),
          ),
        ),
      ],
    );
  }

  Widget _buildHeightCard() {
    return Container(
      decoration: onboardingCardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('HEIGHT', style: kOnboardingSectionLabelStyle),
          const SizedBox(height: 8),
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
    );
  }

  Widget _buildWeightCard() {
    return Container(
      decoration: onboardingCardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('WEIGHT', style: kOnboardingSectionLabelStyle),
          if (_weightFromGarmin) ...[
            const SizedBox(height: 8),
            const Center(
              key: ValueKey('body_comp.garmin_badge'),
              child: GarminAttributionMessage(subject: 'Weight', compact: true),
            ),
          ],
          const SizedBox(height: 8),
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
      ),
    );
  }
}

/// One segment of the Imperial/Metric toggle (dark-scaffold styling;
/// KyleSegmentedControl is theme-driven and would render blackberry-on-
/// blackberry here).
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cream : Colors.transparent,
          border: Border.all(color: AppColors.cream, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Apercu',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isSelected
                  ? AppColors.blackberry
                  : AppColors.cream.withValues(alpha: 0.7),
            ),
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

  @override
  void initState() {
    super.initState();
    final clamped = widget.value.clamp(widget.min, widget.max);
    _scrollController = FixedExtentScrollController(
      initialItem: clamped - widget.min,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 120,
            child: CupertinoPicker(
              key: widget.wheelKey,
              scrollController: _scrollController,
              itemExtent: 36,
              useMagnifier: true,
              magnification: 1.1,
              squeeze: 1.0,
              selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                background: AppColors.orange.withValues(alpha: 0.1),
              ),
              onSelectedItemChanged: (index) =>
                  widget.onChanged(widget.min + index),
              children: [
                for (var v = widget.min; v <= widget.max; v++)
                  Center(
                    child: Text(
                      '$v',
                      style: const TextStyle(
                        fontFamily: 'Apercu',
                        fontSize: 20,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          widget.unit,
          style: const TextStyle(
            fontFamily: 'Apercu',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textDarkSecondary,
          ),
        ),
      ],
    );
  }
}
