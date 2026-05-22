import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/daily_macro_targets.dart';
import 'periodization_bottom_sheet.dart';

/// Weekly line chart showing 7-day macro overview.
/// Defaults to collapsed; tap header to expand/collapse.
class WeeklyOverviewChart extends StatefulWidget {
  const WeeklyOverviewChart({
    super.key,
    required this.weeklyMacros,
    required this.startOfWeek,
  });

  final List<DailyMacroTargets?> weeklyMacros;
  final DateTime startOfWeek;

  @override
  State<WeeklyOverviewChart> createState() => _WeeklyOverviewChartState();
}

class _WeeklyOverviewChartState extends State<WeeklyOverviewChart> {
  bool _isExpanded = false;

  // Sunday-start day labels
  static const _dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  int get _dataPointCount => widget.weeklyMacros.where((m) => m != null).length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row: title + expand/collapse arrow + info button (outside card)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                key: const ValueKey('nutrition_diary.weekly_overview_toggle'),
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Weekly overview',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: textColor.withValues(alpha: 0.6),
                      size: 20,
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const ValueKey('weekly_chart.info_button'),
                onPressed: () => _showInfoDialog(context),
                icon: FaIcon(
                  FontAwesomeIcons.circleInfo,
                  size: 16,
                  color: textColor.withValues(alpha: 0.5),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),

        // Expanded chart content (inside card)
        if (_isExpanded) ...[
          const SizedBox(height: AppSpacing.sm),
          BaseCard(
            backgroundColor: isDark
                ? AppColors.blackberryLight.withValues(alpha: 0.6)
                : null,
            child: Column(
              children: [
                // Sparse data check: need at least 2 data points for a meaningful chart
                if (_dataPointCount < 2)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    child: Center(
                      child: Text(
                        'Calculate more days to see weekly trends',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: textColor.withValues(alpha: 0.5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else ...[
                  // Chart
                  SizedBox(
                    key: const ValueKey('weekly_chart.chart'),
                    height: 180,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: _calculateInterval(),
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: textColor.withValues(alpha: 0.1),
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 24,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                // Only render labels at integer day indices to
                                // avoid duplicates when fl_chart picks a
                                // sub-integer interval.
                                if (value != value.roundToDouble()) {
                                  return const SizedBox.shrink();
                                }
                                final index = value.toInt();
                                if (index < 0 || index >= _dayLabels.length) {
                                  return const SizedBox.shrink();
                                }
                                return Text(
                                  _dayLabels[index],
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: textColor.withValues(alpha: 0.6),
                                    fontSize: 11,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          // Calories line (scaled down to fit with macros)
                          _buildLine(
                            (m) => m.totalCalories / 10,
                            AppColors.cream,
                            isDark,
                          ),
                          // Carbs
                          _buildLine(
                            (m) => m.carbG,
                            AppColors.electrolyte,
                            isDark,
                          ),
                          // Protein
                          _buildLine((m) => m.protG, AppColors.orange, isDark),
                          // Fat
                          _buildLine(
                            (m) => m.fatG,
                            AppColors.dragonfruit,
                            isDark,
                          ),
                        ],
                        lineTouchData: LineTouchData(
                          enabled: true,
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (spot) =>
                                isDark ? AppColors.blackberry : Colors.white,
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final dayIndex = spot.x.toInt();
                                if (dayIndex < 0 ||
                                    dayIndex >= widget.weeklyMacros.length) {
                                  return null;
                                }
                                final macro = widget.weeklyMacros[dayIndex];
                                if (macro == null) return null;

                                String label;
                                double value;
                                switch (spot.barIndex) {
                                  case 0:
                                    label = 'Cal';
                                    value = macro.totalCalories;
                                    break;
                                  case 1:
                                    label = 'C';
                                    value = macro.carbG;
                                    break;
                                  case 2:
                                    label = 'P';
                                    value = macro.protG;
                                    break;
                                  case 3:
                                    label = 'F';
                                    value = macro.fatG;
                                    break;
                                  default:
                                    label = '';
                                    value = 0;
                                }
                                return LineTooltipItem(
                                  '$label: ${value.round()}${spot.barIndex == 0 ? '' : 'g'}',
                                  TextStyle(
                                    color: spot.bar.color,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Legend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LegendItem(
                        key: const ValueKey('weekly_chart.legend_cal'),
                        color: AppColors.cream,
                        label: 'Cal',
                        isDark: isDark,
                      ),
                      const SizedBox(width: 16),
                      _LegendItem(
                        key: const ValueKey('weekly_chart.legend_carbs'),
                        color: AppColors.electrolyte,
                        label: 'Carbs',
                        isDark: isDark,
                      ),
                      const SizedBox(width: 16),
                      _LegendItem(
                        key: const ValueKey('weekly_chart.legend_protein'),
                        color: AppColors.orange,
                        label: 'Protein',
                        isDark: isDark,
                      ),
                      const SizedBox(width: 16),
                      _LegendItem(
                        key: const ValueKey('weekly_chart.legend_fat'),
                        color: AppColors.dragonfruit,
                        label: 'Fat',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  LineChartBarData _buildLine(
    double Function(DailyMacroTargets) getValue,
    Color color,
    bool isDark,
  ) {
    final spots = <FlSpot>[];
    for (int i = 0; i < 7; i++) {
      if (i < widget.weeklyMacros.length && widget.weeklyMacros[i] != null) {
        spots.add(FlSpot(i.toDouble(), getValue(widget.weeklyMacros[i]!)));
      }
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 2,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(radius: 3, color: color, strokeWidth: 0);
        },
      ),
      belowBarData: BarAreaData(show: false),
    );
  }

  double _calculateInterval() {
    double maxVal = 0;
    for (final m in widget.weeklyMacros) {
      if (m != null) {
        if (m.carbG > maxVal) maxVal = m.carbG;
        if (m.totalCalories / 10 > maxVal) maxVal = m.totalCalories / 10;
      }
    }
    if (maxVal == 0) return 100;
    return (maxVal / 4).ceilToDouble();
  }

  void _showInfoDialog(BuildContext context) {
    PeriodizationBottomSheet.show(context, weeklyMacros: widget.weeklyMacros);
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    super.key,
    required this.color,
    required this.label,
    required this.isDark,
  });

  final Color color;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: isDark
                ? AppColors.cream.withValues(alpha: 0.7)
                : AppColors.blackberry.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
