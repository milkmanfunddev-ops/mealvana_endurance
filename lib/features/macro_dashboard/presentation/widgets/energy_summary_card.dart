import 'package:flutter/material.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart'
    show CarbLoadBar;
import '../../domain/carb_dashboard_models.dart';
import '../../domain/dashboard_models.dart';
import '../me_tokens.dart';

/// Energy summary card — ONE component with three faces, not three cards
/// (docs/ssot/spec/design/components/energy-card.md, RATIFIED v1).
///
/// The face follows the surface's filter lens (never self-chosen); the
/// expansion state is the card's own and PERSISTS across face switches and
/// any timeline/card state change elsewhere (P-1 — the surface guarantees
/// the environment honours it, S-4). Collapsed and expanded deliberately
/// show DIFFERENT quantities (P-2). This card invents no arithmetic (P-3).
///
/// Number-color contract (Q-D3): burn-side figures render in electrolyte,
/// intake-side figures in orange — the hue IS the axis label.
class EnergySummaryCard extends StatelessWidget {
  const EnergySummaryCard({
    super.key,
    required this.face,
    required this.expanded,
    required this.data,
    required this.onToggleExpanded,
    this.onFullBreakdown,
    this.carb,
    this.onCarbBreakdown,
  });

  final DashboardFilter face;
  final bool expanded;
  final EnergyCardData data;

  /// E1: toggles in place; never navigates.
  final VoidCallback onToggleExpanded;

  /// E2: opens the face's sheet (outside this contract).
  final VoidCallback? onFullBreakdown;

  /// LOAD face data (energy-card.md §LOAD-face, Q-D9 form). Non-null only
  /// on loading days — the surface chooses the face, never the filter lens
  /// (CD-1); when set, LOAD replaces the All-lens face.
  final CarbLoadFaceData? carb;

