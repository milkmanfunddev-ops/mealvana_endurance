import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../content/application/content_service.dart';
import '../../../daily_macros/presentation/providers/daily_macros_controller.dart';
import '../../../daily_macros/presentation/widgets/energy_source_breakdown.dart';
import '../../../daily_macros/presentation/widgets/macro_palette.dart';
import '../fuel_timeline_type.dart';
import 'weekly_fuel_chart.dart';

/// Opens the "Today's Fueling" energy breakdown sheet (the Full Breakdown
/// destination from the dashboard). Daily reuses the existing
/// [EnergySourceBreakdown]; Weekly shows the periodization chart.
void showEnergyBreakdownSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const EnergyBreakdownSheet(),
  );
}

class EnergyBreakdownSheet extends ConsumerStatefulWidget {
  const EnergyBreakdownSheet({super.key});

  @override
  ConsumerState<EnergyBreakdownSheet> createState() =>
      _EnergyBreakdownSheetState();
}

class _EnergyBreakdownSheetState extends ConsumerState<EnergyBreakdownSheet> {
  bool _weekly = false;
  static final _fmt = NumberFormat.decimalPattern();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? AppColors.cream : AppColors.blackberry;
    // A "one layer up" shade for the sheet's own surface (it floats above the
    // screen bg), matching in both themes.
    final sheetBg = isDark ? AppColors.blackberryDark : AppColors.creamDark;
    // The close button + selected-tab fill are `onSurface`; their glyph/text
    // needs to contrast against that fill, i.e. the inverse.
    final surfaceBg = isDark ? AppColors.blackberry : AppColors.cream;
    final macrosAsync = ref.watch(dailyMacrosControllerProvider);
    final state = macrosAsync.asData?.value;
    final daily = state?.dailyMacros;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _header(context, onSurface, surfaceBg),
          Expanded(
            child: daily == null
                ? Center(
                    child: Text(
                      'No targets for this day.',
                      style: FtType.body.copyWith(
                        color: onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    child: Column(
                      children: [
                        _targetHeadline(daily.totalCalories, onSurface),
                        const SizedBox(height: 18),
                        _macroChips(
                          daily.carbG,
                          daily.protG,
                          daily.fatG,
                          onSurface,
                        ),
                        const SizedBox(height: 22),
                        _toggle(onSurface, surfaceBg),
                        const SizedBox(height: 20),
                        if (_weekly)
                          _weeklyContent(state!.weeklyMacros, onSurface)
                        else
                          EnergySourceBreakdown(macros: daily),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, Color onSurface, Color surfaceBg) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: onSurface,
              ),
              child: Icon(Icons.close, size: 16, color: surfaceBg),
            ),
          ),
          Expanded(
            child: Text(
              ref
                  .read(contentServiceProvider)
                  .getValue(
                    'energy_breakdown.title',
                    defaultValue: "Today's Fueling",
                  ),
              textAlign: TextAlign.center,
              style: FtType.sheetTitle.copyWith(color: onSurface),
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _targetHeadline(double cals, Color onSurface) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            _fmt.format(cals.round()),
            style: FtType.sheetBig.copyWith(color: onSurface, fontSize: 42),
          ),
          const SizedBox(width: 8),
          Text(
            'kcal target',
            style: FtType.sheetTitle.copyWith(
              color: onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroChips(double carb, double prot, double fat, Color onSurface) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _chip(carb, 'Carbs', kMacroColorCarbs, onSurface),
          const SizedBox(width: 34),
          _chip(prot, 'Protein', kMacroColorProtein, onSurface),
          const SizedBox(width: 34),
          _chip(fat, 'Fat', kMacroColorFat, onSurface),
        ],
      ),
    );
  }

  Widget _chip(double grams, String label, Color color, Color onSurface) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${grams.round()}',
              style: FtType.macroChip.copyWith(color: color),
            ),
            Text('g', style: FtType.macroLine.copyWith(color: color)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: FtType.macroLine.copyWith(
            color: onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _toggle(Color onSurface, Color surfaceBg) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          _tab(
            ref
                .read(contentServiceProvider)
                .getValue('energy_breakdown.daily', defaultValue: 'Daily'),
            !_weekly,
            () => setState(() => _weekly = false),
            onSurface,
            surfaceBg,
          ),
          _tab(
            ref
                .read(contentServiceProvider)
                .getValue('energy_breakdown.weekly', defaultValue: 'Weekly'),
            _weekly,
            () => setState(() => _weekly = true),
            onSurface,
            surfaceBg,
          ),
        ],
      ),
    );
  }

  Widget _tab(
    String label,
    bool selected,
    VoidCallback onTap,
    Color onSurface,
    Color surfaceBg,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? onSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            label,
            style: FtType.tab.copyWith(
              color: selected ? surfaceBg : onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _weeklyContent(List week, Color onSurface) {
    final content = ref.read(contentServiceProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          content.getValue(
            'energy_breakdown.weekly_overview',
            defaultValue: 'WEEKLY OVERVIEW',
          ),
          style: FtType.eyebrow.copyWith(
            color: onSurface.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 14),
        WeeklyFuelChart(week: week.cast()),
        const SizedBox(height: 14),
        Text(
          content.getValue(
            'energy_breakdown.weekly_explainer',
            defaultValue:
                'Your week builds toward your next long effort — carbs ramp up '
                'while protein and fat hold steady. This is periodized fueling.',
          ),
          style: FtType.body.copyWith(
            color: onSurface.withValues(alpha: 0.55),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
