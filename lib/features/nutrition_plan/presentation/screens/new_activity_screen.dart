import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/kyle_design/buttons/primary_button.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../providers/new_activity_coordinator.dart';
import '../widgets/new_activity/shared/sport_selector.dart';
import '../widgets/new_activity/running_tab_content.dart';
import '../widgets/new_activity/cycling_tab_content.dart';
import '../widgets/new_activity/swimming_tab_content.dart';
import '../../../../core/utils/debug_logger.dart';
import '../../../../shared/widgets/app_date_picker.dart';

/// New Activity Screen - Kyle's Unified Design
///
/// Single scrollable view with sport selector buttons at top
/// All form fields visible in one column (no tabs)
///
/// Features:
/// - Sport selector buttons (Running/Biking/Swimming)
/// - Dynamic hero image with pink star overlay
/// - Date/Time side-by-side with Edit link
/// - All sport-specific fields in single scroll
/// - Forecast link that navigates to weather screen
/// - Generate button at bottom
class NewActivityScreen extends ConsumerStatefulWidget {
  const NewActivityScreen({
    super.key,
    this.initialDate,
  });

  final DateTime? initialDate;

  @override
  ConsumerState<NewActivityScreen> createState() => _NewActivityScreenState();
}

class _NewActivityScreenState extends ConsumerState<NewActivityScreen> {
  @override
  Widget build(BuildContext context) {
    final coordinatorState = ref.watch(newActivityCoordinatorProvider);
    final coordinator = ref.read(newActivityCoordinatorProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      appBar: _buildAppBar(context, isDark),
      body: Column(
        children: [
          // Main scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.md),

                  // Sport Selector Buttons (center these)
                  const Center(child: SportSelector()),

                  const SizedBox(height: AppSpacing.lg),

                  // Hero Image Section (center this)
                  _buildHeroSection(coordinator, isDark),

                  const SizedBox(height: AppSpacing.lg),

                  // Date and Time Section (center this)
                  _buildDateTimeSection(coordinatorState, coordinator, isDark),

                  const SizedBox(height: AppSpacing.xl),

                  // Sport-specific form fields (full width)
                  _buildFormFields(coordinatorState),

                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),

          // Generate Button (fixed at bottom)
          _buildGenerateButton(coordinatorState, coordinator, isDark),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      centerTitle: true,
      title: Text(
        'Create New Activity Plan',
        style: AppTextStyles.sectionTitle.copyWith(
          color: isDark ? AppColors.cream : AppColors.blackberry,
        ),
      ),
      leading: Container(
        margin: const EdgeInsets.only(left: AppSpacing.md),
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.cream.withValues(alpha: 0.1)
                  : AppColors.blackberry.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                FontAwesomeIcons.arrowLeft,
                size: 16,
                color: isDark ? AppColors.cream : AppColors.blackberry,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(NewActivityCoordinator coordinator, bool isDark) {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Hero image
          Image.asset(
            coordinator.getHeroImagePath(),
            height: 180,
            fit: BoxFit.contain,
          ),

          // Pink star overlay
          // TODO: Uncomment when Vector.png is extracted from Figma
          // Positioned(
          //   top: 0,
          //   right: 60,
          //   child: Image.asset(
          //     'assets/images/Vector.png',
          //     width: 80,
          //     height: 80,
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildDateTimeSection(
    NewActivityCoordinatorState coordinatorState,
    NewActivityCoordinator coordinator,
    bool isDark,
  ) {
    // Format date: "Nov 9, 2025"
    final dateStr =
        '${_getMonthName(coordinatorState.selectedDate)} ${coordinatorState.selectedDate.day}, ${coordinatorState.selectedDate.year}';

    // Format time: "12:00 pm"
    final hour = coordinatorState.selectedTime.hourOfPeriod == 0
        ? 12
        : coordinatorState.selectedTime.hourOfPeriod;
    final minute = coordinatorState.selectedTime.minute
        .toString()
        .padLeft(2, '0');
    final period = coordinatorState.selectedTime.period == DayPeriod.am ? 'am' : 'pm';
    final timeStr = '$hour:$minute $period';

    return Column(
      children: [
        // Date and Time side-by-side
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // DATE section
            Column(
              children: [
                Text(
                  'DATE',
                  style: AppTextStyles.smallLabel.copyWith(
                    color: isDark ? AppColors.cream : AppColors.blackberry,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  dateStr,
                  style: AppTextStyles.dataNumber.copyWith(
                    color: isDark ? AppColors.cream : AppColors.blackberry,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),

            const SizedBox(width: AppSpacing.xxl),

            // TIME section
            Column(
              children: [
                Text(
                  'TIME',
                  style: AppTextStyles.smallLabel.copyWith(
                    color: isDark ? AppColors.cream : AppColors.blackberry,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  timeStr,
                  style: AppTextStyles.dataNumber.copyWith(
                    color: isDark ? AppColors.cream : AppColors.blackberry,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.sm),

        // Edit link (centered)
        GestureDetector(
          onTap: () => _showDateTimePicker(coordinatorState, coordinator),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FontAwesomeIcons.penToSquare,
                size: 14,
                color: AppColors.dragonfruit,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Edit',
                style: AppTextStyles.smallLabel.copyWith(
                  color: AppColors.dragonfruit,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields(NewActivityCoordinatorState coordinatorState) {
    // Show different content based on selected sport
    switch (coordinatorState.selectedTab) {
      case SportTab.running:
        return const RunningTabContent();
      case SportTab.cycling:
        return const CyclingTabContent();
      case SportTab.swimming:
        return const SwimmingTabContent();
    }
  }

  Widget _buildGenerateButton(
    NewActivityCoordinatorState coordinatorState,
    NewActivityCoordinator coordinator,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: AppSpacing.lg),
      child: KylePrimaryButton(
        text: 'Generate Plan',
        onPressed: coordinatorState.isGenerating
            ? null
            : () async {
                try {
                  DebugLogger.info('🎯 NEW ACTIVITY: Starting macro generation from UI...');
                  await coordinator.generateMacros();
                  DebugLogger.info('✅ NEW ACTIVITY: Coordinator generateMacros completed');

                  // Coordinator now waits for state to update - no need for manual checks
                  if (!mounted) return;

                  DebugLogger.info('🚀 NEW ACTIVITY: Navigating to adjust-macros screen');
                  context.pushNamed('adjust-macros');
                } catch (e) {
                  DebugLogger.error('❌ NEW ACTIVITY: Error in macro generation flow: $e');
                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error generating plan: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
        isLoading: coordinatorState.isGenerating,
      ),
    );
  }

  void _showDateTimePicker(
    NewActivityCoordinatorState state,
    NewActivityCoordinator coordinator,
  ) async {
    final date = await showAppDatePicker(
      context: context,
      initialDate: state.selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: state.selectedTime,
      );

      if (time != null) {
        coordinator.updateDateTime(date, time);
      }
    }
  }

  String _getMonthName(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[date.month - 1];
  }
}
