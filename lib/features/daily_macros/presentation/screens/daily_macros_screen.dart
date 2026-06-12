import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../calendar/presentation/providers/calendar_view_provider.dart';
import '../../../calendar/presentation/widgets/calendar_view_toggle.dart';
import '../../../calendar/presentation/widgets/calendar_week_view_kyle.dart';
import '../../../calendar/presentation/widgets/calendar_month_view_kyle.dart';
import '../../../calendar/presentation/providers/calendar_selected_date_provider.dart';
import '../../../meal_logging/presentation/widgets/today_log_section.dart';
import '../../../meal_logging/presentation/providers/meal_log_providers.dart';
import '../../../meal_logging/domain/consumed_totals.dart';
import '../../../integrations/presentation/widgets/garmin_connect_banner.dart';
import '../../../integrations/presentation/providers/integrations_providers.dart';
import '../../../auth/application/auth_service.dart';
import '../../domain/daily_macro_targets.dart';
import '../providers/daily_macros_controller.dart';
import '../widgets/today_hero_card.dart';
import '../widgets/weekly_overview_chart.dart';

// ---------------------------------------------------------------------------
// Sizing constants for the collapsing persistent header
// ---------------------------------------------------------------------------

/// Maximum height of the pinned macro summary header (expanded state).
/// Ring (100) + md gap + 3 bars (≈78) + md gap + trigger row (20) +
/// BaseCard padding top+bottom (16+16) + horizontal padding wrapper (sm*2).
const double _kHeaderMaxExtent = 320.0;

/// Minimum height of the slim collapsed bar (pinned under app's top edge).
const double _kHeaderMinExtent = 60.0;

/// Fraction of collapse at which the expanded content is fully faded out
/// and the slim bar is fully visible.
const double _kCollapseFadeThreshold = 0.60;

// ---------------------------------------------------------------------------
// DailyMacrosScreen
// ---------------------------------------------------------------------------

class DailyMacrosScreen extends ConsumerWidget {
  const DailyMacrosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final macrosAsync = ref.watch(dailyMacrosControllerProvider);
    final selectedDate = ref.watch(calendarSelectedDateProvider);
    final calendarMode = ref.watch(calendarViewProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 12),
          // ── Calendar toggle row (no trends icon here — moved to header) ──
          CalendarViewToggle(
            selectedMode: calendarMode,
            onModeChanged: (mode) {
              ref.read(calendarViewProvider.notifier).setView(mode);
            },
          ),
          const SizedBox(height: 8),
          // ── Calendar widget ───────────────────────────────────────────────
          if (calendarMode == CalendarViewMode.week)
            CalendarWeekViewKyle(
              compact: true,
              selectedDate: selectedDate,
              onDateSelected: (date) {
                ref.read(calendarSelectedDateProvider.notifier).setDate(date);
              },
              dayIndicators: const {},
            )
          else
            CalendarMonthViewKyle(
              selectedDate: selectedDate,
              onDateSelected: (date) {
                ref.read(calendarSelectedDateProvider.notifier).setDate(date);
              },
              dayIndicators: const {},
            ),
          // ── Scrollable content area ───────────────────────────────────────
          Expanded(
            child: macrosAsync.when(
              data: (state) => _buildContent(context, ref, state),
              loading: () => _buildLoadingState(context),
              error: (error, stack) => _buildErrorState(context, ref, error),
            ),
          ),
        ],
      ),
    );
  }

  // ── Content with CustomScrollView ────────────────────────────────────────

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    DailyMacrosState state,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    // Only use collapsing header when we have macro targets.
    final hasMacros = state.dailyMacros != null;

    return CustomScrollView(
      slivers: [
        // ── Pre-hero static content (scrolls away) ────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: AppSpacing.screenPaddingHorizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.md),
                Text(
                  key: const ValueKey('nutrition_diary.heading'),
                  'Nutrition Diary',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: textColor.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const GarminConnectBanner(),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),

        // ── Macro summary — collapsing when targets exist ─────────────────
        if (hasMacros)
          SliverPersistentHeader(
            pinned: true,
            delegate: _MacroHeaderDelegate(
              state: state,
              ref: ref,
              isDark: isDark,
              onTrendsPressed: () {
                _showTrendsSheet(context, ref, state);
              },
              onBreakdownPressed: () {
                final garminAuth = ref
                    .read(_garminAuthoritativeProviderForScreen)
                    .maybeWhen(data: (v) => v, orElse: () => false);
                final showAttribution =
                    (state.dailyMacros!.sources?.anyFromGarmin ?? false) ||
                    garminAuth;
                showBreakdownSheet(
                  context,
                  macros: state.dailyMacros!,
                  showAttribution: showAttribution,
                );
              },
            ),
          )
        else if (state.calculationError != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: AppSpacing.screenPaddingHorizontal,
              child: _buildCalculationErrorState(
                context,
                ref,
                state.calculationError!,
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: Padding(
              padding: AppSpacing.screenPaddingHorizontal,
              child: _buildEmptyState(context),
            ),
          ),

        // ── Meal log ──────────────────────────────────────────────────────
        if (hasMacros) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: AppSpacing.screenPaddingHorizontal,
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  TodayLogSection(selectedDate: state.selectedDate),
                ],
              ),
            ),
          ),
        ],

        // ── Bottom clearance for Jade avatar + nav pill ───────────────────
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  // ── Static states ─────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    return BaseCard(
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.lg),
          FaIcon(
            FontAwesomeIcons.chartPie,
            size: 48,
            color: AppColors.electrolyte.withValues(alpha: 0.4),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No macro targets yet',
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Add activities to your calendar to see daily nutrition targets, or complete your nutrition profile in Settings.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          KyleSecondaryButton(
            text: 'Set Up Nutrition Profile',
            onPressed: () => context.push('/settings/nutrition-profile'),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildCalculationErrorState(
    BuildContext context,
    WidgetRef ref,
    String message,
  ) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              FaIcon(
                FontAwesomeIcons.triangleExclamation,
                size: 18,
                color: AppColors.dragonfruit,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Macros unavailable',
                style: AppTextStyles.subtitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              KyleSecondaryButton(
                text: 'Retry',
                onPressed: () => ref.invalidate(dailyMacrosControllerProvider),
              ),
              const SizedBox(width: AppSpacing.sm),
              KyleSecondaryButton(
                text: 'Open Preferences',
                onPressed: () => context.push('/settings/preferences'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.electrolyte),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(
            FontAwesomeIcons.circleExclamation,
            color: AppColors.dragonfruit,
            size: 48,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Error loading nutrition data',
            style: AppTextStyles.subtitle.copyWith(
              color: AppColors.dragonfruit,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          KyleSecondaryButton(
            text: 'Retry',
            onPressed: () => ref.invalidate(dailyMacrosControllerProvider),
          ),
        ],
      ),
    );
  }

  // ── Weekly Trends bottom sheet ─────────────────────────────────────────

  void _showTrendsSheet(
    BuildContext context,
    WidgetRef ref,
    DailyMacrosState state,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bg = isDark ? AppColors.blackberry : AppColors.cream;
        final textColor = isDark ? AppColors.cream : AppColors.blackberry;
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.md,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Weekly Trends',
                style: AppTextStyles.pageTitle.copyWith(color: textColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              WeeklyOverviewChart(
                weeklyMacros: state.weeklyMacros,
                startOfWeek: _getStartOfWeek(state.selectedDate),
                initiallyExpanded: true,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
      },
    );
  }

  DateTime _getStartOfWeek(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: date.weekday % 7));
  }
}

