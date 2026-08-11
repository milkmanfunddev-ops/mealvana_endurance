import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/providers/unit_system_provider.dart';
import '../../../../shared/utils/unit_formatter.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../daily_macros/presentation/widgets/macro_palette.dart';
import '../../../nutrition_plan/domain/run_parameters.dart';
import '../../domain/day_energy_summary.dart';
import '../../domain/fuel_timeline_filter.dart';
import '../../domain/timeline_node.dart';
import '../fuel_timeline_type.dart';

/// The collapsible energy card at the top of the Fuel Timeline. Its content
/// changes with the active [filter]:
/// - **All** → Intake + Burned (collapsed) / Energy Balance (expanded).
/// - **Meals** → Daily budget (collapsed) / Intake + macro bars (expanded).
/// - **Workout** → planned + count (collapsed) / Active Energy rows (expanded).
class EnergyDashboardCard extends ConsumerWidget {
  const EnergyDashboardCard({
    super.key,
    required this.filter,
    required this.summary,
    required this.workouts,
    required this.expanded,
    required this.onToggle,
    required this.onOpenBreakdown,
  });

  final FuelTimelineFilter filter;
  final DayEnergySummary summary;
  final List<WorkoutNode> workouts;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onOpenBreakdown;

  static final _fmt = NumberFormat.decimalPattern();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? AppColors.cream : AppColors.blackberry;
    final muted = onSurface.withValues(alpha: 0.5);
    final useMetric =
        (ref.watch(unitSystemProvider).value ?? UnitSystem.imperial) ==
        UnitSystem.metric;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: onSurface.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: expanded
                ? _expanded(context, onSurface, muted, useMetric)
                : _collapsed(context, onSurface, muted),
          ),
          IconButton(
            key: const ValueKey('fuel_timeline.dash_expand_toggle'),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onToggle,
            icon: AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.keyboard_arrow_down, size: 22, color: muted),
            ),
          ),
        ],
      ),
    );
  }

  // ── collapsed ──────────────────────────────────────────────────────────────

  Widget _collapsed(BuildContext context, Color onSurface, Color muted) {
    switch (filter) {
      case FuelTimelineFilter.all:
        // Scale-down guard: two big numbers side by side can exceed a narrow
        // card; FittedBox keeps them on one row without overflow.
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              _stat(
                'INTAKE',
                summary.eatenCalories,
                kMacroColorCalories,
                muted,
              ),
              const SizedBox(width: 24),
              if (summary.hasBurnData)
                _stat(
                  'BURNED',
                  summary.burnedCalories.round(),
                  AppColors.electrolyteDark,
                  muted,
                ),
            ],
          ),
        );
      case FuelTimelineFilter.workout:
        return _labelledBig(
          'TODAY\'S WORKOUT',
          _fmt.format(summary.plannedWorkoutKcal.round()),
          'kcal planned · ${_workoutCount()}',
          AppColors.electrolyteDark,
          muted,
        );
      case FuelTimelineFilter.meals:
        return _labelledBig(
          'DAILY BUDGET',
          _fmt.format(summary.targetCalories.round()),
          'kcal',
          kMacroColorCalories,
          muted,
          trailingMacros: true,
        );
    }
  }

  Widget _stat(String label, int value, Color color, Color muted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: FtType.eyebrow.copyWith(color: muted)),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              _fmt.format(value),
              style: FtType.bigNumber.copyWith(color: color),
            ),
            const SizedBox(width: 4),
            Text('kcal', style: FtType.kcalSuffix.copyWith(color: muted)),
          ],
        ),
      ],
    );
  }

  Widget _labelledBig(
    String label,
    String value,
    String suffix,
    Color color,
    Color muted, {
    bool trailingMacros = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: FtType.eyebrow.copyWith(color: muted)),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: FtType.bigNumber.copyWith(color: color)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                trailingMacros ? '$suffix · ${_macroSuffix()}' : suffix,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FtType.kcalSuffix.copyWith(color: muted),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _macroSuffix() =>
      '${summary.carbsTarget.round()}C · ${summary.proteinTarget.round()}P · ${summary.fatTarget.round()}F';

  // ── expanded ─────────────────────────────────────────────────────────────

  Widget _expanded(
    BuildContext context,
    Color onSurface,
    Color muted,
    bool useMetric,
  ) {
    switch (filter) {
      case FuelTimelineFilter.all:
        return _expandedAll(context, onSurface, muted);
      case FuelTimelineFilter.meals:
        return _expandedMeals(context, onSurface, muted);
      case FuelTimelineFilter.workout:
        return _expandedWorkout(context, onSurface, muted, useMetric);
    }
  }

  Widget _expandedAll(BuildContext context, Color onSurface, Color muted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('ENERGY BALANCE', muted),
        const SizedBox(height: 4),
        _intakeLine(muted),
        const SizedBox(height: 12),
        _bar(summary.caloriesPct, kMacroColorCalories, onSurface),
        const SizedBox(height: 12),
        if (summary.hasBurnData)
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  'Burned',
                  '${_fmt.format(summary.burnedCalories.round())} kcal',
                  onSurface,
                  muted,
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: onSurface.withValues(alpha: 0.12),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _miniStat(
                  'Net intake',
                  '${_fmt.format(summary.netCalories.round())} kcal',
                  onSurface,
                  muted,
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        _breakdownButton(),
      ],
    );
  }

  Widget _expandedMeals(BuildContext context, Color onSurface, Color muted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('INTAKE TODAY', muted),
        const SizedBox(height: 4),
        _intakeLine(muted),
        const SizedBox(height: 11),
        Row(
          children: [
            _macroBar(
              'Carbs',
              summary.carbsEaten,
              summary.carbsTarget,
              summary.carbsPct,
              kMacroColorCarbs,
              onSurface,
              muted,
            ),
            const SizedBox(width: 12),
            _macroBar(
              'Protein',
              summary.proteinEaten,
              summary.proteinTarget,
              summary.proteinPct,
              kMacroColorProtein,
              onSurface,
              muted,
            ),
            const SizedBox(width: 12),
            _macroBar(
              'Fat',
              summary.fatEaten,
              summary.fatTarget,
              summary.fatPct,
              kMacroColorFat,
              onSurface,
              muted,
            ),
          ],
        ),
        const SizedBox(height: 13),
        _breakdownButton(),
      ],
    );
  }

  Widget _expandedWorkout(
    BuildContext context,
    Color onSurface,
    Color muted,
    bool useMetric,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('ACTIVE ENERGY', muted),
        const SizedBox(height: 4),
        _fit(
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _fmt.format(summary.plannedWorkoutKcal.round()),
                style: FtType.bigNumber.copyWith(
                  color: AppColors.electrolyteDark,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'kcal planned · ${_workoutCount()}',
                style: FtType.kcalSuffix.copyWith(color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 11),
        ...workouts.map((w) => _workoutRow(w, onSurface, muted, useMetric)),
        const SizedBox(height: 13),
        _breakdownButton(),
      ],
    );
  }

  Widget _workoutRow(
    WorkoutNode node,
    Color onSurface,
    Color muted,
    bool useMetric,
  ) {
    final a = node.activity;
    final sub = _workoutSubtitle(a, useMetric);
    final showKcal = workouts.length == 1 && summary.plannedWorkoutKcal > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.electrolyteDark,
            ),
            child: Icon(
              // Real activity-type icon (was hardcoded to cycling for every
              // workout — same bug as the timeline tile's workout card).
              a.activityType.icon,
              size: 15,
              color: AppColors.blackberry,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FtType.itemName.copyWith(color: onSurface),
                ),
                if (sub != null)
                  Text(sub, style: FtType.kcalSuffix.copyWith(color: muted)),
              ],
            ),
          ),
          if (showKcal)
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '${_fmt.format(summary.plannedWorkoutKcal.round())} kcal',
                  style: FtType.miniValue.copyWith(color: onSurface),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── shared bits ────────────────────────────────────────────────────────────

  Widget _eyebrow(String text, Color muted) =>
      Text(text, style: FtType.eyebrow.copyWith(color: muted));

  /// Scale-down guard: keeps a fixed-width number row on one line without
  /// overflowing a narrow card / large system font.
  Widget _fit(Widget child) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: child,
  );

  Widget _intakeLine(Color muted) {
    return _fit(
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            _fmt.format(summary.eatenCalories),
            style: FtType.bigNumber.copyWith(color: kMacroColorCalories),
          ),
          const SizedBox(width: 6),
          Text(
            '/ ${_fmt.format(summary.targetCalories.round())} kcal',
            style: FtType.targetSuffix.copyWith(color: muted),
          ),
        ],
      ),
    );
  }

  Widget _bar(double pct, Color color, Color onSurface) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: pct,
        minHeight: 5,
        backgroundColor: onSurface.withValues(alpha: 0.1),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }

  Widget _macroBar(
    String label,
    double eaten,
    double target,
    double pct,
    Color color,
    Color onSurface,
    Color muted,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fit(
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${eaten.round()}',
                  style: FtType.miniValue.copyWith(color: onSurface),
                ),
                Text(
                  '/${target.round()}g',
                  style: FtType.kcalSuffix.copyWith(color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _bar(pct, color, onSurface),
          const SizedBox(height: 5),
          Text(label, style: FtType.kcalSuffix.copyWith(color: muted)),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color onSurface, Color muted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: FtType.kcalSuffix.copyWith(color: muted)),
        const SizedBox(height: 4),
        Text(value, style: FtType.miniValue.copyWith(color: onSurface)),
      ],
    );
  }

  Widget _breakdownButton() {
    return OutlinedButton(
      key: const ValueKey('fuel_timeline.breakdown_button'),
      onPressed: onOpenBreakdown,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.electrolyteDark,
        textStyle: FtType.breakdownBtn,
        side: BorderSide(
          color: AppColors.electrolyteDark.withValues(alpha: 0.4),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Full Breakdown'),
          SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 16),
        ],
      ),
    );
  }

  String _workoutCount() =>
      workouts.length == 1 ? '1 workout' : '${workouts.length} workouts';

  String? _workoutSubtitle(dynamic activity, bool useMetric) {
    final parts = <String>[];
    final dist = activity.distanceMiles as double?;
    final speed = activity.cyclingSpeedMph as double?;
    final dur = activity.durationMinutes as int?;
    if (dist != null) {
      parts.add(
        UnitFormatter.formatDistance(
          dist,
          unit: useMetric ? DistanceUnit.kilometers : DistanceUnit.miles,
        ),
      );
    }
    if (speed != null) {
      parts.add(UnitFormatter.formatSpeed(speed, useMetric: useMetric));
    }
    if (dur != null) parts.add('${(dur / 60).toStringAsFixed(1)} h');
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