  /// E2 on LOAD: opens the carb-loading breakdown page (never the
  /// net-balance pager).
  final VoidCallback? onCarbBreakdown;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: expanded ? 0 : 68),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: MeTokens.creamAlpha(0.1)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: expanded
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Expanded(child: _faceContent()),
          Semantics(
            button: true,
            label: expanded ? 'Collapse details' : 'Expand details',
            child: GestureDetector(
              key: const ValueKey('macro_dashboard.energy_expand'),
              behavior: HitTestBehavior.opaque,
              onTap: onToggleExpanded,
              child: Padding(
                padding: const EdgeInsets.only(left: 12, top: 1),
                child: AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 16,
                    color: MeTokens.creamAlpha(0.55),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _faceContent() {
    // LOAD replaces the All-lens face on loading days (CD-1); Workout and
    // Meals stay one tap away, untouched.
    final load = carb;
    if (!expanded) {
      return switch (face) {
        DashboardFilter.all when load != null => _collapsedLoad(load),
        DashboardFilter.all => _collapsedAll(),
        DashboardFilter.workout => _collapsedWorkout(),
        DashboardFilter.meals => _collapsedMeals(),
      };
    }
    return switch (face) {
      DashboardFilter.all when load != null => _expandedLoad(load),
      DashboardFilter.all => _expandedAll(),
      DashboardFilter.workout => _expandedWorkout(),
      DashboardFilter.meals => _expandedMeals(),
    };
  }

  // -------------------------------------------------------------------
  // LOAD face (energy-card.md §LOAD-face amendment, Q-D9 form). Strings
  // arrive from the assembler's copy register verbatim (P-3).
  // -------------------------------------------------------------------

  Widget _collapsedLoad(CarbLoadFaceData load) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _label(load.labelLine),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Bar two thirds, pace words one third — one row.
            Expanded(
              flex: 2,
              child: CarbLoadBar(
                fillFrac: load.fillFrac,
                tickFrac: load.tickFrac,
                loaded: load.loaded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    load.paceMainStr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // Carb figures are intake side → orange (Q-D3).
                    style: TextStyle(
                      fontFamily: 'Sansita',
                      fontWeight: FontWeight.w700,
                      fontSize: load.paceMainIsWord ? 18 : 21,
                      height: 1.05,
                      color: MeTokens.orange,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    load.paceSubStr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Apercu',
                      fontSize: 10.5,
                      color: MeTokens.creamAlpha(0.55),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _expandedLoad(CarbLoadFaceData load) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _label(load.labelLine),
        const SizedBox(height: 7),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              load.eatenOfTargetStr,
              style: const TextStyle(
                fontFamily: 'Sansita',
                fontWeight: FontWeight.w700,
                fontSize: 25,
                height: 1,
                color: MeTokens.orange,
              ),
            ),
            const SizedBox(width: 8),
            // Registered form: to-go clamps at 0 (never negative, never a
            // worded substitute).
            _unit(load.toGoStr),
          ],
        ),
        const SizedBox(height: 10),
        CarbLoadBar(
          fillFrac: load.fillFrac,
          tickFrac: load.tickFrac,
          loaded: load.loaded,
          height: 8,
        ),
        if (load.paceByNowStr != null) ...[
          const SizedBox(height: 6),
          Text(
            load.paceByNowStr!,
            style: TextStyle(
              fontFamily: 'Apercu',
              fontSize: 10.5,
              color: MeTokens.creamAlpha(0.5),
            ),
          ),
        ],
        const SizedBox(height: 12),
        // E2 on LOAD: the carb breakdown page, never the net-balance pager.
        _fullBreakdownButton(
          onTap: onCarbBreakdown,
          keyName: 'macro_dashboard.carb_full_breakdown',
        ),
      ],
    );
  }

  // -------------------------------------------------------------------
  // Collapsed faces — the single most decision-relevant number (P-2)
  // -------------------------------------------------------------------

  Widget _collapsedAll() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _label('Net balance'),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              netStr(data.netKcal),
              // Net balance is an intake-side figure → orange (Q-D3).
              style: const TextStyle(
                fontFamily: 'Sansita',
                fontWeight: FontWeight.w700,
                fontSize: 27,
                height: 1,
                color: MeTokens.orange,
              ),
            ),
            const SizedBox(width: 6),
            _unit('kcal'),
            if (data.bandCopy != null) ...[
              const SizedBox(width: 6),
              Text(
                data.bandCopy!,
                style: TextStyle(
                  fontFamily: 'Apercu',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _bandInk(data.netKcal),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _collapsedWorkout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _label("Today's Workout"),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              kcalStr(data.workoutDoneKcal),
              // Burn-side figure → electrolyte (Q-D3).
              style: const TextStyle(
                fontFamily: 'Sansita',
                fontWeight: FontWeight.w700,
                fontSize: 24,
                height: 1,
                color: MeTokens.electrolyte,
              ),
            ),
            const SizedBox(width: 5),
            _unit('done · ${kcalStr(data.workoutPlannedKcal)} planned'),
          ],
        ),
      ],
    );
  }

  Widget _collapsedMeals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _label('Daily budget'),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              kcalStr(data.targetKcal),
              style: const TextStyle(
                fontFamily: 'Sansita',
                fontWeight: FontWeight.w700,
                fontSize: 24,
                height: 1,
                color: MeTokens.orange,
              ),
            ),
            const SizedBox(width: 6),
            _unit('kcal'),
            const SizedBox(width: 6),
            Flexible(
              child: Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontFamily: 'Apercu Mono',
                    fontSize: 11,
                    color: MeTokens.creamAlpha(0.4),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  children: [
                    const TextSpan(text: '· '),
                    TextSpan(
                      text: '${data.carbTargetG.round()}C',
                      style: const TextStyle(color: MeTokens.electrolyte),
                    ),
                    const TextSpan(text: ' · '),
                    TextSpan(
                      text: '${data.proteinTargetG.round()}P',
                      style: const TextStyle(color: MeTokens.proteinAccent),
                    ),
                    const TextSpan(text: ' · '),
                    TextSpan(
                      text: '${data.fatTargetG.round()}F',
                      style: const TextStyle(color: MeTokens.fatAccent),
                    ),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------------
  // Expanded faces — the working detail (P-2)
  // -------------------------------------------------------------------

  Widget _expandedAll() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _label('Net energy balance'),
        const SizedBox(height: 7),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 7,
          runSpacing: 5,
          children: [
            _monoNumber(kcalStr(data.eatenKcal), MeTokens.orange),
            _dimLabel('eaten'),
            Text(
              '−',
              style: TextStyle(
                fontFamily: 'Apercu',
                fontSize: 13,
                color: MeTokens.creamAlpha(0.4),
              ),
            ),
            _monoNumber(kcalStr(data.burnedKcal), MeTokens.electrolyte),
            _dimLabel('burned'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '=',
              style: TextStyle(
                fontFamily: 'Sansita',
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: MeTokens.creamAlpha(0.35),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              netStr(data.netKcal),
              style: const TextStyle(
                fontFamily: 'Sansita',
                fontWeight: FontWeight.w700,
                fontSize: 38,
                height: 0.85,
                color: MeTokens.orange,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'kcal',
              style: TextStyle(
                fontFamily: 'Sansita',
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: MeTokens.orangeAlpha(0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        Container(
          padding: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: MeTokens.creamAlpha(0.1))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text.rich(
                TextSpan(
                  style: _footerStyle,
                  children: [
                    const TextSpan(text: 'Eaten '),
                    TextSpan(
                      text: kcalStr(data.eatenKcal),
                      style: TextStyle(color: MeTokens.creamAlpha(0.75)),
                    ),
                    TextSpan(text: ' / ${kcalStr(data.targetKcal)}'),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(
                  style: _footerStyle,
                  children: [
                    TextSpan(
                      text: kcalStr(
                        data.remainingKcal.clamp(0, double.infinity),
                      ),
                      style: TextStyle(color: MeTokens.creamAlpha(0.75)),
                    ),
                    const TextSpan(text: ' kcal to target'),
                  ],
                ),
              ),
            ],
          ),
        ),
        _fullBreakdownButton(),
      ],
    );
  }

  Widget _expandedWorkout() {
    final projected = data.workoutProjectedKcal;
    final donePct = projected > 0 ? data.workoutDoneKcal / projected : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _label('Active energy'),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              kcalStr(data.workoutDoneKcal),
              style: const TextStyle(
                fontFamily: 'Sansita',
                fontWeight: FontWeight.w700,
                fontSize: 25,
                height: 1,
                color: MeTokens.electrolyte,
              ),
            ),
            const SizedBox(width: 5),
            _unit('done · ${kcalStr(data.workoutPlannedKcal)} planned'),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 6,
          child: Row(
            children: [
              Expanded(
                flex: (donePct * 1000).round().clamp(0, 1000),
                child: Container(
                  decoration: BoxDecoration(
                    color: MeTokens.electrolyte,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                flex: ((1 - donePct) * 1000).round().clamp(0, 1000),
                child: Container(
                  decoration: BoxDecoration(
                    color: MeTokens.electrolyteAlpha(0.22),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 11),
        ...data.workoutRows.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: r.planned
                        ? MeTokens.electrolyteAlpha(0.3)
                        : MeTokens.electrolyte,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Apercu',
                      fontSize: 11.5,
                      color: r.planned
                          ? MeTokens.creamAlpha(0.6)
                          : MeTokens.cream,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  r.note,
                  style: TextStyle(
                    fontFamily: 'Apercu',
                    fontSize: 10,
                    color: MeTokens.creamAlpha(0.38),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  kcalStr(r.kcal),
                  style: TextStyle(
                    fontFamily: 'Apercu Mono',
                    fontSize: 11.5,
                    color: r.planned
                        ? MeTokens.creamAlpha(0.55)
                        : MeTokens.cream,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.only(top: 9),
          margin: const EdgeInsets.only(top: 3),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: MeTokens.creamAlpha(0.1))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Projected by day's end", style: _footerStyle),
              Text(
                '${kcalStr(projected)} kcal',
                style: const TextStyle(
                  fontFamily: 'Apercu Mono',
                  fontSize: 12.5,
                  color: MeTokens.cream,
                ),
              ),
            ],
          ),
        ),
        _fullBreakdownButton(),
      ],
    );
  }

  Widget _expandedMeals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _label('Intake today'),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              kcalStr(data.eatenKcal),
              style: const TextStyle(
                fontFamily: 'Sansita',
                fontWeight: FontWeight.w700,
                fontSize: 25,
                height: 1,
                color: MeTokens.orange,
              ),
            ),
            const SizedBox(width: 5),
            _unit('/ ${kcalStr(data.targetKcal)} kcal'),
          ],
        ),
        const SizedBox(height: 11),
        Row(
          children: [
            _macroBar(
              'Carbs',
              data.carbEatenG,
              data.carbTargetG,
              MeTokens.electrolyte,
            ),
            const SizedBox(width: 12),
            _macroBar(
              'Protein',
              data.proteinEatenG,
              data.proteinTargetG,
              MeTokens.proteinAccent,
            ),
            const SizedBox(width: 12),
            _macroBar(
              'Fat',
              data.fatEatenG,
              data.fatTargetG,
              MeTokens.fatAccent,
            ),
          ],
        ),
        _fullBreakdownButton(),
      ],
    );
  }

  Widget _macroBar(String label, double eaten, double target, Color color) {
    final pct = target > 0 ? (eaten / target).clamp(0.0, 1.0) : 0.0;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              style: const TextStyle(
                fontFamily: 'Apercu Mono',
                fontSize: 12.5,
                color: MeTokens.cream,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              children: [
                TextSpan(text: '${eaten.round()}'),
                TextSpan(
                  text: '/${target.round()}g',
                  style: TextStyle(color: MeTokens.creamAlpha(0.4)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 5,
              child: Stack(
                children: [
                  Container(color: MeTokens.creamAlpha(0.1)),
                  FractionallySizedBox(
                    widthFactor: pct,
                    child: Container(color: color),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Apercu',
              fontSize: 10,
              color: MeTokens.creamAlpha(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fullBreakdownButton({
    VoidCallback? onTap,
    String keyName = 'macro_dashboard.full_breakdown',
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 13),
      child: GestureDetector(
        key: ValueKey(keyName),
        onTap: onTap ?? onFullBreakdown,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: MeTokens.electrolyteAlpha(0.4)),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'Full Breakdown',
                style: TextStyle(
                  fontFamily: 'Apercu',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: MeTokens.electrolyte,
                ),
              ),
              SizedBox(width: 5),
              Icon(Icons.chevron_right, size: 13, color: MeTokens.electrolyte),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------

  Widget _label(String text) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontFamily: 'Apercu',
      fontSize: 9.5,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.8,
      color: MeTokens.creamAlpha(0.5),
    ),
  );

  Widget _unit(String text) => Text(
    text,
    style: TextStyle(
      fontFamily: 'Apercu',
      fontSize: 11,
      color: MeTokens.creamAlpha(0.45),
    ),
  );

  Widget _dimLabel(String text) => Text(
    text,
    style: TextStyle(
      fontFamily: 'Apercu',
      fontSize: 11,
      color: MeTokens.creamAlpha(0.5),
    ),
  );

  Widget _monoNumber(String text, Color color) => Text(
    text,
    style: TextStyle(
      fontFamily: 'Apercu Mono',
      fontWeight: FontWeight.w700,
      fontSize: 14,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );

  TextStyle get _footerStyle => TextStyle(
    fontFamily: 'Apercu',
    fontSize: 10.5,
    color: MeTokens.creamAlpha(0.45),
  );

  Color _bandInk(double net) {
    final magnitude = net.abs();
    if (magnitude <= 200) return MeTokens.electrolyte;
    if (magnitude <= 500) return MeTokens.creamAlpha(0.7);
    return MeTokens.orange;
  }
}
