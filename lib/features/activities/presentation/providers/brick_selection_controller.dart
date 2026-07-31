import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/activity.dart';
import '../../domain/brick_eligibility.dart';
import '../../domain/brick_exceptions.dart';

part 'brick_selection_controller.g.dart';

/// State for brick selection mode
class BrickSelectionState {
  const BrickSelectionState({
    this.isSelectionMode = false,
    this.selectedActivityIds = const [],
    this.selectedActivities = const [],
  });

  final bool isSelectionMode;
  final List<String> selectedActivityIds; // Ordered by selection sequence
  final List<Activity> selectedActivities; // Parallel list for easy access

  BrickSelectionState copyWith({
    bool? isSelectionMode,
    List<String>? selectedActivityIds,
    List<Activity>? selectedActivities,
  }) {
    return BrickSelectionState(
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedActivityIds: selectedActivityIds ?? this.selectedActivityIds,
      selectedActivities: selectedActivities ?? this.selectedActivities,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BrickSelectionState) return false;
    return isSelectionMode == other.isSelectionMode &&
        _listEquals(selectedActivityIds, other.selectedActivityIds) &&
        _listEquals(selectedActivities, other.selectedActivities);
  }

  @override
  int get hashCode =>
      Object.hash(isSelectionMode, selectedActivityIds, selectedActivities);

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Controller for managing brick workout selection mode
///
/// Handles the UI flow for creating brick workouts from existing activities:
/// - Enter/exit selection mode
/// - Toggle activity selection with order tracking (1, 2, 3)
/// - Validate selection (2-3 activities, different sports, same day)
/// - Provide selection order for brick creation
///
/// Follows Andrea Bizzotto's Riverpod AsyncNotifier pattern.
@riverpod
class BrickSelectionController extends _$BrickSelectionController {
  @override
  BrickSelectionState build() {
    // Initialize with selection mode disabled
    return const BrickSelectionState();
  }

  /// Enter selection mode
  /// Called when user taps "Create Brick" button
  void enterSelectionMode() {
    state = const BrickSelectionState(
      isSelectionMode: true,
      selectedActivityIds: [],
      selectedActivities: [],
    );
  }

  /// Exit selection mode and clear selections
  /// Called when user taps "Cancel" button
  void exitSelectionMode() {
    state = const BrickSelectionState(
      isSelectionMode: false,
      selectedActivityIds: [],
      selectedActivities: [],
    );
  }

  /// Toggle activity selection
  /// Adds activity if not selected (maintaining order), removes if already selected
  ///
  /// Order tracking:
  /// - First selected activity = order 1
  /// - Second selected activity = order 2
  /// - Third selected activity = order 3
  /// - Removing activity from middle renumbers subsequent activities
  void toggleActivity(Activity activity) {
    final currentState = state;

    // Only swim / bike / run can join a brick. The UI already refuses to make
    // ineligible rows selectable, but guard here too so no caller can build an
    // invalid selection (Notion 3a7e3fdb).
    if (!activity.isBrickEligible) return;

    final selectedIds = List<String>.from(currentState.selectedActivityIds);
    final selectedActivities = List<Activity>.from(
      currentState.selectedActivities,
    );

    final index = selectedIds.indexOf(activity.id);

    if (index >= 0) {
      // Activity is already selected - remove it
      selectedIds.removeAt(index);
      selectedActivities.removeAt(index);
    } else {
      // Activity is not selected - add it (up to maximum of 3)
      if (selectedIds.length < 3) {
        selectedIds.add(activity.id);
        selectedActivities.add(activity);
      }
      // If already at max (3), do nothing (could also show toast/snackbar)
    }

    state = currentState.copyWith(
      selectedActivityIds: selectedIds,
      selectedActivities: selectedActivities,
    );
  }

  /// Reverse the leg order of the current selection.
  ///
  /// Brick redesign (Notion 3a7e3fdb, step 2 — "Pick legs, set order"):
  /// "Swap reverses leg order." The selection order defines the brick's
  /// segment order, so reversing the list is the whole operation; the 1/2/3
  /// badges and the rail preview follow from it.
  void swapOrder() {
    final current = state;
    if (current.selectedActivityIds.length < 2) return;
    state = current.copyWith(
      selectedActivityIds: current.selectedActivityIds.reversed.toList(),
      selectedActivities: current.selectedActivities.reversed.toList(),
    );
  }

