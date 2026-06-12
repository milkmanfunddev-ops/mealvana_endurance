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
import '../providers/daily_macros_controller.dart';
import '../widgets/macro_summary_strip.dart';
import '../widgets/today_hero_card.dart';
import '../widgets/weekly_overview_chart.dart';

// ---------------------------------------------------------------------------
// Sizing constant for the permanent pinned strip
// ---------------------------------------------------------------------------

/// Fixed height of the pinned macro summary strip (no collapse, no expand).
/// Two lines: ring+kcal row (32 px ring + 12 sm + top/bottom padding) +
/// micro-bar row (4 px bar + text) + BaseCard vertical padding (12+12).
const double _kStripExtent = 92.0;

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
          // ── Calendar toggle row ───────────────────────────────────────────
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

    final hasMacros = state.dailyMacros != null;

    return CustomScrollView(
      slivers: [
        // ── Pre-strip static content (scrolls away) ───────────────────────
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

        // ── Macro summary strip — pinned fixed extent when targets exist ──
        if (hasMacros)
          SliverPersistentHeader(
            pinned: true,
            delegate: _FixedStripDelegate(
              state: state,
              ref: ref,
              isDark: isDark,
              onTrendsPressed: () => _showTrendsSheet(context, ref, state),
              onDetailPressed: () => _showDetailSheet(context, ref, state),
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

  // ── Macro detail sheet ────────────────────────────────────────────────────

  void _showDetailSheet(
    BuildContext context,
    WidgetRef ref,
    DailyMacrosState state,
  ) {
    final macros = state.dailyMacros!;
    final selectedDate = state.selectedDate;
    final dateStr =
        '${selectedDate.year}-'
        '${selectedDate.month.toString().padLeft(2, '0')}-'
        '${selectedDate.day.toString().padLeft(2, '0')}';

    // Read the consumed totals snapshot at the moment of tap.
    final consumed = ref
        .read(consumedTotalsForDateProvider(dateStr))
        .maybeWhen(data: (v) => v, orElse: () => const ConsumedTotals());

    final garminAuth = ref
        .read(garminAuthoritativeForMacrosProvider)
        .maybeWhen(data: (v) => v, orElse: () => false);

    final showAttribution =
        (macros.sources?.anyFromGarmin ?? false) || garminAuth;

    showMacroDetailSheet(
      context,
      macros: macros,
      consumed: consumed,
      showAttribution: showAttribution,
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
// Fixed-extent pinned strip delegate (no interpolation)
// ---------------------------------------------------------------------------

/// A [SliverPersistentHeaderDelegate] with min == max == [_kStripExtent].
///
/// Renders [MacroSummaryStrip] with a subtle bottom border when content
/// scrolls beneath the pinned header.
class _FixedStripDelegate extends SliverPersistentHeaderDelegate {
  _FixedStripDelegate({
    required this.state,
    required this.ref,
    required this.isDark,
    required this.onTrendsPressed,
    required this.onDetailPressed,
  });

  final DailyMacrosState state;
  final WidgetRef ref;
  final bool isDark;
  final VoidCallback onTrendsPressed;
  final VoidCallback onDetailPressed;

  @override
  double get minExtent => _kStripExtent;

  @override
  double get maxExtent => _kStripExtent;

  @override
  bool shouldRebuild(_FixedStripDelegate old) =>
      old.state != state || old.isDark != isDark;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final bg = isDark ? AppColors.blackberry : AppColors.cream;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    // `alignment` makes the Container expand to the full header extent — a
    // pinned SliverPersistentHeader child MUST fill maxExtent, otherwise the
    // sliver reports paintExtent (child height) < layoutExtent (extent) and
    // trips the SliverGeometry validity assert.
    return Container(
      color: bg,
      alignment: Alignment.center,
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
      child: Padding(
        padding: AppSpacing.screenPaddingHorizontal,
        child: MacroSummaryStrip(
          macros: state.dailyMacros!,
          onTrendsPressed: onTrendsPressed,
          onDetailPressed: onDetailPressed,
        ),
      ),
    );
  }
}
