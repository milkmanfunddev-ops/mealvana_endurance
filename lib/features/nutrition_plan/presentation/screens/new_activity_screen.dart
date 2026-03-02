import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/new_activity_coordinator.dart';
import '../providers/running_input_controller.dart';
import '../providers/cycling_input_controller.dart';
import '../providers/swimming_input_controller.dart';
import '../providers/brick_input_controller.dart';
import '../../../activities/data/activities_repository.dart';
import '../../../../shared/providers/user_id_provider.dart';
import '../widgets/new_activity/shared/sport_selector.dart';
import '../widgets/new_activity/shared/new_activity_app_bar.dart';
import '../widgets/new_activity/shared/new_activity_hero_section.dart';
import '../widgets/new_activity/shared/new_activity_date_time_section.dart';
import '../widgets/new_activity/shared/new_activity_generate_button.dart';
import '../widgets/new_activity/running_tab_content.dart';
import '../widgets/new_activity/cycling_tab_content.dart';
import '../widgets/new_activity/swimming_tab_content.dart';
import '../widgets/new_activity/brick/brick_tab_content.dart';
import '../../../../core/utils/debug_logger.dart';
import '../../../../shared/widgets/app_date_picker.dart';
import '../../../../../../../../../shared/widgets/kyle_design/kyle_design.dart';

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
    this.forUserId, // NEW: If provided, create activity for this user (coach creating for athlete)
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
    // Brick event subtype distances (from triathlon/duathlon/multisport events)
    this.brickSwimDistanceMeters,
    this.brickBikeDistanceMiles,
    this.brickRunDistanceMiles,
  });

  final DateTime? initialDate;
  final double? initialDistance;
  final double? initialPace;
  final String? activityId;
  final String? eventId;
  final String?
  forUserId; // NEW: Target athlete user ID (when coach is creating for athlete)

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

  // Brick event subtype distances (from triathlon/duathlon/multisport events)
  final double? brickSwimDistanceMeters;
  final double? brickBikeDistanceMiles;
  final double? brickRunDistanceMiles;

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
        DebugLogger.info(
          '🏃 NEW ACTIVITY: Selecting ${widget.activityType} tab',
        );
        coordinator.selectTab(sportTab);
      }
    }

    // Only override coordinator date/time when it is still at fresh defaults.
    final defaultDateTime = defaultNewActivityDateTime();
    final isDefaultDate = _isSameDay(
      coordinatorState.selectedDate,
      defaultDateTime,
    );

    // Initialize date/time from event/activity
    if (widget.initialDate != null && isDefaultDate) {
      final resolvedDateTime = _resolveInitialDateTime(widget.initialDate!);
      DebugLogger.info(
        '🗓️ NEW ACTIVITY: Initializing date/time: $resolvedDateTime',
      );
      coordinator.updateDateTime(
        resolvedDateTime,
        TimeOfDay.fromDateTime(resolvedDateTime),
      );
    } else if (widget.initialDate == null) {
      // Propagate default coordinator date/time into sport controllers on first load.
      coordinator.updateDateTime(
        coordinatorState.selectedDate,
        coordinatorState.selectedTime,
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
      case 'brick':
        _initializeBrickController();
        break;
      case 'running':
      default:
        _initializeRunningController();
        break;
    }

    if (widget.activityId != null || widget.eventId != null) {
      DebugLogger.info(
        '🔗 NEW ACTIVITY: Linked to activityId: ${widget.activityId}, eventId: ${widget.eventId}',
      );
    }

    // Trigger location fetch for the active sport tab
    // This is done via coordinator to ensure only ONE controller fetches at a time
    coordinator.fetchLocationForActiveTab();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _resolveInitialDateTime(DateTime initialDate) {
    final now = DateTime.now();
    final minimumDateTime = defaultNewActivityDateTime(now);
    final hasLinkedSource = widget.activityId != null || widget.eventId != null;
    final hasExplicitTime = initialDate.hour != 0 || initialDate.minute != 0;

    if (hasLinkedSource) {
      return initialDate;
    }

    if (_isSameDay(initialDate, now)) {
      if (!hasExplicitTime || initialDate.isBefore(minimumDateTime)) {
        return minimumDateTime;
      }
      return initialDate;
    }

    if (!hasExplicitTime) {
      return DateTime(
        initialDate.year,
        initialDate.month,
        initialDate.day,
        7,
        0,
      );
    }

    return initialDate;
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
      case 'brick':
        return SportTab.brick;
      default:
        return null;
    }
  }

  /// Initialize running controller with synced activity data
  void _initializeRunningController() {
    final controller = ref.read(runningInputControllerProvider.notifier);

    if (widget.initialDistance != null) {
      DebugLogger.info(
        '📏 NEW ACTIVITY: Initializing distance: ${widget.initialDistance} miles',
      );
      controller.updateDistance(widget.initialDistance!);
    }

    if (widget.initialPace != null) {
      DebugLogger.info(
        '⏱️ NEW ACTIVITY: Initializing pace: ${widget.initialPace} min/mile',
      );
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
      DebugLogger.info(
        '📏 NEW ACTIVITY: Initializing cycling distance: ${widget.initialDistance} miles',
      );
      controller.updateDistance(widget.initialDistance!);
    }

    if (widget.cyclingSpeedMph != null) {
      DebugLogger.info(
        '🚴 NEW ACTIVITY: Initializing cycling speed: ${widget.cyclingSpeedMph} mph',
      );
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
      DebugLogger.info(
        '📏 NEW ACTIVITY: Initializing swimming distance: $distanceMeters meters',
      );
      controller.updateDistance(distanceMeters);
    }

    if (widget.swimmingPacePer100mSeconds != null) {
      DebugLogger.info(
        '🏊 NEW ACTIVITY: Initializing swimming pace: ${widget.swimmingPacePer100mSeconds} sec/100m',
      );
      controller.updatePace(widget.swimmingPacePer100mSeconds!);
    }

    if (widget.timeBeforeMinutes != null) {
      controller.updatePreSwimMinutes(widget.timeBeforeMinutes!);
    }
  }

  /// Initialize brick controller from existing brick activity or event subtype distances
  ///
  /// Priority:
  /// 1. If activityId exists → load existing brick metadata
  /// 2. If event subtype distances exist → pre-populate from event (triathlon/duathlon)
  /// 3. Otherwise → start fresh with defaults
  void _initializeBrickController() {
    if (widget.activityId != null) {
      DebugLogger.info(
        '🧱 NEW ACTIVITY: Loading existing brick activity: ${widget.activityId}',
      );
      _loadExistingBrickActivity();
      return;
    }

    // Check if we have event subtype distances to pre-populate
    final hasEventDistances = widget.brickSwimDistanceMeters != null ||
        widget.brickBikeDistanceMiles != null ||
        widget.brickRunDistanceMiles != null;

    if (hasEventDistances) {
      DebugLogger.info(
        '🧱 NEW ACTIVITY: Initializing brick from event subtype distances',
      );
      final brickController = ref.read(brickInputControllerProvider.notifier);
      brickController.initializeFromEventSubtype(
        swimMeters: widget.brickSwimDistanceMeters,
        bikeMiles: widget.brickBikeDistanceMiles,
        runMiles: widget.brickRunDistanceMiles,
      );
      return;
    }

    DebugLogger.info(
      '🧱 NEW ACTIVITY: No activityId or event distances for brick - starting fresh',
    );
  }

  /// Load existing brick activity data and populate the form
  Future<void> _loadExistingBrickActivity() async {
    try {
      // Get current user ID
      final userId = await ref.read(userIdProvider.future);

      final repository = ref.read(activitiesRepositoryProvider);
      final activity = await repository.getActivityById(
        userId,
        widget.activityId!,
      );

      if (activity == null) {
        DebugLogger.warning(
          '🧱 NEW ACTIVITY: Activity not found: ${widget.activityId}',
        );
        return;
      }

      if (activity.brickMetadata == null) {
        DebugLogger.warning(
          '🧱 NEW ACTIVITY: Activity has no brick metadata: ${widget.activityId}',
        );
        return;
      }

      // Initialize the brick controller with existing data
      final brickController = ref.read(brickInputControllerProvider.notifier);
      brickController.initializeFromBrickMetadata(
        activity.brickMetadata!,
        activity.scheduledDateTime,
      );

      DebugLogger.info(
        '🧱 NEW ACTIVITY: Brick form initialized from existing activity',
      );
    } catch (e) {
      DebugLogger.error('🧱 NEW ACTIVITY: Error loading brick activity: $e');
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
      body: Stack(
        children: [
          // Main scrollable content
          Positioned.fill(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.opaque,
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
                    // For brick workouts, shows composite image of all three sports
                    NewActivityHeroSection(
                      heroImagePath: coordinator.getHeroImagePath(),
                      isBrick: coordinatorState.selectedTab == SportTab.brick,
                    ),

                    const SizedBox(height: 24),

                    // Date and Time Section (center this)
                    NewActivityDateTimeSection(
                      selectedDate: coordinatorState.selectedDate,
                      selectedTime: coordinatorState.selectedTime,
                      onEditTapped: () =>
                          _showDateTimePicker(coordinatorState, coordinator),
                      isDark: isDark,
                    ),

                    const SizedBox(height: 32),

                    // Sport-specific form fields (full width)
                    _buildFormFields(coordinatorState),

                    // Add padding at bottom for the sticky button
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ),

          // Generate Button (fixed at bottom)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: NewActivityGenerateButton(
              isGenerating: coordinatorState.isGenerating,
              onPressed: () => _handleGeneratePlan(coordinator),
            ),
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
      DebugLogger.info(
        '🔗 NEW ACTIVITY: activityId=${widget.activityId}, eventId=${widget.eventId}, forUserId=${widget.forUserId}',
      );
      await coordinator.generateMacros(
        activityId: widget.activityId,
        eventId: widget.eventId,
        forUserId: widget
            .forUserId, // NEW: Pass through forUserId for coach-created activities
      );
      DebugLogger.info('✅ NEW ACTIVITY: Coordinator generateMacros completed');

      // Coordinator now waits for state to update - no need for manual checks
      if (!mounted) return;

      DebugLogger.info('🚀 NEW ACTIVITY: Navigating to adjust-macros screen');
      context.pushNamed('adjust-macros');
    } catch (e) {
      DebugLogger.error('❌ NEW ACTIVITY: Error in macro generation flow: $e');
      if (!mounted) return;

      // Strip 'Exception: ' prefix for cleaner user-facing messages
      final message = e.toString().replaceFirst('Exception: ', '');
      MealvanaSnackbar.showError(context, message);
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
      case SportTab.brick:
        return const BrickTabContent();
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