// ---------------------------------------------------------------------------
// Screen-local Garmin auth provider (same logic as in TodayHeroCard,
// lifted here so _MacroHeaderDelegate can read it without a ConsumerWidget)
// ---------------------------------------------------------------------------

final _garminAuthoritativeProviderForScreen =
    FutureProvider.autoDispose<bool>((ref) async {
  final profile = await ref.watch(currentUserProvider.future);
  if (profile == null) return false;
  final garmin =
      await ref.watch(garminLastBodyCompProvider(profile.id).future);
  if (garmin == null) return false;
  final userWeightKg = profile.weightPounds * 0.453592;
  return isGarminAuthoritativeForWeight(
        garmin: garmin,
        userWeightKg: userWeightKg,
        userUpdatedAt: profile.weightPoundsUpdatedAt,
      ) ||
      isGarminAuthoritativeForBodyFat(
        garmin: garmin,
        userBodyFatPct: profile.bodyFatPct,
        userUpdatedAt: profile.bodyFatPctUpdatedAt,
      );
});

// ---------------------------------------------------------------------------
// Collapsing macro header delegate
// ---------------------------------------------------------------------------

/// [SliverPersistentHeaderDelegate] that renders the macro summary in two
/// states:
///
/// * **Expanded** (shrinkOffset near 0): Full [TodayHeroCard] layout — ring,
///   fueling target text, three macro bars, "How these targets are set"
///   trigger.
/// * **Collapsed** (shrinkOffset near maxExtent − minExtent): A slim 60 px
///   bar showing a small ring dot, "X / Y kcal" text, three coloured
///   macro-gram labels, and the trends icon on the right.
///
/// Interpolation: expanded content fades out and collapsed content fades in
/// past [_kCollapseFadeThreshold] of the total shrink range.
class _MacroHeaderDelegate extends SliverPersistentHeaderDelegate {
  _MacroHeaderDelegate({
    required this.state,
    required this.ref,
    required this.isDark,
    required this.onTrendsPressed,
    required this.onBreakdownPressed,
  });

  final DailyMacrosState state;
  final WidgetRef ref;
  final bool isDark;
  final VoidCallback onTrendsPressed;
  final VoidCallback onBreakdownPressed;

  @override
  double get maxExtent => _kHeaderMaxExtent;

  @override
  double get minExtent => _kHeaderMinExtent;

  @override
  bool shouldRebuild(_MacroHeaderDelegate old) =>
      old.state != state || old.isDark != isDark;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final macros = state.dailyMacros!;
    final totalShrink = maxExtent - minExtent;
    // collapseRatio: 0.0 = fully expanded, 1.0 = fully collapsed
    final collapseRatio = (shrinkOffset / totalShrink).clamp(0.0, 1.0);

