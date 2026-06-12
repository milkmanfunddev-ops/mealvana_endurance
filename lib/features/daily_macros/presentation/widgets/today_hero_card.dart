import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../auth/application/auth_service.dart';
import '../../../calendar/presentation/providers/calendar_selected_date_provider.dart';
import '../../../integrations/presentation/providers/integrations_providers.dart';
import '../../../integrations/presentation/widgets/garmin_attribution_message.dart';
import '../../../meal_logging/domain/consumed_totals.dart';
import '../../../meal_logging/domain/meal_log.dart';
import '../../../meal_logging/presentation/providers/meal_log_providers.dart';
import '../../domain/daily_macro_targets.dart';
import 'energy_source_breakdown.dart';

// ---------------------------------------------------------------------------
// Public macro colour constants — reused by MacroSummaryStrip.
// ---------------------------------------------------------------------------

/// Colour used for the carbs macro indicator.
const Color kMacroColorCarbs = Color(0xFF00C896);

/// Colour used for the protein macro indicator.
const Color kMacroColorProtein = Color(0xFF6B4FA0);

/// Colour used for the fat macro indicator.
const Color kMacroColorFat = Color(0xFFFF2D55);

// ---------------------------------------------------------------------------
// Detail sheet (replaces the old card composition as the primary surface)
// ---------------------------------------------------------------------------

/// Opens the "Today's Fueling" detail bottom sheet.
///
/// Contains, top to bottom:
///   - drag handle
///   - title "Today's Fueling"
///   - big calorie ring + [_FuelingText] row (same layout as the old hero card)
///   - three full [_MacroBarRow] bars
///   - divider
///   - [EnergySourceBreakdown]
///   - Garmin attribution when applicable
///
/// Scrollable so it works on small screens.
void showMacroDetailSheet(
  BuildContext context, {
  required DailyMacroTargets macros,
  required ConsumedTotals consumed,
  required bool showAttribution,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _MacroDetailSheetContent(
      macros: macros,
      consumed: consumed,
      showAttribution: showAttribution,
    ),
  );
}

// ---------------------------------------------------------------------------
// Sheet tab enum
// ---------------------------------------------------------------------------

enum _DetailTab { eaten, plan }

extension _DetailTabLabel on _DetailTab {
  String get label {
    switch (this) {
      case _DetailTab.eaten:
        return 'Eaten';
      case _DetailTab.plan:
        return 'Plan';
    }
  }
}

// ---------------------------------------------------------------------------
// Sheet content — ConsumerStatefulWidget so it can watch log + tab state
// ---------------------------------------------------------------------------

class _MacroDetailSheetContent extends ConsumerStatefulWidget {
  const _MacroDetailSheetContent({
    required this.macros,
    required this.consumed,
    required this.showAttribution,
  });

  final DailyMacroTargets macros;
  final ConsumedTotals consumed;
  final bool showAttribution;

  @override
  ConsumerState<_MacroDetailSheetContent> createState() =>
      _MacroDetailSheetContentState();
}

