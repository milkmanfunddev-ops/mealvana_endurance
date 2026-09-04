import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter/material.dart';
import 'running_input_controller.dart';
import 'cycling_input_controller.dart';
import 'swimming_input_controller.dart';
import 'brick_input_controller.dart';
import 'macro_targets_controller.dart';
import '../../../../core/utils/debug_logger.dart';
import '../../../../shared/providers/user_id_provider.dart';

part 'new_activity_coordinator.g.dart';

/// Sport tab selection enum
enum SportTab { running, cycling, swimming, brick }

/// Default datetime for newly-created activities.
/// Ensures the suggested time is at least one hour in the future.
DateTime defaultNewActivityDateTime([DateTime? reference]) {
  final now = reference ?? DateTime.now();
  final atLeastOneHourAhead = now.add(const Duration(hours: 1));

  // Round up to the next 15-minute boundary for cleaner defaults in the UI.
  final roundedMinute = ((atLeastOneHourAhead.minute + 14) ~/ 15) * 15;
  final hourCarry = roundedMinute ~/ 60;
  final minute = roundedMinute % 60;

  return DateTime(
    atLeastOneHourAhead.year,
    atLeastOneHourAhead.month,
    atLeastOneHourAhead.day,
    atLeastOneHourAhead.hour + hourCarry,
    minute,
  );
}

/// New Activity Coordinator
///
/// Manages tab selection state and coordinates shared state (date/time) across
/// all three sport-specific controllers (running, cycling, swimming).
///
/// This is a thin coordination layer that delegates business logic to existing
/// well-tested sport-specific controllers.
///
/// Status: Phase 0 - File structure created
@riverpod
class NewActivityCoordinator extends _$NewActivityCoordinator {
  @override
  NewActivityCoordinatorState build() {
    final defaultDateTime = defaultNewActivityDateTime();

    return NewActivityCoordinatorState(
      selectedTab: SportTab.running,
      selectedDate: DateTime(
        defaultDateTime.year,
        defaultDateTime.month,
        defaultDateTime.day,
      ),
      selectedTime: TimeOfDay.fromDateTime(defaultDateTime),
      isGenerating: false,
    );
  }

  /// Select a sport tab
  void selectTab(SportTab tab) {
    DebugLogger.info('🏃 COORDINATOR: Switching sport tab to ${tab.name}');

    // Clear cached macro targets when switching sports to prevent stale data
    ref.read(macroTargetsControllerProvider.notifier).clearCachedMacros();

    state = state.copyWith(selectedTab: tab);
    DebugLogger.info(
      '✅ COORDINATOR: Sport tab switched, cached macros cleared',
    );

    // Trigger location fetch for the newly selected sport
    fetchLocationForActiveTab();
  }

  /// Fetch location for the currently active sport tab.
  /// This ensures only ONE controller requests location at a time,
  /// preventing race conditions with the geolocator.
  Future<void> fetchLocationForActiveTab() async {
    DebugLogger.info(
      '📍 COORDINATOR: Fetching location for ${state.selectedTab.name} tab',
    );

    switch (state.selectedTab) {
      case SportTab.running:
        await ref
            .read(runningInputControllerProvider.notifier)
            .fetchLocationIfNeeded();
        await _applyZonePaceIfAvailableForRunning();
        break;
      case SportTab.cycling:
        await ref
            .read(cyclingInputControllerProvider.notifier)
            .fetchLocationIfNeeded();
        break;
      case SportTab.swimming:
        await ref
            .read(swimmingInputControllerProvider.notifier)
            .fetchLocationIfNeeded();
        await _applyZonePaceIfAvailableForSwimming();
        break;
      case SportTab.brick:
        // Brick workouts don't need location for macro generation
        // Location will be handled per-segment if needed
        break;
    }
  }

