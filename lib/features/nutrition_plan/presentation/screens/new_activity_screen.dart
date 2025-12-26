import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../providers/new_activity_coordinator.dart';
import '../providers/running_input_controller.dart';
import '../widgets/new_activity/shared/sport_selector.dart';
import '../widgets/new_activity/shared/new_activity_app_bar.dart';
import '../widgets/new_activity/shared/new_activity_hero_section.dart';
import '../widgets/new_activity/shared/new_activity_date_time_section.dart';
import '../widgets/new_activity/shared/new_activity_generate_button.dart';
import '../widgets/new_activity/running_tab_content.dart';
import '../widgets/new_activity/cycling_tab_content.dart';
import '../widgets/new_activity/swimming_tab_content.dart';
import '../../../../core/utils/debug_logger.dart';
import '../../../../shared/widgets/app_date_picker.dart';
import '../providers/macro_targets_controller.dart';
import '../../../../shared/providers/user_id_provider.dart';
import '../../../activities/application/activities_service.dart';
import '../../../activities/presentation/providers/activities_controller.dart';
import '../../../../../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../activities/domain/activity.dart' as domain;

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
///
/// Event Integration:
/// When navigating from an event (e.g., marathon), this screen receives:
/// - initialDate: The event date
/// - initialDistance: Race distance from event subtype (e.g., 26.2 for marathon)
/// - initialPace: Goal pace from event settings
/// - activityId: Existing activity ID if already created
/// - eventId: Event ID for linking nutrition plan back to event
class NewActivityScreen extends ConsumerStatefulWidget {
  const NewActivityScreen({
    super.key,
    this.initialDate,
    this.initialDistance,
    this.initialPace,
    this.activityId,
    this.eventId,
  });

  final DateTime? initialDate;
  final double? initialDistance;
  final double? initialPace;
  final String? activityId;
  final String? eventId;

  @override
  ConsumerState<NewActivityScreen> createState() => _NewActivityScreenState();
}

class _NewActivityScreenState extends ConsumerState<NewActivityScreen> {
  @override
  void initState() {
    super.initState();

    // Initialize controllers with event data after first frame
    // Using microtask to avoid modifying providers during build
    Future.microtask(() {
      _initializeFromEventData();
    });
  }

  @override
  void dispose() {
    // ⚠️ IMPORTANT: Cannot use ref.read() in dispose() - violates Riverpod safety
    // Draft cleanup is now handled by MacroTargetsController.ref.onDispose()
    // See: macro_targets_controller.dart for cleanup implementation
    super.dispose();
  }

  /// Initialize form controllers with data from event navigation
  ///
  /// When coming from an event (e.g., marathon race day), pre-populate:
  /// - Date/time from event date
  /// - Distance from event subtype (e.g., 26.2 miles for marathon)
  /// - Pace from event goal pace
  void _initializeFromEventData() {
    final coordinator = ref.read(newActivityCoordinatorProvider.notifier);
    final coordinatorState = ref.read(newActivityCoordinatorProvider);

    // Check if coordinator has default date (today) - only override if it's the default
    final now = DateTime.now();
    final isDefaultDate = coordinatorState.selectedDate.year == now.year &&
        coordinatorState.selectedDate.month == now.month &&
        coordinatorState.selectedDate.day == now.day;

    // Initialize date/time from event
    if (widget.initialDate != null && isDefaultDate) {
      DebugLogger.info('🗓️ NEW ACTIVITY: Initializing date from event: ${widget.initialDate}');
      coordinator.updateDateTime(
        widget.initialDate!,
        TimeOfDay.fromDateTime(widget.initialDate!),
      );
    }

    // Initialize running controller with event distance and pace
    // (Currently defaulting to running for events - can be extended for multi-sport)
    final runningController = ref.read(runningInputControllerProvider.notifier);

    if (widget.initialDistance != null) {
      DebugLogger.info('📏 NEW ACTIVITY: Initializing distance from event: ${widget.initialDistance} miles');
      runningController.updateDistance(widget.initialDistance!);
    }

    if (widget.initialPace != null) {
      DebugLogger.info('⏱️ NEW ACTIVITY: Initializing pace from event: ${widget.initialPace} min/mile');
      runningController.updatePace(widget.initialPace!);
    }

    if (widget.activityId != null || widget.eventId != null) {
      DebugLogger.info('🔗 NEW ACTIVITY: Linked to activityId: ${widget.activityId}, eventId: ${widget.eventId}');
    }

    // Trigger location fetch for the active sport tab
    // This is done via coordinator to ensure only ONE controller fetches at a time
    coordinator.fetchLocationForActiveTab();
  }

  @override
  Widget build(BuildContext context) {
    final coordinatorState = ref.watch(newActivityCoordinatorProvider);
    final coordinator = ref.read(newActivityCoordinatorProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      appBar: NewActivityAppBar(isDark: isDark),
      body: Column(
        children: [
          // Main scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),

                  // Sport Selector Buttons (center these)
                  const Center(child: SportSelector()),

                  const SizedBox(height: 24),

                  // Hero Image Section (center this)
                  NewActivityHeroSection(
                    heroImagePath: coordinator.getHeroImagePath(),
                  ),

                  const SizedBox(height: 24),

                  // Date and Time Section (center this)
                  NewActivityDateTimeSection(
                    selectedDate: coordinatorState.selectedDate,
                    selectedTime: coordinatorState.selectedTime,
                    onEditTapped: () => _showDateTimePicker(coordinatorState, coordinator),
                    isDark: isDark,
                  ),

                  const SizedBox(height: 32),

                  // Sport-specific form fields (full width)
                  _buildFormFields(coordinatorState),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),

          // Generate Button (fixed at bottom)
          NewActivityGenerateButton(
            isGenerating: coordinatorState.isGenerating,
            onPressed: () => _handleGeneratePlan(coordinator),
          ),
        ],
      ),
    );
  }

  /// Handles the Generate Plan button press
  ///
  /// Triggers macro generation through the coordinator and navigates
  /// to the adjust macros screen on success, or shows error snackbar on failure
  Future<void> _handleGeneratePlan(NewActivityCoordinator coordinator) async {
    try {
      DebugLogger.info('🎯 NEW ACTIVITY: Starting macro generation from UI...');
      DebugLogger.info('🔗 NEW ACTIVITY: activityId=${widget.activityId}, eventId=${widget.eventId}');
      await coordinator.generateMacros(
        activityId: widget.activityId,
        eventId: widget.eventId,
      );
      DebugLogger.info('✅ NEW ACTIVITY: Coordinator generateMacros completed');

      // Coordinator now waits for state to update - no need for manual checks
      if (!mounted) return;

      DebugLogger.info('🚀 NEW ACTIVITY: Navigating to adjust-macros screen');
      context.pushNamed('adjust-macros');
    } catch (e) {
      DebugLogger.error('❌ NEW ACTIVITY: Error in macro generation flow: $e');
      if (!mounted) return;

      MealvanaSnackbar.showError(context, 'Error generating plan: $e');
    }
  }

  /// Show different sport-specific form content based on selected tab
  Widget _buildFormFields(NewActivityCoordinatorState coordinatorState) {
    switch (coordinatorState.selectedTab) {
      case SportTab.running:
        return const RunningTabContent();
      case SportTab.cycling:
        return const CyclingTabContent();
      case SportTab.swimming:
        return const SwimmingTabContent();
    }
  }

  /// Show date and time picker dialogs
  ///
  /// First shows date picker, then if a date is selected, shows time picker.
  /// Updates coordinator state with both date and time when complete.
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
}
