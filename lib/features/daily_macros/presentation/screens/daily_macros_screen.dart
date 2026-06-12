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
import '../../../integrations/presentation/widgets/garmin_connect_banner.dart';
import '../providers/daily_macros_controller.dart';
import '../widgets/today_hero_card.dart';
import '../widgets/weekly_overview_chart.dart';

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
          // Calendar toggle + trends button row
          Row(
            children: [
              Expanded(
                child: CalendarViewToggle(
                  selectedMode: calendarMode,
                  onModeChanged: (mode) {
                    ref.read(calendarViewProvider.notifier).setView(mode);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  key: const ValueKey('nutrition_diary.trends_button'),
                  icon: Icon(
                    Icons.bar_chart,
                    size: 20,
                    color: isDark ? AppColors.cream : AppColors.blackberry,
                  ),
                  onPressed: () {
                    final macrosState =
                        ref.read(dailyMacrosControllerProvider).value;
                    if (macrosState != null) {
                      _showTrendsSheet(context, ref, macrosState);
                    }
                  },
                  tooltip: 'Weekly Trends',
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Calendar widget (week or month) — shares state with Activities tab
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
          // Content area (scrollable)
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

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    DailyMacrosState state,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    return SingleChildScrollView(
      padding: AppSpacing.screenPaddingHorizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),

          // Page title (below calendar, in scrollable area)
          Text(
            key: const ValueKey('nutrition_diary.heading'),
            'Nutrition Diary',
            style: AppTextStyles.sectionTitle.copyWith(
              color: textColor.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Garmin connect banner (self-hides when dismissed or already connected)
          const GarminConnectBanner(),
          const SizedBox(height: AppSpacing.sm),

          // Daily hero card + meal log
          if (state.dailyMacros != null) ...[
            TodayHeroCard(macros: state.dailyMacros!),
            const SizedBox(height: AppSpacing.lg),

            // Today's meal log
            TodayLogSection(selectedDate: state.selectedDate),
          ] else if (state.calculationError != null) ...[
            _buildCalculationErrorState(context, ref, state.calculationError!),
          ] else ...[
            _buildEmptyState(context),
          ],

          // Bottom padding for FAB clearance
          const SizedBox(height: 100),
        ],
      ),
    );
  }

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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
      },
    );
  }

  DateTime _getStartOfWeek(DateTime date) {
    // Sunday-start (matches calendar_week_view_kyle.dart)
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: date.weekday % 7));
  }
}
