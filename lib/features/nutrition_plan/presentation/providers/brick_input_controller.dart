import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../activities/domain/brick_metadata.dart';
import '../../../../core/utils/debug_logger.dart';
import '../../domain/intensity_distribution.dart';
import '../../../../shared/widgets/kyle_design/inputs/duration_pace_toggle.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../domain/meal_type.dart';

part 'brick_input_controller.g.dart';

/// Form input data for a single brick segment
class BrickSegmentInput {
  final String sport;
  final int order;

  // Common fields
  final int durationMinutes;
  final String intensity; // 'easy', 'moderate', 'hard', 'race'

  /// Intensity distribution across three zones (Z1-Z2, Z3-Z4, Z5+)
  /// Defaults to 70/20/10 split when segment is created
  final IntensityDistribution? intensityDistribution;

  /// Duration/Pace mode for WorkoutDetailsWidget
  final DurationPaceMode durationPaceMode;

  /// Pre-activity fueling window in minutes (0-480)
  final int preActivityMinutes;

  /// Session goal for cycling/swimming
  final String? sessionGoal;

  /// Environment temperature (running/cycling)
  final double temperatureC;

  /// Environment humidity percentage (running/cycling)
  final double humidityPct;

  /// Wind condition for cycling ('still', 'breezy', 'windy')
  final String windCondition;

  /// Sun exposure for cycling ('full_sun', 'mixed', 'shade')
  final String sunExposure;

  /// Deck temperature for swimming
  final double deckTemperature;

  /// Deck humidity for swimming
  final double deckHumidity;

  /// Whether environment/deck conditions section is expanded
  final bool showEnvironment;

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
    this.intensityDistribution,
    this.durationPaceMode = DurationPaceMode.byDuration,
    this.preActivityMinutes = 0,
    this.sessionGoal,
    this.temperatureC = 20.0,
    this.humidityPct = 50.0,
    this.windCondition = 'still',
    this.sunExposure = 'mixed',
    this.deckTemperature = 22.0,
    this.deckHumidity = 50.0,
    this.showEnvironment = false,
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
    IntensityDistribution? intensityDistribution,
    DurationPaceMode? durationPaceMode,
    int? preActivityMinutes,
    String? sessionGoal,
    double? temperatureC,
    double? humidityPct,
    String? windCondition,
    String? sunExposure,
    double? deckTemperature,
    double? deckHumidity,
    bool? showEnvironment,
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
      intensityDistribution: intensityDistribution ?? this.intensityDistribution,
      durationPaceMode: durationPaceMode ?? this.durationPaceMode,
      preActivityMinutes: preActivityMinutes ?? this.preActivityMinutes,
      sessionGoal: sessionGoal ?? this.sessionGoal,
      temperatureC: temperatureC ?? this.temperatureC,
      humidityPct: humidityPct ?? this.humidityPct,
      windCondition: windCondition ?? this.windCondition,
      sunExposure: sunExposure ?? this.sunExposure,
      deckTemperature: deckTemperature ?? this.deckTemperature,
      deckHumidity: deckHumidity ?? this.deckHumidity,
      showEnvironment: showEnvironment ?? this.showEnvironment,
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

  /// Effective duration in minutes for display and validation.
  /// Uses explicit durationMinutes when set, otherwise computes from pace fields.
  int get effectiveDurationMinutes {
    if (durationMinutes > 0) return durationMinutes;
    return _computeDurationFromPace();
  }

  /// Compute duration from distance/pace when in byPace mode
  int _computeDurationFromPace() {
    if (sport == 'swimming' && distanceMeters != null && pacePer100mSeconds != null && pacePer100mSeconds! > 0) {
      return ((distanceMeters! / 100) * (pacePer100mSeconds! / 60)).round();
    } else if (sport == 'cycling' && distanceMiles != null && speedMph != null && speedMph! > 0) {
      return ((distanceMiles! / speedMph!) * 60).round();
    } else if (sport == 'running' && distanceMiles != null && paceMinutesPerMile != null && paceMinutesPerMile! > 0) {
      return (distanceMiles! * paceMinutesPerMile!).round();
    }
    return 0;
  }

