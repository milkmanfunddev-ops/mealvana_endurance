import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../activities/domain/brick_metadata.dart';
import '../../../../core/utils/debug_logger.dart';

part 'brick_input_controller.g.dart';

/// Form input data for a single brick segment
class BrickSegmentInput {
  final String sport;
  final int order;

  // Common fields
  final int durationMinutes;
  final String intensity; // 'easy', 'moderate', 'hard', 'race'

  // Swimming fields
  final double? distanceMeters;
  final int? pacePer100mSeconds;
  final String? poolOrOpenWater; // 'pool', 'open_water'
  final double? waterTempC;

  // Cycling fields
  final double? distanceMiles;
  final double? speedMph;
  final String? terrain; // 'flat', 'rolling', 'hilly'
  final String? indoorOutdoor; // 'indoor', 'outdoor'
  final int? elevationGainFt;

  // Running fields (shares distanceMiles with cycling)
  final double? paceMinutesPerMile;

  const BrickSegmentInput({
    required this.sport,
    required this.order,
    this.durationMinutes = 0,
    this.intensity = 'moderate',
    // Swimming
    this.distanceMeters,
    this.pacePer100mSeconds,
    this.poolOrOpenWater,
    this.waterTempC,
    // Cycling
    this.distanceMiles,
    this.speedMph,
    this.terrain,
    this.indoorOutdoor,
    this.elevationGainFt,
    // Running
    this.paceMinutesPerMile,
  });

  BrickSegmentInput copyWith({
    String? sport,
    int? order,
    int? durationMinutes,
    String? intensity,
    double? distanceMeters,
    int? pacePer100mSeconds,
    String? poolOrOpenWater,
    double? waterTempC,
    double? distanceMiles,
    double? speedMph,
    String? terrain,
    String? indoorOutdoor,
    int? elevationGainFt,
    double? paceMinutesPerMile,
  }) {
    return BrickSegmentInput(
      sport: sport ?? this.sport,
      order: order ?? this.order,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      intensity: intensity ?? this.intensity,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      pacePer100mSeconds: pacePer100mSeconds ?? this.pacePer100mSeconds,
      poolOrOpenWater: poolOrOpenWater ?? this.poolOrOpenWater,
      waterTempC: waterTempC ?? this.waterTempC,
      distanceMiles: distanceMiles ?? this.distanceMiles,
      speedMph: speedMph ?? this.speedMph,
      terrain: terrain ?? this.terrain,
      indoorOutdoor: indoorOutdoor ?? this.indoorOutdoor,
      elevationGainFt: elevationGainFt ?? this.elevationGainFt,
      paceMinutesPerMile: paceMinutesPerMile ?? this.paceMinutesPerMile,
    );
  }

  /// Convert to BrickSegment domain model
  BrickSegment toBrickSegment() {
    return BrickSegment(
      sport: sport,
      order: order,
      durationMinutes: durationMinutes,
      intensity: intensity,
      distanceMeters: distanceMeters,
      pacePer100mSeconds: pacePer100mSeconds,
      poolOrOpenWater: poolOrOpenWater,
      waterTempC: waterTempC,
      distanceMiles: distanceMiles,
      speedMph: speedMph,
      terrain: terrain,
      indoorOutdoor: indoorOutdoor,
      elevationGainFt: elevationGainFt,
      paceMinutesPerMile: paceMinutesPerMile,
    );
  }

  /// Check if this segment has all required fields filled
  bool isValid() {
    if (durationMinutes <= 0) return false;

    switch (sport) {
      case 'swimming':
        return distanceMeters != null &&
            distanceMeters! > 0 &&
            pacePer100mSeconds != null &&
            pacePer100mSeconds! > 0 &&
            poolOrOpenWater != null;
      case 'cycling':
        return distanceMiles != null &&
            distanceMiles! > 0 &&
            speedMph != null &&
            speedMph! > 0 &&
            terrain != null &&
            indoorOutdoor != null;
      case 'running':
        return distanceMiles != null &&
            distanceMiles! > 0 &&
            paceMinutesPerMile != null &&
            paceMinutesPerMile! > 0;
      default:
        return false;
    }
  }
}

