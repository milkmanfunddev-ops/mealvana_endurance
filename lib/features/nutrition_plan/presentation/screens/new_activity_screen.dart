import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../providers/new_activity_coordinator.dart';
import '../providers/running_input_controller.dart';
import '../providers/cycling_input_controller.dart';
import '../providers/swimming_input_controller.dart';
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
    // Activity type for tab selection
    this.activityType,
    // Cycling-specific parameters
    this.cyclingSpeedMph,
    this.cyclingTerrain,
    this.cyclingIndoorOutdoor,
    this.cyclingElevationGainFt,
    this.cyclingSessionGoal,
    // Swimming-specific parameters
    this.swimmingPacePer100mSeconds,
    this.swimmingPoolOrOpenWater,
    this.swimmingWaterTempC,
    // Shared parameters
    this.intensityTarget,
    this.timeBeforeMinutes,
  });

  final DateTime? initialDate;
  final double? initialDistance;
  final double? initialPace;
  final String? activityId;
  final String? eventId;

  /// Activity type for selecting the correct sport tab (e.g., 'running', 'cycling', 'swimming')
  final String? activityType;

  // Cycling-specific parameters
  final double? cyclingSpeedMph;
  final String? cyclingTerrain;
  final String? cyclingIndoorOutdoor;
  final int? cyclingElevationGainFt;
  final String? cyclingSessionGoal;

  // Swimming-specific parameters
  final int? swimmingPacePer100mSeconds;
  final String? swimmingPoolOrOpenWater;
  final double? swimmingWaterTempC;

  // Shared parameters
  final String? intensityTarget;
  final int? timeBeforeMinutes;

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

  /// Initialize form controllers with data from event/activity navigation
  ///
  /// When coming from an event or synced activity, pre-populate:
  /// - Sport tab based on activity type
  /// - Date/time from scheduled date
  /// - Sport-specific fields (distance, pace, etc.)
  void _initializeFromEventData() {
    final coordinator = ref.read(newActivityCoordinatorProvider.notifier);
    final coordinatorState = ref.read(newActivityCoordinatorProvider);

    // Select the appropriate sport tab based on activity type
    if (widget.activityType != null) {
      final sportTab = _getSportTabFromActivityType(widget.activityType!);
      if (sportTab != null && sportTab != coordinatorState.selectedTab) {
        DebugLogger.info('🏃 NEW ACTIVITY: Selecting ${widget.activityType} tab');
        coordinator.selectTab(sportTab);
      }
    }

    // Check if coordinator has default date (today) - only override if it's the default
    final now = DateTime.now();
    final isDefaultDate = coordinatorState.selectedDate.year == now.year &&
        coordinatorState.selectedDate.month == now.month &&
        coordinatorState.selectedDate.day == now.day;

    // Initialize date/time from event/activity
    if (widget.initialDate != null && isDefaultDate) {
      DebugLogger.info('🗓️ NEW ACTIVITY: Initializing date: ${widget.initialDate}');
      coordinator.updateDateTime(
        widget.initialDate!,
        TimeOfDay.fromDateTime(widget.initialDate!),
      );
    }

    // Initialize sport-specific controllers based on activity type
    final activityType = widget.activityType ?? 'running';
    switch (activityType) {
      case 'cycling':
        _initializeCyclingController();
        break;
      case 'swimming':
        _initializeSwimmingController();
        break;
      case 'running':
      default:
        _initializeRunningController();
        break;
    }

    if (widget.activityId != null || widget.eventId != null) {
      DebugLogger.info('🔗 NEW ACTIVITY: Linked to activityId: ${widget.activityId}, eventId: ${widget.eventId}');
    }

    // Trigger location fetch for the active sport tab
    // This is done via coordinator to ensure only ONE controller fetches at a time
    coordinator.fetchLocationForActiveTab();
  }

  /// Convert activity type string to SportTab enum
  SportTab? _getSportTabFromActivityType(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'running':
        return SportTab.running;
      case 'cycling':
        return SportTab.cycling;
      case 'swimming':
        return SportTab.swimming;
      default:
        return null;
    }
  }

  /// Initialize running controller with synced activity data
  void _initializeRunningController() {
    final controller = ref.read(runningInputControllerProvider.notifier);

    if (widget.initialDistance != null) {
      DebugLogger.info('📏 NEW ACTIVITY: Initializing distance: ${widget.initialDistance} miles');
      controller.updateDistance(widget.initialDistance!);
    }

    if (widget.initialPace != null) {
      DebugLogger.info('⏱️ NEW ACTIVITY: Initializing pace: ${widget.initialPace} min/mile');
      controller.updatePace(widget.initialPace!);
    }

    if (widget.timeBeforeMinutes != null) {
      controller.updatePreRunMinutes(widget.timeBeforeMinutes!);
    }
  }

  /// Initialize cycling controller with synced activity data
  void _initializeCyclingController() {
    final controller = ref.read(cyclingInputControllerProvider.notifier);

    if (widget.initialDistance != null) {
      DebugLogger.info('📏 NEW ACTIVITY: Initializing cycling distance: ${widget.initialDistance} miles');
      controller.updateDistance(widget.initialDistance!);
    }

    if (widget.cyclingSpeedMph != null) {
      DebugLogger.info('🚴 NEW ACTIVITY: Initializing cycling speed: ${widget.cyclingSpeedMph} mph');
      controller.updateSpeed(widget.cyclingSpeedMph!);
    }

    if (widget.timeBeforeMinutes != null) {
      controller.updatePreRideMinutes(widget.timeBeforeMinutes!);
    }
  }

  /// Initialize swimming controller with synced activity data
  void _initializeSwimmingController() {
    final controller = ref.read(swimmingInputControllerProvider.notifier);

    if (widget.initialDistance != null) {
      // Convert miles to meters for swimming
      final distanceMeters = (widget.initialDistance! * 1609.34).round();
      DebugLogger.info('📏 NEW ACTIVITY: Initializing swimming distance: $distanceMeters meters');
      controller.updateDistance(distanceMeters);
    }

    if (widget.swimmingPacePer100mSeconds != null) {
      DebugLogger.info('🏊 NEW ACTIVITY: Initializing swimming pace: ${widget.swimmingPacePer100mSeconds} sec/100m');
      controller.updatePace(widget.swimmingPacePer100mSeconds!);
    }

    if (widget.timeBeforeMinutes != null) {
      controller.updatePreSwimMinutes(widget.timeBeforeMinutes!);
    }
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