    // Opacity curves: expanded fades out after threshold, slim fades in.
    final expandedOpacity =
        (1.0 - (collapseRatio / _kCollapseFadeThreshold)).clamp(0.0, 1.0);
    final slimOpacity =
        ((collapseRatio - _kCollapseFadeThreshold) /
            (1.0 - _kCollapseFadeThreshold))
            .clamp(0.0, 1.0);

    final bg = isDark ? AppColors.blackberry : AppColors.cream;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    // We always need the consumed totals to drive both layouts.
    final selectedDate = state.selectedDate;
    final dateStr =
        '${selectedDate.year}-'
        '${selectedDate.month.toString().padLeft(2, '0')}-'
        '${selectedDate.day.toString().padLeft(2, '0')}';
    final totalsAsync = ref.watch(consumedTotalsForDateProvider(dateStr));
    final consumed = totalsAsync.maybeWhen(
      data: (v) => v,
      orElse: () => const ConsumedTotals(),
    );

    final targetCals = macros.totalCalories;
    final progress = targetCals > 0
        ? (consumed.calories / targetCals).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      color: bg,
      // Subtle bottom shadow/border when pinned so log rows scrolling under
      // the header look clean.
      foregroundDecoration: overlapsContent
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: textColor.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
            )
          : null,
      child: Stack(
        children: [
          // ── EXPANDED layout ───────────────────────────────────────────
          // ClipRect + OverflowBox: while the header shrinks, the card keeps
          // its intrinsic height and is clipped instead of overflowing (the
          // sliver lays the child out at the *current* extent, which is
          // smaller than the card for most of the collapse travel).
          if (expandedOpacity > 0.0)
            Opacity(
              opacity: expandedOpacity,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  maxHeight: _kHeaderMaxExtent,
                  child: Padding(
                    padding: AppSpacing.screenPaddingHorizontal,
                    child: TodayHeroCard(
                      macros: macros,
                      onTrendsPressed: onTrendsPressed,
                      onBreakdownPressed: onBreakdownPressed,
                    ),
                  ),
                ),
              ),
            ),

          // ── COLLAPSED slim bar ────────────────────────────────────────
          if (slimOpacity > 0.0)
            Opacity(
              opacity: slimOpacity,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                child: _SlimMacroBar(
                  consumed: consumed,
                  macros: macros,
                  progress: progress,
                  textColor: textColor,
                  isDark: isDark,
                  onTrendsPressed: onTrendsPressed,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slim collapsed bar widget
// ---------------------------------------------------------------------------

/// The compact single-row bar shown when the macro header is fully collapsed.
///
/// Layout:  [small ring] [X / Y kcal]  [C 144  P 89  F 47]  [chart icon]
class _SlimMacroBar extends StatelessWidget {
  const _SlimMacroBar({
    required this.consumed,
    required this.macros,
    required this.progress,
    required this.textColor,
    required this.isDark,
    required this.onTrendsPressed,
  });

  final ConsumedTotals consumed;
  final DailyMacroTargets macros;
  final double progress;
  final Color textColor;
  final bool isDark;
  final VoidCallback onTrendsPressed;

  @override
  Widget build(BuildContext context) {
    final targetCals = macros.totalCalories;

    return SizedBox(
      height: _kHeaderMinExtent,
      child: Row(
        children: [
          // Small calorie ring (28px)
          SizedBox(
            width: 28,
            height: 28,
            child: CustomPaint(
              painter: CalorieRingPainter(
                progress: progress,
                trackColor: AppColors.orange.withValues(alpha: 0.2),
                arcColor: AppColors.orange,
                strokeWidth: 4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Consumed / target — neutral fueling framing, no "left"/"over".
          Text(
            '${consumed.calories} / ${targetCals.round()} kcal',
            style: AppTextStyles.bodySmall.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          // Three macro dots with gram labels
          _MacroDot(
            label: 'C',
            grams: consumed.carbsG,
            color: kMacroColorCarbs,
            textColor: textColor,
          ),
          const SizedBox(width: 8),
          _MacroDot(
            label: 'P',
            grams: consumed.proteinG,
            color: kMacroColorProtein,
            textColor: textColor,
          ),
          const SizedBox(width: 8),
          _MacroDot(
            label: 'F',
            grams: consumed.fatG,
            color: kMacroColorFat,
            textColor: textColor,
          ),
          const Spacer(),
          // Trends icon at the right end of the slim bar
          GestureDetector(
            onTap: onTrendsPressed,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Icon(
                Icons.bar_chart,
                size: 18,
                color: textColor.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Coloured dot + letter label + gram count for the slim bar.
class _MacroDot extends StatelessWidget {
  const _MacroDot({
    required this.label,
    required this.grams,
    required this.color,
    required this.textColor,
  });

  final String label;
  final double grams;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          '$label ${grams.toStringAsFixed(0)}',
          style: AppTextStyles.bodySmall.copyWith(
            color: textColor.withValues(alpha: 0.75),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