/// Brick form state
class BrickFormState {
  /// Which sports are checked/selected (minimum 2)
  final Set<String> selectedSports;

  /// Segment order (determines which segment is 1st, 2nd, 3rd)
  final List<String> sportOrder;

  /// Form data for each sport
  final Map<String, BrickSegmentInput> segmentInputs;

  /// Date and time for the brick activity
  final DateTime selectedDate;
  final TimeOfDay selectedTime;

  const BrickFormState({
    required this.selectedSports,
    required this.sportOrder,
    required this.segmentInputs,
    required this.selectedDate,
    required this.selectedTime,
  });

  BrickFormState copyWith({
    Set<String>? selectedSports,
    List<String>? sportOrder,
    Map<String, BrickSegmentInput>? segmentInputs,
    DateTime? selectedDate,
    TimeOfDay? selectedTime,
  }) {
    return BrickFormState(
      selectedSports: selectedSports ?? this.selectedSports,
      sportOrder: sportOrder ?? this.sportOrder,
      segmentInputs: segmentInputs ?? this.segmentInputs,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedTime: selectedTime ?? this.selectedTime,
    );
  }
}

/// Brick Input Controller
///
/// Manages brick workout form state including:
/// - Sport selection (which sports are included)
/// - Segment order (drag to reorder)
/// - Form inputs for each sport segment
///
/// FOA COMPLIANT: Contains form state management only, business logic
/// delegated to services.
@Riverpod(keepAlive: true)
class BrickInputController extends _$BrickInputController {
  @override
  BrickFormState build() {
    final now = DateTime.now();

    // Default: Swimming and Running selected (classic brick)
    final defaultSports = {'swimming', 'running'};
    final defaultOrder = ['swimming', 'running'];

    // Initialize segment inputs for all possible sports
    final defaultInputs = <String, BrickSegmentInput>{
      'swimming': const BrickSegmentInput(
        sport: 'swimming',
        order: 1,
        poolOrOpenWater: 'pool',
        waterTempC: 24.0,
      ),
      'cycling': const BrickSegmentInput(
        sport: 'cycling',
        order: 2,
        terrain: 'flat',
        indoorOutdoor: 'outdoor',
      ),
      'running': const BrickSegmentInput(
        sport: 'running',
        order: 2,
      ),
    };

    return BrickFormState(
      selectedSports: defaultSports,
      sportOrder: defaultOrder,
      segmentInputs: defaultInputs,
      selectedDate: now,
      selectedTime: const TimeOfDay(hour: 7, minute: 0),
    );
  }

  /// Update date and time
  void updateDateTime(DateTime date, TimeOfDay time) {
    state = state.copyWith(selectedDate: date, selectedTime: time);
    DebugLogger.info('🧱 BRICK CONTROLLER: Updated date/time - $date ${time.hour}:${time.minute}');
  }

  /// Toggle sport selection (add or remove)
  /// Enforces minimum 2 sports requirement
  void toggleSport(String sport) {
    final newSelected = Set<String>.from(state.selectedSports);
    final newOrder = List<String>.from(state.sportOrder);

    if (newSelected.contains(sport)) {
      // Removing sport - enforce minimum 2
      if (newSelected.length <= 2) {
        DebugLogger.warning('🧱 BRICK CONTROLLER: Cannot remove $sport - minimum 2 sports required');
        return;
      }

      newSelected.remove(sport);
      newOrder.remove(sport);
      DebugLogger.info('🧱 BRICK CONTROLLER: Removed sport: $sport');
    } else {
      // Adding sport - enforce maximum 3
      if (newSelected.length >= 3) {
        DebugLogger.warning('🧱 BRICK CONTROLLER: Cannot add $sport - maximum 3 sports allowed');
        return;
      }

      newSelected.add(sport);
      newOrder.add(sport);
      DebugLogger.info('🧱 BRICK CONTROLLER: Added sport: $sport');
    }

    state = state.copyWith(selectedSports: newSelected, sportOrder: newOrder);
  }

