import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart'
    show CarbLoadBar;
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../macro_dashboard/domain/carb_dashboard_models.dart';
import '../../../macro_dashboard/presentation/providers/carb_dashboard_providers.dart';
import 'carb_plan_summary_screen.dart';

/// The carb-loading breakdown page — E2's destination on the LOAD face
/// (energy-card.md §LOAD-face clause 4; surfaces/carb-loading-dashboard.md
/// CD-6). READ-ONLY: the page answers the whole day; logging stays on the
/// timeline. The only interactions are the back chevron, the protocol chips
/// (day navigation — the ring follows the viewed day; the back chevron
/// restores the origin day by construction, since the dashboard's selected
/// date is never touched), and the CE-7 `Manage plan ›` footer (navigation
/// only, to the plan summary).
///
/// D7 (tokens.md Q-D3 named exception): the macro strip's carbs figure
/// renders in electrolyte on THIS strip; everywhere else carbs stay orange.
class CarbBreakdownScreen extends ConsumerStatefulWidget {
  const CarbBreakdownScreen({super.key, required this.initialDateStr});

  final String initialDateStr;

  static void open(BuildContext context, String dateStr) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CarbBreakdownScreen(initialDateStr: dateStr),
      ),
    );
  }

  @override
  ConsumerState<CarbBreakdownScreen> createState() =>
      _CarbBreakdownScreenState();
}

class _CarbBreakdownScreenState extends ConsumerState<CarbBreakdownScreen> {
  late String _viewedDateStr = widget.initialDateStr;

  @override
  Widget build(BuildContext context) {
    final carbAsync = ref.watch(carbDashboardForDateProvider(_viewedDateStr));
    final carb = carbAsync.value;
    final cream = AppColors.cream;

    return Scaffold(
      backgroundColor: AppColors.blackberry,
      body: SafeArea(
        child: carb == null
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        _backButton(context),
                        const SizedBox(width: 10),
                        Text(
                          carb.breakdown.titleLine,
                          style: TextStyle(
                            fontFamily: 'Compadre',
                            fontSize: 18,
                            color: cream,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                      children: [
                        _hero(carb),
                        const SizedBox(height: 16),
                        _macroStrip(carb.breakdown),
                        const SizedBox(height: 16),
                        _sectionLabel('By meal'),
                        for (final row in carb.breakdown.mealRows)
                          _mealRow(row),
                        const SizedBox(height: 16),
                        _sectionLabel('Protocol'),
                        _protocolChips(carb.breakdown),
                        const SizedBox(height: 16),
                        if (carb.eventId != null) _manageFooter(carb.eventId!),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _hero(CarbDashboardData carb) {
    final face = carb.face;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                face.paceMainStr,
                style: const TextStyle(
                  fontFamily: 'Sansita',
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                  height: 1,
                  color: AppColors.orange,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                face.paceSubStr,
                style: TextStyle(
                  fontFamily: 'Apercu',
                  fontSize: 11,
                  color: AppColors.cream.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          CarbLoadBar(
            fillFrac: face.fillFrac,
            tickFrac: face.tickFrac,
            loaded: face.loaded,
            height: 14,
          ),
          const SizedBox(height: 8),
          Text(
            carb.breakdown.eatenOfTargetStr,
            style: TextStyle(
              fontFamily: 'Apercu Mono',
              fontSize: 11,
              color: AppColors.cream.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroStrip(CarbBreakdownData b) {
    Widget stat(String value, String label) => Column(
      children: [
        Text(
          value,
          // D7: electrolyte on this strip, carbs included — named Q-D3
          // exception, do not recolor.
          style: const TextStyle(
            fontFamily: 'Sansita',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.electrolyte,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Apercu',
            fontSize: 8.5,
            letterSpacing: 0.8,
            color: AppColors.cream.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        stat(b.carbsStr, 'Carbs'),
        stat(b.proteinStr, 'Protein'),
        stat(b.fatStr, 'Fat'),
        stat(b.kcalStr, 'Kcal'),
      ],
    );
  }

  Widget _mealRow(CarbBreakdownMealRow row) {
    final cream = AppColors.cream;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: BoxDecoration(
        color: row.isCurrentWindow
            ? AppColors.orange.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: row.isCurrentWindow
              ? AppColors.orange.withValues(alpha: 0.5)
              : cream.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: row.label.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Apercu',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.7,
                      color: cream.withValues(alpha: 0.7),
                    ),
                    children: [
                      TextSpan(
                        text: '  ${row.clockStr}',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          color: cream.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                '${row.eatenG} / ${row.targetG} g',
                style: TextStyle(
                  fontFamily: 'Apercu Mono',
                  fontSize: 11,
                  color: cream.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: row.fillFrac,
              minHeight: 4,
              backgroundColor: cream.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _protocolChips(CarbBreakdownData b) {
    return Row(
      children: [
        for (final chip in b.dayChips) ...[
          Expanded(
            child: Semantics(
              button: true,
              label: '${chip.label}, ${chip.targetStr}',
              child: GestureDetector(
                // CD-6: chips NAVIGATE protocol days within the page.
                onTap: () => setState(() => _viewedDateStr = _ymd(chip.date)),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: chip.isViewed
                        ? AppColors.orange.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: chip.isViewed
                          ? AppColors.orange.withValues(alpha: 0.6)
                          : AppColors.cream.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        chip.label.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Apercu',
                          fontSize: 9.5,
                          letterSpacing: 0.6,
                          color: AppColors.cream.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        chip.targetStr,
                        style: const TextStyle(
                          fontFamily: 'Sansita',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (chip != b.dayChips.last) const SizedBox(width: 8),
        ],
      ],
    );
  }

  /// CE-7: navigation only — the page itself stays read-only.
  Widget _manageFooter(String eventId) {
    return Semantics(
      button: true,
      label: 'Manage plan',
      child: GestureDetector(
        key: const ValueKey('carb_breakdown.manage_plan'),
        onTap: () => CarbPlanSummaryScreen.open(context, eventId),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cream.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Manage plan',
                  style: TextStyle(
                    fontFamily: 'Apercu',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.cream,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: AppColors.cream.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6, left: 2),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: 'Apercu',
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: AppColors.cream.withValues(alpha: 0.45),
      ),
    ),
  );

  Widget _backButton(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.07),
          ),
          child: const Icon(
            Icons.chevron_left,
            size: 20,
            color: AppColors.cream,
          ),
        ),
      ),
    );
  }
}

String _ymd(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}