  /// Check if brick can be created from current selection
  ///
  /// Requirements (from /docs/brick/ui-flow.md):
  /// 1. Minimum 2 activities selected
  /// 2. Maximum 3 activities selected
  /// 3. Activities must be different sports
  /// 4. Activities must be on same calendar day
  ///
  /// Returns true if all requirements are met
  bool canCreateBrick() {
    final currentState = state;

    final activities = currentState.selectedActivities;

    // Check minimum/maximum count
    if (activities.length < 2 || activities.length > 3) {
      return false;
    }

    // Only the three triathlon disciplines are groupable.
    if (activities.any((a) => !a.isBrickEligible)) {
      return false;
    }

    // Check that all sports are different
    final sportTypes = activities.map((a) => a.activityType).toSet();
    if (sportTypes.length != activities.length) {
      return false; // Duplicate sport found
    }

    // Check that all activities are on same calendar day
    if (activities.isNotEmpty) {
      final firstDate = activities.first.scheduledDateTime;
      final sameDay = DateTime(firstDate.year, firstDate.month, firstDate.day);

      for (final activity in activities) {
        final activityDay = DateTime(
          activity.scheduledDateTime.year,
          activity.scheduledDateTime.month,
          activity.scheduledDateTime.day,
        );
        if (activityDay != sameDay) {
          return false; // Activities on different days
        }
      }
    }

    return true;
  }

  /// Get selected activity IDs in selection order
  /// Used when calling createBrickFromActivities()
  ///
  /// Returns list of activity IDs in the order they were selected
  /// (which defines the brick segment order: [0] = first segment, [1] = second, etc.)
  List<String> getSelectedOrder() {
    final currentState = state;
    return List<String>.from(currentState.selectedActivityIds);
  }

  /// Get the selection order number for an activity (1-based)
  /// Returns null if activity is not selected
  ///
  /// Used for displaying numbered indicators (1, 2, 3) on activity cards
  int? getSelectionOrder(String activityId) {
    final currentState = state;

    final index = currentState.selectedActivityIds.indexOf(activityId);
    return index >= 0 ? index + 1 : null; // Convert to 1-based numbering
  }

  /// Check if an activity is currently selected
  bool isActivitySelected(String activityId) {
    final currentState = state;
    return currentState.selectedActivityIds.contains(activityId);
  }

  /// Get the count of currently selected activities
  /// Used for "Confirm (n)" button text
  int getSelectionCount() {
    final currentState = state;
    return currentState.selectedActivityIds.length;
  }

  /// Validate selection and throw specific exception if validation fails
  ///
  /// This method performs the same validation as canCreateBrick(), but throws
  /// a specific BrickValidationException with a user-friendly message instead
  /// of returning a boolean.
  ///
  /// Use this method before attempting to create a brick to provide detailed
  /// error feedback to the user.
  ///
  /// Throws:
  /// - BrickValidationException.minimumSports() if less than 2 activities selected
  /// - BrickValidationException.maximumActivities() if more than 3 activities selected
  /// - BrickValidationException.duplicateSports() if activities have duplicate sports
  /// - BrickValidationException.sameDayRequired() if activities are on different days
  void validateSelection() {
    final currentState = state;
    final activities = currentState.selectedActivities;

    // Check minimum count
    if (activities.length < 2) {
      throw BrickValidationException.minimumSports();
    }

    // Check maximum count
    if (activities.length > 3) {
      throw BrickValidationException.maximumActivities();
    }

    // Only the three triathlon disciplines are groupable.
    if (activities.any((a) => !a.isBrickEligible)) {
      throw BrickValidationException.ineligibleSport();
    }

    // Check that all sports are different
    final sportTypes = activities.map((a) => a.activityType).toSet();
    if (sportTypes.length != activities.length) {
      throw BrickValidationException.duplicateSports();
    }

    // Check that all activities are on same calendar day
    if (activities.isNotEmpty) {
      final firstDate = activities.first.scheduledDateTime;
      final sameDay = DateTime(firstDate.year, firstDate.month, firstDate.day);

      for (final activity in activities) {
        final activityDay = DateTime(
          activity.scheduledDateTime.year,
          activity.scheduledDateTime.month,
          activity.scheduledDateTime.day,
        );
        if (activityDay != sameDay) {
          throw BrickValidationException.sameDayRequired();
        }
      }
    }
  }

  /// Get a user-friendly validation error message, or null if selection is valid
  ///
  /// Returns a human-readable error message describing why the current selection
  /// cannot be used to create a brick workout, or null if the selection is valid.
  ///
  /// This is useful for displaying inline validation feedback in the UI.
  String? getValidationError() {
    final currentState = state;
    final activities = currentState.selectedActivities;

    // Check minimum count
    if (activities.length < 2) {
      return 'Select at least 2 activities from different sports';
    }

    // Check maximum count
    if (activities.length > 3) {
      return 'Maximum 3 activities allowed per brick';
    }

    // Check that all sports are different
    final sportTypes = activities.map((a) => a.activityType).toSet();
    if (sportTypes.length != activities.length) {
      return 'All activities must be different sports';
    }

    // Check that all activities are on same calendar day
    if (activities.isNotEmpty) {
      final firstDate = activities.first.scheduledDateTime;
      final sameDay = DateTime(firstDate.year, firstDate.month, firstDate.day);

      for (final activity in activities) {
        final activityDay = DateTime(
          activity.scheduledDateTime.year,
          activity.scheduledDateTime.month,
          activity.scheduledDateTime.day,
        );
        if (activityDay != sameDay) {
          return 'All activities must be on the same day';
        }
      }
    }

    return null; // No validation errors
  }
}
