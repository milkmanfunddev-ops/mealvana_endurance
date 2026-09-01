import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/services/app_external_deps.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../domain/onboarding_plan_preview.dart';
import '../providers/onboarding_controller.dart';
import '../providers/onboarding_preview_providers.dart';
import '../theme/onboarding_design_tokens.dart';
import '../widgets/onboarding_step_scaffold.dart';

/// Daily Plan Preview Screen - Step 9 (final) of Onboarding (2026-08
/// redesign)
///
/// Three sample days (Workout / Rest / Carb load) from the same
/// [onboardingPlanPreviewProvider] bundle the plan reveal rendered, so both
/// screens show consistent numbers. Continue is "Save My Plan" — the
/// pageview's last-page branch routes it to /auth/post-onboarding.
///
/// Pixel port of the prototype's DAILY screen: teal-eyebrow header without
/// progress segments, teal-pill day tabs on a cream-6% track, a Compadre
/// teal day caption, the Garmin nudge, then the "Your Macros" card with
/// dot-labelled rows and Apercu Mono values.
class DailyPlanPreviewScreen extends ConsumerStatefulWidget {
  const DailyPlanPreviewScreen({
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
  ConsumerState<DailyPlanPreviewScreen> createState() =>
      _DailyPlanPreviewScreenState();
}

class _DailyPlanPreviewScreenState
    extends ConsumerState<DailyPlanPreviewScreen> {
  PreviewDayType _tab = PreviewDayType.workout;

  @override
  void initState() {
    super.initState();

    ref
        .read(appExternalDepsProvider)
        .analytics
        .track(
          'screen_viewed',
          properties: {
            'screen_name': 'Daily Plan Preview Onboarding',
            if (widget.stepIndex != null) 'step_index': widget.stepIndex,
          },
        );
    _trackTabViewed(_tab);
  }

  static String _tabName(PreviewDayType tab) {
    switch (tab) {
      case PreviewDayType.workout:
        return 'workout';
      case PreviewDayType.rest:
        return 'rest';
      case PreviewDayType.carbLoad:
        return 'carb_load';
    }
  }

  static String _tabLabel(PreviewDayType tab) {
    switch (tab) {
      case PreviewDayType.workout:
        return 'Workout day';
      case PreviewDayType.rest:
        return 'Rest day';
      case PreviewDayType.carbLoad:
        return 'Carb load';
    }
  }

  void _trackTabViewed(PreviewDayType tab) {
    try {
      ref
          .read(appExternalDepsProvider)
          .analytics
          .track(
            'daily_preview_tab_viewed',
            properties: {'tab': _tabName(tab)},
          );
    } catch (_) {
      // Analytics must never block onboarding.
    }
  }

  void _selectTab(PreviewDayType tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    _trackTabViewed(tab);
  }

  String _dayDescription(OnboardingPlanPreview preview) {
    switch (_tab) {
      case PreviewDayType.workout:
        final descriptor =
            preview.longRun?.insightDescriptor ??
            preview.longRide?.insightDescriptor;
        return descriptor != null
            ? 'Built around $descriptor.'
            : 'Built around a long training session.';
      case PreviewDayType.rest:
        // Spec copy names the long run; keep it when the athlete has a run
        // card, generalize otherwise.
        return preview.longRun != null
            ? 'Minimal movement — the day after your long run.'
            : 'Minimal movement — the day after a long session.';
      case PreviewDayType.carbLoad:
        return 'The day before your race — topping up glycogen.';
    }
  }

  /// Small day tag on the Calories row ("workout day" / "rest day" /
  /// "carb-load day").
  String get _calorieTag {
    switch (_tab) {
      case PreviewDayType.workout:
        return 'workout day';
      case PreviewDayType.rest:
        return 'rest day';
      case PreviewDayType.carbLoad:
        return 'carb-load day';
    }
  }

  DayPreview _dayPreview(OnboardingPlanPreview preview) {
    switch (_tab) {
      case PreviewDayType.workout:
        return preview.workoutDay;
      case PreviewDayType.rest:
        return preview.restDay;
      case PreviewDayType.carbLoad:
        return preview.carbLoadDay;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild on draft changes (connect state can change via the nudge).
    ref.watch(onboardingControllerProvider);
    final draft = ref.read(onboardingControllerProvider.notifier).draft;
    final bundle = ref.watch(onboardingPlanPreviewProvider).value;

    return OnboardingStepScaffold(
      eyebrow: 'YOUR DAILY PLAN',
      title: "And here's how to eat every day.",
      // Spec: cream Sansita 27 like the reveal, not the step orange.
      titleStyle: const TextStyle(
        fontFamily: OnbTokens.fontDisplay,
        fontSize: 27,
        fontWeight: FontWeight.w700,
        height: 1.05,
        color: OnbTokens.cream,
      ),
      subtitle:
          'Targets shift with your training — carbs rise on workout days. '
          'Here are three sample days.',
      titleKey: const ValueKey('daily_preview.title'),
      stepIndex: widget.stepIndex,
      showProgress: false,
      onContinue: widget.onContinue,
      onBack: widget.onBack,
      canContinue: bundle != null,
      continueLabel: 'Save My Plan',
      continueButtonKey: const ValueKey('daily_preview.save_button'),
      backButtonKey: const ValueKey('daily_preview.back_button'),
      children: [
        if (bundle == null)
          // The shared bundle is computed by the plan-reveal step, so this
          // is a rarely-seen instant of first-frame loading.
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: AppColors.orange),
            ),
          )
        else ...[
          _buildTabs(),
          const SizedBox(height: 12),
          // Spec: 7px teal dot + 8px gap ahead of the Compadre caption.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: OnbTokens.teal,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _dayDescription(bundle.preview).toUpperCase(),
                  key: const ValueKey('daily_preview.day_description'),
                  style: const TextStyle(
                    fontFamily: OnbTokens.fontLabel,
                    fontSize: 14,
                    color: OnbTokens.teal,
                  ),
                ),
              ),
            ],
          ),
          if (draft.connectedProvider == null &&
              widget.onConnectTap != null) ...[
            const SizedBox(height: 24),
            OnboardingConnectNudgeCard(
              key: const ValueKey('daily_preview.connect_nudge'),
              onConnectNow: widget.onConnectTap!,
              connectButtonKey: const ValueKey('daily_preview.connect_now'),
              title: 'Connect with Garmin',
              body:
                  'When you finish an activity, your daily plan will be '
                  'adjusted to it.',
              iconBoxSize: 40,
              iconBoxRadius: 12,
            ),
          ],
          const SizedBox(height: 26),
          const Text(
            'Your Macros',
            style: TextStyle(
              fontFamily: OnbTokens.fontDisplay,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: OnbTokens.cream,
            ),
          ),
          const SizedBox(height: 12),
          _MacrosCard(day: _dayPreview(bundle.preview), dayTag: _calorieTag),
        ],
      ],
    );
  }

  /// Spec tabs: cream-6% pill track (radius 100, 3px padding) with three
  /// equal pills — selected teal with plum text, unselected transparent
  /// cream-70%, Apercu 12/500.
  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: OnbTokens.creamA(0.06),
        borderRadius: BorderRadius.circular(OnbTokens.rPill),
      ),
      child: Row(
        children: [
          for (final tab in PreviewDayType.values)
            Expanded(
              child: _DayTab(
                tabKey: ValueKey('daily_preview.tab_${_tabName(tab)}'),
                label: _tabLabel(tab),
                isSelected: tab == _tab,
                onTap: () => _selectTab(tab),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayTab extends StatelessWidget {
  const _DayTab({
    required this.tabKey,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final Key tabKey;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: tabKey,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? OnbTokens.teal : Colors.transparent,
          borderRadius: BorderRadius.circular(OnbTokens.rPill),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: OnbTokens.fontBody,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected ? OnbTokens.bg : OnbTokens.creamA(0.7),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Your Macros" card: cream-4% fill, 1px cream-12% border, radius 15,
/// 6px/16px padding. Rows are 13px-vertical-padding flex rows (gap 10):
/// 9px color dot, Apercu 13.5/500 label, 11.5 cream-45% g/kg (or day tag),
/// and an Apercu Mono 17 value with an 11px cream-50% unit.
class _MacrosCard extends StatelessWidget {
  const _MacrosCard({required this.day, required this.dayTag});

  final DayPreview day;
  final String dayTag;

  // Spec dot colors (oklch resolved to sRGB).
  static const Color _carbsDot = Color(0xFFF7C243);
  static const Color _proteinDot = Color(0xFFDC2597);
  static const Color _fatDot = Color(0xFF437DDE);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('daily_preview.macros_card'),
      decoration: BoxDecoration(
        color: OnbTokens.creamA(0.04),
        borderRadius: BorderRadius.circular(OnbTokens.rCard),
        border: Border.all(color: OnbTokens.creamA(0.12)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Column(
        children: [
          _macroRow(
            dot: _carbsDot,
            label: 'Carbs',
            meta: '${day.carbGPerKg.toStringAsFixed(1)} g/kg',
            value: '${day.carbsG}',
            unit: 'g',
          ),
          _macroRow(
            dot: _proteinDot,
            label: 'Protein',
            meta: '${day.proteinGPerKg.toStringAsFixed(1)} g/kg',
            value: '${day.proteinG}',
            unit: 'g',
          ),
          _macroRow(
            dot: _fatDot,
            label: 'Fat',
            meta: '${day.fatGPerKg.toStringAsFixed(1)} g/kg',
            value: '${day.fatG}',
            unit: 'g',
          ),
          _macroRow(
            dot: OnbTokens.creamA(0.35),
            label: 'Calories',
            meta: dayTag,
            value: '${day.calories}',
            unit: 'kcal',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _macroRow({
    required Color dot,
    required String label,
    required String meta,
    required String value,
    required String unit,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: OnbTokens.creamA(0.08))),
            ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: OnbTokens.fontBody,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: OnbTokens.cream,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Spec: the meta column is shrinkable (flex 0 1 auto) — real
          // fonts never need it, but it keeps the row overflow-proof.
          Flexible(
            child: Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: OnbTokens.fontBody,
                fontSize: 11.5,
                color: OnbTokens.creamA(0.45),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontFamily: OnbTokens.fontMono,
                    fontSize: 17,
                    color: OnbTokens.cream,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontFamily: OnbTokens.fontMono,
                    fontSize: 11,
                    color: OnbTokens.creamA(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