  Future<void> _applyZonePaceIfAvailableForRunning() async {
    try {
      final userId = await ref.read(userIdProvider.future);
      await ref
          .read(runningInputControllerProvider.notifier)
          .applyZonePaceIfAvailable(userId);
    } catch (e) {
      // Non-blocking - skip if userId isn't available
      DebugLogger.warning(
        '🏃 COORDINATOR: Unable to apply running zone pace -> $e',
      );
    }
  }

  Future<void> _applyZonePaceIfAvailableForSwimming() async {
    try {
      final userId = await ref.read(userIdProvider.future);
      await ref
          .read(swimmingInputControllerProvider.notifier)
          .applyZonePaceIfAvailable(userId);
    } catch (e) {
      // Non-blocking - skip if userId isn't available
      DebugLogger.warning(
        '🏊 COORDINATOR: Unable to apply swimming zone pace -> $e',
      );
    }
  }

  /// Update date and time (propagates to all sport controllers)
  void updateDateTime(DateTime date, TimeOfDay time) {
    state = state.copyWith(selectedDate: date, selectedTime: time);

    // Propagate to all sport controllers
    ref
        .read(runningInputControllerProvider.notifier)
        .updateDateTime(date, time);
    ref
        .read(cyclingInputControllerProvider.notifier)
        .updateDateTime(date, time);
    ref
        .read(swimmingInputControllerProvider.notifier)
        .updateDateTime(date, time);
    ref.read(brickInputControllerProvider.notifier).updateDateTime(date, time);
  }