  /// Convert to BrickSegment domain model
  ///
  /// If durationMinutes is 0 (e.g. user entered distance/pace instead of
  /// explicit duration), computes it from sport-specific distance/pace fields.
  BrickSegment toBrickSegment() {
    int finalDuration = durationMinutes;
    if (finalDuration <= 0) {
      finalDuration = _computeDurationFromPace();
    }

    return BrickSegment(
      sport: sport,
      order: order,
      durationMinutes: finalDuration,
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
  ///
  /// Duration can come from explicit entry or be computed from distance/pace.
  bool isValid() {
    if (effectiveDurationMinutes <= 0) return false;

    switch (sport) {
      case 'swimming':
        if (durationPaceMode == DurationPaceMode.byDuration) {
          return true;
        }
        return distanceMeters != null &&
            distanceMeters! > 0 &&
            pacePer100mSeconds != null &&
            pacePer100mSeconds! > 0;
      case 'cycling':
        if (durationPaceMode == DurationPaceMode.byDuration) {
          return true;
        }
        return distanceMiles != null &&
            distanceMiles! > 0 &&
            speedMph != null &&
            speedMph! > 0;
      case 'running':
        if (durationPaceMode == DurationPaceMode.byDuration) {
          return true;
        }
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

  /// Brick-level pre-activity fueling window in minutes (0-480)
  final int preActivityMinutes;

  /// Tracks whether the user manually changed the pre-activity timing
  final bool preActivityMinutesManuallySet;

  /// Brick-level fasted toggle (applies to pre-activity fueling only)
  final bool isFasted;

  /// Date and time for the brick activity
  final DateTime selectedDate;
  final TimeOfDay selectedTime;

  const BrickFormState({
    required this.selectedSports,
    required this.sportOrder,
    required this.segmentInputs,
    required this.preActivityMinutes,
    required this.preActivityMinutesManuallySet,
    required this.isFasted,
    required this.selectedDate,
    required this.selectedTime,
  });

  BrickFormState copyWith({
    Set<String>? selectedSports,
    List<String>? sportOrder,
    Map<String, BrickSegmentInput>? segmentInputs,
    int? preActivityMinutes,
    bool? preActivityMinutesManuallySet,
    bool? isFasted,
    DateTime? selectedDate,
    TimeOfDay? selectedTime,
  }) {
    return BrickFormState(
      selectedSports: selectedSports ?? this.selectedSports,
      sportOrder: sportOrder ?? this.sportOrder,
      segmentInputs: segmentInputs ?? this.segmentInputs,
      preActivityMinutes: preActivityMinutes ?? this.preActivityMinutes,
      preActivityMinutesManuallySet:
          preActivityMinutesManuallySet ?? this.preActivityMinutesManuallySet,
      isFasted: isFasted ?? this.isFasted,
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

    // Default intensity distribution (70/20/10)
    final defaultIntensity = IntensityDistribution.defaultDistribution();
    // Default durations for each sport
    final defaultSwimDuration = ((1500 / 100) * (120 / 60)).round(); // 30 min
    final defaultCycleDuration = ((20.0 / 18.0) * 60).round();       // 67 min
    final defaultRunDuration = (3.0 * 9.0).round();                   // 27 min

    final defaultPreSwimMinutes =
        (recommendedHoursBefore(ActivityType.swimming, defaultIntensity, durationMinutes: defaultSwimDuration) * 60).round();
    final defaultPreRideMinutes =
        (recommendedHoursBefore(ActivityType.cycling, defaultIntensity, durationMinutes: defaultCycleDuration) * 60).round();
    final defaultPreRunMinutes =
        (recommendedHoursBefore(ActivityType.running, defaultIntensity, durationMinutes: defaultRunDuration) * 60).round();

    // Initialize segment inputs for all possible sports
    final defaultInputs = <String, BrickSegmentInput>{
      'swimming': BrickSegmentInput(
        sport: 'swimming',
        order: 1,
        intensityDistribution: defaultIntensity,
        poolOrOpenWater: 'pool',
        waterTempC: 24.0,
        distanceMeters: 1500,
        pacePer100mSeconds: 120,
        sessionGoal: 'endurance',
        deckTemperature: 22.0,
        deckHumidity: 50.0,
        preActivityMinutes: defaultPreSwimMinutes,
        durationMinutes: defaultSwimDuration,
      ),
      'cycling': BrickSegmentInput(
        sport: 'cycling',
        order: 2,
        intensityDistribution: defaultIntensity,
        terrain: 'flat_outdoor',
        indoorOutdoor: 'outdoor',
        distanceMiles: 20.0,
        speedMph: 18.0,
        sessionGoal: 'endurance',
        temperatureC: 20.0,
        humidityPct: 50.0,
        windCondition: 'still',
        sunExposure: 'mixed',
        preActivityMinutes: defaultPreRideMinutes,
        durationMinutes: defaultCycleDuration,
      ),
      'running': BrickSegmentInput(
        sport: 'running',
        order: 2,
        intensityDistribution: defaultIntensity,
        distanceMiles: 3.0,
        paceMinutesPerMile: 9.0,
        temperatureC: 20.0,
        humidityPct: 50.0,
        preActivityMinutes: defaultPreRunMinutes,
        durationMinutes: defaultRunDuration,
      ),
    };

    final defaultBrickPreActivityMinutes =
        _recommendedPreActivityMinutes(selectedSports: defaultSports, segmentInputs: defaultInputs);

    return BrickFormState(
      selectedSports: defaultSports,
      sportOrder: defaultOrder,
      segmentInputs: defaultInputs,
      preActivityMinutes: defaultBrickPreActivityMinutes,
      preActivityMinutesManuallySet: false,
      isFasted: false,
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
    final newInputs = Map<String, BrickSegmentInput>.from(state.segmentInputs);

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

      // Create default segment input if one doesn't exist
      if (!newInputs.containsKey(sport)) {
        newInputs[sport] = _createDefaultSegmentInput(sport, newOrder.length);
        DebugLogger.info('🧱 BRICK CONTROLLER: Created default segment input for $sport');
      }

      DebugLogger.info('🧱 BRICK CONTROLLER: Added sport: $sport');
    }

    final shouldUpdatePreActivity = !state.preActivityMinutesManuallySet;
    final updatedPreActivityMinutes = shouldUpdatePreActivity
        ? _recommendedPreActivityMinutes(
            selectedSports: newSelected,
            segmentInputs: newInputs,
          )
        : state.preActivityMinutes;

    state = state.copyWith(
      selectedSports: newSelected,
      sportOrder: newOrder,
      segmentInputs: newInputs,
      preActivityMinutes: updatedPreActivityMinutes,
    );
  }

  /// Create a default segment input for a sport
  BrickSegmentInput _createDefaultSegmentInput(String sport, int order) {
    // All segments start with default 70/20/10 intensity distribution
    final defaultIntensity = IntensityDistribution.defaultDistribution();
    // Default durations for each sport (used for fueling window calculation)
    const defaultSwimDuration = 30; // 1500m at 2:00/100m
    const defaultCycleDuration = 67; // 20mi at 18mph
    const defaultRunDuration = 27;  // 3mi at 9:00/mi
    final defaultPreSwimMinutes =
        (recommendedHoursBefore(ActivityType.swimming, defaultIntensity, durationMinutes: defaultSwimDuration) * 60).round();
    final defaultPreRideMinutes =
        (recommendedHoursBefore(ActivityType.cycling, defaultIntensity, durationMinutes: defaultCycleDuration) * 60).round();
    final defaultPreRunMinutes =
        (recommendedHoursBefore(ActivityType.running, defaultIntensity, durationMinutes: defaultRunDuration) * 60).round();

    switch (sport) {
      case 'swimming':
        return BrickSegmentInput(
          sport: sport,
          order: order,
          intensityDistribution: defaultIntensity,
          poolOrOpenWater: 'pool',
          waterTempC: 24.0,
          distanceMeters: 1500,
          pacePer100mSeconds: 120,
          sessionGoal: 'endurance',
          deckTemperature: 22.0,
          deckHumidity: 50.0,
          preActivityMinutes: defaultPreSwimMinutes,
          durationMinutes: ((1500 / 100) * (120 / 60)).round(),
        );
      case 'cycling':
        return BrickSegmentInput(
          sport: sport,
          order: order,
          intensityDistribution: defaultIntensity,
          terrain: 'flat_outdoor',
          indoorOutdoor: 'outdoor',
          distanceMiles: 20.0,
          speedMph: 18.0,
          sessionGoal: 'endurance',
          temperatureC: 20.0,
          humidityPct: 50.0,
          windCondition: 'still',
          sunExposure: 'mixed',
          preActivityMinutes: defaultPreRideMinutes,
          durationMinutes: ((20.0 / 18.0) * 60).round(),
        );
      case 'running':
        return BrickSegmentInput(
          sport: sport,
          order: order,
          intensityDistribution: defaultIntensity,
          distanceMiles: 3.0,
          paceMinutesPerMile: 9.0,
          temperatureC: 20.0,
          humidityPct: 50.0,
          preActivityMinutes: defaultPreRunMinutes,
          durationMinutes: (3.0 * 9.0).round(),
        );
      default:
        return BrickSegmentInput(
          sport: sport,
          order: order,
          durationMinutes: 30,
          intensityDistribution: defaultIntensity,
        );
    }
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

    if (state.preActivityMinutesManuallySet) {
      state = state.copyWith(segmentInputs: newInputs);
      DebugLogger.info('🧱 BRICK CONTROLLER: Updated $sport segment input');
      return;
    }

    final updatedPreActivityMinutes = _recommendedPreActivityMinutes(
      selectedSports: state.selectedSports,
      segmentInputs: newInputs,
    );

    state = state.copyWith(
      segmentInputs: newInputs,
      preActivityMinutes: updatedPreActivityMinutes,
    );
    DebugLogger.info('🧱 BRICK CONTROLLER: Updated $sport segment input');
  }

  void updatePreActivityMinutes(int minutes) {
    state = state.copyWith(
      preActivityMinutes: minutes,
      preActivityMinutesManuallySet: true,
    );
  }

  void updateFasted(bool isFasted) {
    state = state.copyWith(isFasted: isFasted);
  }

  /// Update intensity distribution for a specific segment
  void updateSegmentIntensity(String sport, IntensityDistribution intensity) {
    final currentInput = state.segmentInputs[sport];
    if (currentInput == null) {
      DebugLogger.warning('🧱 BRICK CONTROLLER: Cannot update intensity - no segment found for $sport');
      return;
    }

    final updatedInput = currentInput.copyWith(intensityDistribution: intensity);
    updateSegmentInput(sport, updatedInput);
    DebugLogger.info('🧱 BRICK CONTROLLER: Updated $sport intensity distribution - $intensity');
  }

  int _recommendedPreActivityMinutes({
    Set<String>? selectedSports,
    Map<String, BrickSegmentInput>? segmentInputs,
  }) {
    // Use the most conservative recommendation across selected segments.
    final sports = selectedSports ?? state.selectedSports;
    final inputs = segmentInputs ?? state.segmentInputs;
    final defaultIntensity = IntensityDistribution.defaultDistribution();

    if (sports.isEmpty) {
      return (recommendedHoursBefore(ActivityType.brick, defaultIntensity) * 60).round();
    }

    int maxMinutes = 0;
    for (final sport in sports) {
      final input = inputs[sport];
      final intensity = input?.intensityDistribution ?? defaultIntensity;
      final duration = input?.durationMinutes ?? 90;
      final minutes = (recommendedHoursBefore(
        ActivityType.brick, intensity,
        durationMinutes: duration,
      ) * 60).round();
      if (minutes > maxMinutes) {
        maxMinutes = minutes;
      }
    }

    if (maxMinutes == 0) {
      return (recommendedHoursBefore(ActivityType.brick, defaultIntensity) * 60).round();
    }

    return maxMinutes;
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
        total += input.effectiveDurationMinutes;
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
    final defaultIntensity = IntensityDistribution.defaultDistribution();

    for (final segment in metadata.segments) {
      sports.add(segment.sport);
      if (!sportOrder.contains(segment.sport)) {
        sportOrder.add(segment.sport);
      }

      // Convert BrickSegment to BrickSegmentInput
      // Note: intensityDistribution is nullable to support existing segments without this field
      // Defaults to 70/20/10 if not present
      final segmentDuration = segment.durationMinutes;
      final preActivityMinutes = switch (segment.sport) {
        'swimming' => (recommendedHoursBefore(ActivityType.swimming, defaultIntensity, durationMinutes: segmentDuration) * 60).round(),
        'cycling' => (recommendedHoursBefore(ActivityType.cycling, defaultIntensity, durationMinutes: segmentDuration) * 60).round(),
        'running' => (recommendedHoursBefore(ActivityType.running, defaultIntensity, durationMinutes: segmentDuration) * 60).round(),
        _ => 0,
      };

      segmentInputs[segment.sport] = BrickSegmentInput(
        sport: segment.sport,
        order: segment.order,
        durationMinutes: segment.durationMinutes,
        intensity: segment.intensity,
        intensityDistribution: defaultIntensity,
        preActivityMinutes: preActivityMinutes,
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

      segmentInputs[segment.sport] = _hydrateDerivedFields(segmentInputs[segment.sport]!);
    }

    // Update state with loaded data
    state = BrickFormState(
      selectedSports: sports,
      sportOrder: sportOrder,
      segmentInputs: segmentInputs,
      preActivityMinutes: _recommendedPreActivityMinutes(
        selectedSports: sports,
        segmentInputs: segmentInputs,
      ),
      preActivityMinutesManuallySet: false,
      isFasted: false,
      selectedDate: activityDate,
      selectedTime: TimeOfDay(hour: activityDate.hour, minute: activityDate.minute),
    );

    DebugLogger.info('🧱 BRICK CONTROLLER: Loaded ${sports.length} segments in order: $sportOrder');
  }

  BrickSegmentInput _hydrateDerivedFields(BrickSegmentInput input) {
    switch (input.sport) {
      case 'running':
        return _hydrateRunningInput(input);
      case 'cycling':
        return _hydrateCyclingInput(input);
      case 'swimming':
        return _hydrateSwimmingInput(input);
      default:
        return input;
    }
  }

  BrickSegmentInput _hydrateRunningInput(BrickSegmentInput input) {
    final distance = input.distanceMiles;
    var pace = input.paceMinutesPerMile;
    var durationMinutes = input.durationMinutes;

    if ((pace == null || pace <= 0) &&
        distance != null &&
        distance > 0 &&
        durationMinutes > 0) {
      pace = durationMinutes / distance;
    }

    if (durationMinutes <= 0 &&
        distance != null &&
        distance > 0 &&
        pace != null &&
        pace > 0) {
      durationMinutes = (distance * pace).round();
    }

    return input.copyWith(
      paceMinutesPerMile: pace,
      durationMinutes: durationMinutes,
    );
  }

  BrickSegmentInput _hydrateCyclingInput(BrickSegmentInput input) {
    final distance = input.distanceMiles;
    var speed = input.speedMph;
    var durationMinutes = input.durationMinutes;

    if ((speed == null || speed <= 0) &&
        distance != null &&
        distance > 0 &&
        durationMinutes > 0) {
      final hours = durationMinutes / 60.0;
      if (hours > 0) {
        speed = distance / hours;
      }
    }

    if (durationMinutes <= 0 &&
        distance != null &&
        distance > 0 &&
        speed != null &&
        speed > 0) {
      durationMinutes = ((distance / speed) * 60).round();
    }

    return input.copyWith(
      speedMph: speed,
      durationMinutes: durationMinutes,
    );
  }

  BrickSegmentInput _hydrateSwimmingInput(BrickSegmentInput input) {
    final distance = input.distanceMeters;
    var pacePer100mSeconds = input.pacePer100mSeconds;
    var durationMinutes = input.durationMinutes;

    if ((pacePer100mSeconds == null || pacePer100mSeconds <= 0) &&
        distance != null &&
        distance > 0 &&
        durationMinutes > 0) {
      final segments = distance / 100.0;
      if (segments > 0) {
        final totalSeconds = durationMinutes * 60;
        pacePer100mSeconds = (totalSeconds / segments).round();
      }
    }

    if (durationMinutes <= 0 &&
        distance != null &&
        distance > 0 &&
        pacePer100mSeconds != null &&
        pacePer100mSeconds > 0) {
      final totalSeconds = (distance / 100.0) * pacePer100mSeconds;
      durationMinutes = (totalSeconds / 60).round();
    }

    return input.copyWith(
      pacePer100mSeconds: pacePer100mSeconds,
      durationMinutes: durationMinutes,
    );
  }
}
