import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/services/app_external_deps.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../domain/onboarding_plan_preview.dart';
import '../providers/onboarding_controller.dart';
import '../providers/onboarding_preview_providers.dart';
import '../widgets/onboarding_step_scaffold.dart';

/// Daily Plan Preview Screen - Step 9 (final) of Onboarding (2026-08
/// redesign)
///
/// Three sample days (Workout / Rest / Carb load) from the same
/// [onboardingPlanPreviewProvider] bundle the plan reveal rendered, so both
/// screens show consistent numbers. Continue is "Save My Plan" — the
/// pageview's last-page branch routes it to /auth/post-onboarding.
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
        return 'Minimal movement — the day after a long session.';
      case PreviewDayType.carbLoad:
        return 'The day before your race — topping up glycogen.';
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
      title: "And here's how to eat every day.",
      subtitle:
          'Targets shift with your training — carbs rise on workout days. '
          'Here are three sample days.',
      titleKey: const ValueKey('daily_preview.title'),
      stepIndex: widget.stepIndex,
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
          Text(
            _dayDescription(bundle.preview),
            key: const ValueKey('daily_preview.day_description'),
            textAlign: TextAlign.center,
            style: kOnboardingBodyMutedStyle,
          ),
          const SizedBox(height: 16),
          _MacrosCard(day: _dayPreview(bundle.preview)),
          if (draft.connectedProvider == null &&
              widget.onConnectTap != null) ...[
            const SizedBox(height: 16),
            OnboardingConnectNudgeCard(
              key: const ValueKey('daily_preview.connect_nudge'),
              onConnectNow: widget.onConnectTap!,
              connectButtonKey: const ValueKey('daily_preview.connect_now'),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildTabs() {
    return Row(
      children: [
        for (final tab in PreviewDayType.values) ...[
          if (tab != PreviewDayType.values.first) const SizedBox(width: 8),
          Expanded(
            child: _DayTab(
              tabKey: ValueKey('daily_preview.tab_${_tabName(tab)}'),
              label: _tabLabel(tab),
              isSelected: tab == _tab,
              onTap: () => _selectTab(tab),
            ),
          ),
        ],
      ],
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cream : Colors.transparent,
          border: Border.all(color: AppColors.cream, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Apercu',
              fontSize: 12,
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

/// "Your Macros" card for the active day tab: Carbs / Protein / Fat rows
/// with g/kg + grams, and a Calories row in kcal.
class _MacrosCard extends StatelessWidget {
  const _MacrosCard({required this.day});

  final DayPreview day;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('daily_preview.macros_card'),
      decoration: onboardingCardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('YOUR MACROS', style: kOnboardingSectionLabelStyle),
          const SizedBox(height: 12),
          _macroRow('Carbs', '${day.carbGPerKg} g/kg', '${day.carbsG} g'),
          const _RowDivider(),
          _macroRow(
            'Protein',
            '${day.proteinGPerKg} g/kg',
            '${day.proteinG} g',
          ),
          const _RowDivider(),
          _macroRow('Fat', '${day.fatGPerKg} g/kg', '${day.fatG} g'),
          const _RowDivider(),
          _macroRow('Calories', '', '${day.calories} kcal'),
        ],
      ),
    );
  }

  Widget _macroRow(String label, String perKg, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Apercu',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ),
          if (perKg.isNotEmpty) ...[
            Text(perKg, style: kOnboardingBodyMutedStyle),
            const SizedBox(width: 12),
          ],
          Text(
            amount,
            style: const TextStyle(
              fontFamily: 'Apercu',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.orange,
            ),
          ),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(color: AppColors.cream.withValues(alpha: 0.1), height: 1);
  }
}