  /// Generate macros for the active sport
  ///
  /// Delegates to the appropriate sport-specific controller's generateMacros method,
  /// which in turn calls the main distancePageGutEntryController.
  Future<void> generateMacros({
    String? activityId,
    String? eventId,
    String?
    forUserId, // NEW: If provided, create activity for this user (coach creating for athlete)
  }) async {
    DebugLogger.info(
      '🎮 COORDINATOR: generateMacros called for sport: ${state.selectedTab.name}',
    );

    // CRITICAL: Clear cached macros BEFORE generating to prevent stale data
    DebugLogger.info(
      '🎮 COORDINATOR: Clearing cached macros before generation...',
    );
    await ref.read(macroTargetsControllerProvider.notifier).clearCachedMacros();
    DebugLogger.info(
      '🎮 COORDINATOR: Cached macros cleared, proceeding with generation',
    );

    state = state.copyWith(isGenerating: true);

    try {
      switch (state.selectedTab) {
        case SportTab.running:
          DebugLogger.info(
            '🎮 COORDINATOR: Calling runningInputController.generateMacros...',
          );
          await ref
              .read(runningInputControllerProvider.notifier)
              .generateMacros(
                activityId: activityId,
                eventId: eventId,
                forUserId: forUserId, // NEW: Pass through forUserId
              );
          DebugLogger.info(
            '🎮 COORDINATOR: runningInputController.generateMacros returned',
          );
          break;
        case SportTab.cycling:
          DebugLogger.info(
            '🎮 COORDINATOR: Calling cyclingInputController.generateMacros...',
          );
          await ref
              .read(cyclingInputControllerProvider.notifier)
              .generateMacros(
                activityId: activityId,
                eventId: eventId,
                forUserId: forUserId, // NEW: Pass through forUserId
              );
          DebugLogger.info(
            '🎮 COORDINATOR: cyclingInputController.generateMacros returned',
          );
          break;
        case SportTab.swimming:
          DebugLogger.info(
            '🎮 COORDINATOR: Calling swimmingInputController.generateMacros...',
          );
          await ref
              .read(swimmingInputControllerProvider.notifier)
              .generateMacros(
                activityId: activityId,
                eventId: eventId,
                forUserId: forUserId, // NEW: Pass through forUserId
              );
          DebugLogger.info(
            '🎮 COORDINATOR: swimmingInputController.generateMacros returned',
          );
          break;
        case SportTab.brick:
          DebugLogger.info(
            '🎮 COORDINATOR: Calling brickInputController to get segments...',
          );
          final brickController = ref.read(
            brickInputControllerProvider.notifier,
          );

          // Validate before calling edge function
          if (!brickController.isValid()) {
            DebugLogger.error(
              '❌ COORDINATOR: Brick form is not valid - missing required fields',
            );
            throw Exception(
              'Please fill in all required fields for each sport segment before generating a plan.',
            );
          }

          final segments = brickController.getSegments();
          final segmentOrder = brickController.state.segmentOrder;
          final selectedDate = brickController.state.selectedDate;
          final selectedTime = brickController.state.selectedTime;
          final preActivityMinutes = brickController.state.preActivityMinutes;
          final activityTitle = brickController.state.activityTitleManuallySet
              ? brickController.state.activityTitle
              : null;

          DebugLogger.info(
            '🎮 COORDINATOR: Got ${segments.length} brick segments (preActivityMinutes=$preActivityMinutes), calling macroTargetsController...',
          );
          await ref
              .read(macroTargetsControllerProvider.notifier)
              .generateBrickMacros(
                segments: segments,
                segmentOrder: segmentOrder,
                scheduledDate: selectedDate,
                scheduledTime: selectedTime,
                preActivityMinutes: preActivityMinutes,
                activityTitle: activityTitle,
                activityId: activityId,
                eventId: eventId,
                forUserId: forUserId,
              );
          DebugLogger.info(
            '🎮 COORDINATOR: macroTargetsController.generateBrickMacros returned',
          );
      }

      // CRITICAL: Wait for distancePageGutEntryController state to fully update
      // This ensures the state has propagated through Riverpod before we return
      DebugLogger.info(
        '🎮 COORDINATOR: Waiting for distancePageGutEntryController state update...',
      );
      await ref.read(macroTargetsControllerProvider.future);
      DebugLogger.info('🎮 COORDINATOR: State update confirmed');

      DebugLogger.info('🎮 COORDINATOR: Setting isGenerating to false');
      state = state.copyWith(isGenerating: false);
      DebugLogger.info('✅ COORDINATOR: generateMacros completed successfully');
    } catch (e) {
      DebugLogger.error('❌ COORDINATOR: Error in generateMacros: $e');
      state = state.copyWith(isGenerating: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// Get hero image path for active tab
  String getHeroImagePath() {
    switch (state.selectedTab) {
      case SportTab.running:
        return 'assets/images/Runner.png';
      case SportTab.cycling:
        return 'assets/images/Biker.png';
      case SportTab.swimming:
        return 'assets/images/Swimmer.png';
      case SportTab.brick:
        // TODO: Phase 4 - Add brick-specific hero image
        // Using triathlon image as fallback for now
        return 'assets/images/Triathlete.png';
    }
  }

  /// Get sport label for active tab
  String getSportLabel() {
    switch (state.selectedTab) {
      case SportTab.running:
        return 'Running';
      case SportTab.cycling:
        return 'Biking';
      case SportTab.swimming:
        return 'Swimming';
      case SportTab.brick:
        return 'Brick';
    }
  }
}

/// Coordinator state
class NewActivityCoordinatorState {
  final SportTab selectedTab;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final bool isGenerating;
  final String? errorMessage;

  NewActivityCoordinatorState({
    required this.selectedTab,
    required this.selectedDate,
    required this.selectedTime,
    required this.isGenerating,
    this.errorMessage,
  });

  NewActivityCoordinatorState copyWith({
    SportTab? selectedTab,
    DateTime? selectedDate,
    TimeOfDay? selectedTime,
    bool? isGenerating,
    String? errorMessage,
  }) {
    return NewActivityCoordinatorState(
      selectedTab: selectedTab ?? this.selectedTab,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedTime: selectedTime ?? this.selectedTime,
      isGenerating: isGenerating ?? this.isGenerating,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