class _MacroDetailSheetContentState
    extends ConsumerState<_MacroDetailSheetContent> {
  _DetailTab _activeTab = _DetailTab.eaten;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.blackberry : AppColors.cream;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    // Watch the calendar's selected date so the Eaten tab always reflects the
    // date the user is browsing (same as TodayLogSection).
    final selectedDate = ref.watch(calendarSelectedDateProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final logsAsync = ref.watch(mealLogsForDateProvider(dateStr));

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (ctx, scrollController) {
          return Column(
            children: [
              // ── Static header ──────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  children: [
                    // Drag handle
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      "Today's Fueling",
                      style: AppTextStyles.pageTitle.copyWith(color: textColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Kyle segmented control — Eaten | Plan
                    _DetailTabBar(
                      activeTab: _activeTab,
                      onTabSelected: (t) => setState(() => _activeTab = t),
                      isDark: isDark,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ),
              ),
              // ── Scrollable body ────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg),
                  child: _activeTab == _DetailTab.eaten
                      ? _EatenTabBody(
                          macros: widget.macros,
                          consumed: widget.consumed,
                          logsAsync: logsAsync,
                          textColor: textColor,
                          isDark: isDark,
                        )
                      : _PlanTabBody(
                          macros: widget.macros,
                          showAttribution: widget.showAttribution,
                          textColor: textColor,
                          isDark: isDark,
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab bar for the detail sheet
// ---------------------------------------------------------------------------

class _DetailTabBar extends StatelessWidget {
  const _DetailTabBar({
    required this.activeTab,
    required this.onTabSelected,
    required this.isDark,
  });

  final _DetailTab activeTab;
  final ValueChanged<_DetailTab> onTabSelected;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white12
            : Colors.black.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: _DetailTab.values.map((tab) {
          final isSelected = tab == activeTab;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTabSelected(tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? AppColors.cream : AppColors.blackberry)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Center(
                  child: Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? (isDark
                              ? AppColors.blackberry
                              : AppColors.cream)
                          : (isDark
                              ? AppColors.cream.withValues(alpha: 0.7)
                              : AppColors.blackberry
                                  .withValues(alpha: 0.6)),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Eaten tab body
// ---------------------------------------------------------------------------

class _EatenTabBody extends StatelessWidget {
  const _EatenTabBody({
    required this.macros,
    required this.consumed,
    required this.logsAsync,
    required this.textColor,
    required this.isDark,
  });

  final DailyMacroTargets macros;
  final ConsumedTotals consumed;
  final AsyncValue<List<MealLog>> logsAsync;
  final Color textColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),

        // ── Calorie ring (eaten-only, plain ring without progress framing) ─
        Center(
          child: SizedBox(
            width: 100,
            height: 100,
            child: CustomPaint(
              painter: CalorieRingPainter(
                progress: macros.totalCalories > 0
                    ? (consumed.calories / macros.totalCalories).clamp(0.0, 1.0)
                    : 0.0,
                trackColor: AppColors.orange.withValues(alpha: 0.15),
                arcColor: AppColors.orange,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      consumed.calories.toString(),
                      style: const TextStyle(
                        fontFamily: 'Sansita',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ).copyWith(color: textColor),
                    ),
                    Text(
                      'kcal',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: textColor.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── C/P/F eaten values ─────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _MacroStat(
              label: 'Carbs',
              value: '${consumed.carbsG.toStringAsFixed(0)}g',
              color: kMacroColorCarbs,
              textColor: textColor,
            ),
            _MacroStat(
              label: 'Protein',
              value: '${consumed.proteinG.toStringAsFixed(0)}g',
              color: kMacroColorProtein,
              textColor: textColor,
            ),
            _MacroStat(
              label: 'Fat',
              value: '${consumed.fatG.toStringAsFixed(0)}g',
              color: kMacroColorFat,
              textColor: textColor,
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),
        Divider(color: textColor.withValues(alpha: 0.12)),
        const SizedBox(height: AppSpacing.sm),

        // ── From your log ──────────────────────────────────────────────
        Text(
          'From your log',
          style: AppTextStyles.bodySmall.copyWith(
            color: textColor.withValues(alpha: 0.55),
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        logsAsync.when(
          data: (logs) {
            if (logs.isEmpty) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  'No meals logged yet.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: textColor.withValues(alpha: 0.45),
                  ),
                ),
              );
            }
            return Column(
              children: logs
                  .map((log) => _LogEntryRow(log: log, textColor: textColor))
                  .toList(),
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

/// Small stat bubble for one macro (Eaten tab).
class _MacroStat extends StatelessWidget {
  const _MacroStat({
    required this.label,
    required this.value,
    required this.color,
    required this.textColor,
  });

  final String label;
  final String value;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.bodySmall
              .copyWith(color: textColor.withValues(alpha: 0.6)),
        ),
      ],
    );
  }
}

/// Single row in the "From your log" list inside the Eaten tab.
class _LogEntryRow extends StatelessWidget {
  const _LogEntryRow({required this.log, required this.textColor});

  final MealLog log;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final c = log.carbsG;
    final p = log.proteinG;
    final f = log.fatG;

    final parts = <TextSpan>[];
    const sep = TextSpan(
      text: ' · ',
      style: TextStyle(fontSize: 11, color: Colors.grey),
    );
    if (c != null) {
      parts.add(TextSpan(
        text: '${c.toStringAsFixed(0)}C',
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: kMacroColorCarbs),
      ));
    }
    if (p != null) {
      if (parts.isNotEmpty) parts.add(sep);
      parts.add(TextSpan(
        text: '${p.toStringAsFixed(0)}P',
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: kMacroColorProtein),
      ));
    }
    if (f != null) {
      if (parts.isNotEmpty) parts.add(sep);
      parts.add(TextSpan(
        text: '${f.toStringAsFixed(0)}F',
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: kMacroColorFat),
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              log.name,
              style: AppTextStyles.bodySmall.copyWith(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (log.calories != null) ...[
            const SizedBox(width: 8),
            Text(
              '${log.calories} kcal',
              style: AppTextStyles.bodySmall
                  .copyWith(color: textColor.withValues(alpha: 0.6)),
            ),
          ],
          if (parts.isNotEmpty) ...[
            const SizedBox(width: 6),
            RichText(text: TextSpan(children: parts)),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plan tab body — original content unchanged
// ---------------------------------------------------------------------------

class _PlanTabBody extends StatelessWidget {
  const _PlanTabBody({
    required this.macros,
    required this.showAttribution,
    required this.textColor,
    required this.isDark,
  });

  final DailyMacroTargets macros;
  final bool showAttribution;
  final Color textColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.lg),

        // Target kcal + C/P/F
        Center(
          child: Text(
            '${macros.totalCalories.round()} kcal target',
            style: const TextStyle(
              fontFamily: 'Sansita',
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ).copyWith(color: textColor),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _MacroStat(
              label: 'Carbs',
              value: '${macros.carbG.toStringAsFixed(0)}g',
              color: kMacroColorCarbs,
              textColor: textColor,
            ),
            _MacroStat(
              label: 'Protein',
              value: '${macros.protG.toStringAsFixed(0)}g',
              color: kMacroColorProtein,
              textColor: textColor,
            ),
            _MacroStat(
              label: 'Fat',
              value: '${macros.fatG.toStringAsFixed(0)}g',
              color: kMacroColorFat,
              textColor: textColor,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Three full macro bar rows ────────────────────────────
        _MacroBarRow(
          label: 'Carbs',
          eaten: macros.carbG,
          target: macros.carbG,
          color: kMacroColorCarbs,
        ),
        const SizedBox(height: AppSpacing.sm),
        _MacroBarRow(
          label: 'Protein',
          eaten: macros.protG,
          target: macros.protG,
          color: kMacroColorProtein,
        ),
        const SizedBox(height: AppSpacing.sm),
        _MacroBarRow(
          label: 'Fat',
          eaten: macros.fatG,
          target: macros.fatG,
          color: kMacroColorFat,
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Divider ──────────────────────────────────────────────
        Divider(color: textColor.withValues(alpha: 0.12)),
        const SizedBox(height: AppSpacing.lg),

        // ── Energy source breakdown ──────────────────────────────
        EnergySourceBreakdown(macros: macros),

        // ── Garmin attribution ───────────────────────────────────
        if (showAttribution) ...[
          const SizedBox(height: AppSpacing.lg),
          const GarminAttributionMessage(
            subject: 'Body composition and activity inputs',
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Individual macro bar row (reused in detail sheet)
// ---------------------------------------------------------------------------

class _MacroBarRow extends StatelessWidget {
  const _MacroBarRow({
    required this.label,
    required this.eaten,
    required this.target,
    required this.color,
  });

  final String label;
  final double eaten;
  final double target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    final ratio = target > 0 ? (eaten / target).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(color: textColor),
            ),
            Text(
              '${eaten.toStringAsFixed(0)} / ${target > 0 ? target.toStringAsFixed(0) : '—'}g',
              style: AppTextStyles.bodySmall.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Calorie ring painter (public — reused by MacroSummaryStrip)
// ---------------------------------------------------------------------------

class CalorieRingPainter extends CustomPainter {
  const CalorieRingPainter({
    required this.progress,
    required this.trackColor,
    required this.arcColor,
    this.strokeWidth = 8.0,
  });

  final double progress;
  final Color trackColor;
  final Color arcColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - strokeWidth / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Track
    paint.color = trackColor;
    canvas.drawCircle(center, radius, paint);

    // Arc
    if (progress > 0) {
      paint.color = arcColor;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // start at top
        2 * math.pi * progress,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CalorieRingPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.arcColor != arcColor;
}

// ---------------------------------------------------------------------------
// Garmin authoritative provider (mirrors daily_summary_card.dart)
// ---------------------------------------------------------------------------

/// True when Garmin body comp is currently authoritative for either the
/// user's weight or body fat.
final garminAuthoritativeForMacrosProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final profile = await ref.watch(currentUserProvider.future);
  if (profile == null) return false;

  final garmin = await ref.watch(
    garminLastBodyCompProvider(profile.id).future,
  );
  if (garmin == null) return false;

  final userWeightKg = profile.weightPounds * 0.453592;
  final weightAuthoritative = isGarminAuthoritativeForWeight(
    garmin: garmin,
    userWeightKg: userWeightKg,
    userUpdatedAt: profile.weightPoundsUpdatedAt,
  );
  final bodyFatAuthoritative = isGarminAuthoritativeForBodyFat(
    garmin: garmin,
    userBodyFatPct: profile.bodyFatPct,
    userUpdatedAt: profile.bodyFatPctUpdatedAt,
  );
  return weightAuthoritative || bodyFatAuthoritative;
});