  /// Reorder sports (drag to reorder)
  void reorderSports(int oldIndex, int newIndex) {
    final newOrder = List<String>.from(state.sportOrder);

    // Handle Flutter's ReorderableListView behavior (newIndex adjusts if moving down)
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final sport = newOrder.removeAt(oldIndex);
    newOrder.insert(newIndex, sport);

    state = state.copyWith(sportOrder: newOrder);
    DebugLogger.info('🧱 BRICK CONTROLLER: Reordered sports - new order: $newOrder');
  }

  /// Update segment input data for a specific sport
  void updateSegmentInput(String sport, BrickSegmentInput input) {
    final newInputs = Map<String, BrickSegmentInput>.from(state.segmentInputs);
    newInputs[sport] = input;

    state = state.copyWith(segmentInputs: newInputs);
    DebugLogger.info('🧱 BRICK CONTROLLER: Updated $sport segment input');
  }

  /// Get list of BrickSegment objects in proper order
  List<BrickSegment> getSegments() {
    final segments = <BrickSegment>[];

    for (int i = 0; i < state.sportOrder.length; i++) {
      final sport = state.sportOrder[i];
      if (state.selectedSports.contains(sport)) {
        final input = state.segmentInputs[sport];
        if (input != null) {
          // Update order to match current position
          final segmentWithOrder = input.copyWith(order: i + 1);
          segments.add(segmentWithOrder.toBrickSegment());
        }
      }
    }

    return segments;
  }

  /// Check if all form data is valid for macro generation
  bool isValid() {
    // Must have at least 2 sports selected
    if (state.selectedSports.length < 2) {
      return false;
    }

    // All selected sports must have valid segment inputs
    for (final sport in state.selectedSports) {
      final input = state.segmentInputs[sport];
      if (input == null || !input.isValid()) {
        return false;
      }
    }

    return true;
  }

  /// Get total duration across all segments
  int getTotalDuration() {
    int total = 0;
    for (final sport in state.selectedSports) {
      final input = state.segmentInputs[sport];
      if (input != null) {
        total += input.durationMinutes;
      }
    }
    return total;
  }

  /// Get a human-readable brick type (e.g., "SWIM/RUN BRICK")
  String getBrickType() {
    final sportNames = state.sportOrder
        .where((sport) => state.selectedSports.contains(sport))
        .map((sport) => sport.toUpperCase())
        .toList();

    return '${sportNames.join('/')} BRICK';
  }

  /// Initialize form from existing brick metadata
  /// Called when opening an existing brick activity that needs a nutrition plan
  void initializeFromBrickMetadata(BrickMetadata metadata, DateTime activityDate) {
    DebugLogger.info('🧱 BRICK CONTROLLER: Initializing from existing brick metadata');

    // Extract sports and order from segments
    final sports = <String>{};
    final sportOrder = <String>[];
    final segmentInputs = <String, BrickSegmentInput>{};

    for (final segment in metadata.segments) {
      sports.add(segment.sport);
      if (!sportOrder.contains(segment.sport)) {
        sportOrder.add(segment.sport);
      }

      // Convert BrickSegment to BrickSegmentInput
      segmentInputs[segment.sport] = BrickSegmentInput(
        sport: segment.sport,
        order: segment.order,
        durationMinutes: segment.durationMinutes,
        intensity: segment.intensity,
        // Swimming fields
        distanceMeters: segment.distanceMeters,
        pacePer100mSeconds: segment.pacePer100mSeconds,
        poolOrOpenWater: segment.poolOrOpenWater,
        waterTempC: segment.waterTempC,
        // Cycling fields
        distanceMiles: segment.distanceMiles,
        speedMph: segment.speedMph,
        terrain: segment.terrain,
        indoorOutdoor: segment.indoorOutdoor,
        elevationGainFt: segment.elevationGainFt,
        // Running fields
        paceMinutesPerMile: segment.paceMinutesPerMile,
      );
    }

    // Update state with loaded data
    state = BrickFormState(
      selectedSports: sports,
      sportOrder: sportOrder,
      segmentInputs: segmentInputs,
      selectedDate: activityDate,
      selectedTime: TimeOfDay(hour: activityDate.hour, minute: activityDate.minute),
    );

    DebugLogger.info('🧱 BRICK CONTROLLER: Loaded ${sports.length} segments in order: $sportOrder');
  }
}
