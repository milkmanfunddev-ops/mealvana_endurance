import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../activities/domain/brick_metadata.dart';
import '../../../../core/utils/debug_logger.dart';
import '../../domain/fueling_window_limits.dart';
import '../../domain/intensity_distribution.dart';
import '../../../../shared/widgets/kyle_design/inputs/duration_pace_toggle.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../domain/fueling_window_authority.dart';

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

  /// Pre-activity fueling window in minutes (0-240, see FuelingWindowLimits / D-016)
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
      intensityDistribution:
          intensityDistribution ?? this.intensityDistribution,
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
    if (sport == 'swimming' &&
        distanceMeters != null &&
        pacePer100mSeconds != null &&
        pacePer100mSeconds! > 0) {
      return ((distanceMeters! / 100) * (pacePer100mSeconds! / 60)).round();
    } else if (sport == 'cycling' &&
        distanceMiles != null &&
        speedMph != null &&
        speedMph! > 0) {
      return ((distanceMiles! / speedMph!) * 60).round();
    } else if (sport == 'running' &&
        distanceMiles != null &&
        paceMinutesPerMile != null &&
        paceMinutesPerMile! > 0) {
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

/// Brick form state.
///
/// A brick is an ORDERED LIST OF LEGS, not a set of sports: the same sport may
/// appear more than once (Run → Bike → Run) and the legs are fuelled in the
/// order they appear. Ruled Lee 2026-08-26 (see brick_eligibility.dart); the
/// earlier sport-keyed model silently collapsed a second run onto the first.
class BrickFormState {
  /// Activity title shown on the new activity screen.
  final String activityTitle;

  /// Whether the activity title was explicitly edited by the user.
  final bool activityTitleManuallySet;

  /// The legs, in brick order. Index == position; each leg's `order` is kept
  /// at index + 1 by the controller. Valid bricks have 2–3 legs.
  final List<BrickSegmentInput> legs;

  /// Brick-level pre-activity fueling window in minutes (0-240, see FuelingWindowLimits / D-016)
  final int preActivityMinutes;

  /// Tracks whether the user manually changed the pre-activity timing
  final bool preActivityMinutesManuallySet;

  /// Date and time for the brick activity
  final DateTime selectedDate;
  final TimeOfDay selectedTime;

  const BrickFormState({
    required this.activityTitle,
    required this.activityTitleManuallySet,
    required this.legs,
    required this.preActivityMinutes,
    required this.preActivityMinutesManuallySet,
    required this.selectedDate,
    required this.selectedTime,
  });

  /// The sport of each leg, in brick order — what the engine receives as
  /// `segment_order`. Repeats are meaningful (`[running, cycling, running]`).
  List<String> get segmentOrder =>
      legs.map((l) => l.sport).toList(growable: false);

  /// The distinct sports present (hero art, header icons) — NOT the legs.
  Set<String> get sports => legs.map((l) => l.sport).toSet();

  /// Maximum legs a brick may carry (the nutrition engine models T1/T2 only).
  static const int maxLegs = 3;

  /// Minimum legs for a valid brick.
  static const int minLegs = 2;

  bool get canAddLeg => legs.length < maxLegs;
  bool get canRemoveLeg => legs.length > minLegs;

  BrickFormState copyWith({
    String? activityTitle,
    bool? activityTitleManuallySet,
    List<BrickSegmentInput>? legs,
    int? preActivityMinutes,
    bool? preActivityMinutesManuallySet,
    DateTime? selectedDate,
    TimeOfDay? selectedTime,
  }) {
    return BrickFormState(
      activityTitle: activityTitle ?? this.activityTitle,
      activityTitleManuallySet:
          activityTitleManuallySet ?? this.activityTitleManuallySet,
      legs: legs ?? this.legs,
      preActivityMinutes: preActivityMinutes ?? this.preActivityMinutes,
      preActivityMinutesManuallySet:
          preActivityMinutesManuallySet ?? this.preActivityMinutesManuallySet,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedTime: selectedTime ?? this.selectedTime,
    );
  }
}

/// Brick Input Controller
///
/// Manages brick workout form state including:
/// - The ordered list of legs (add / remove / drag to reorder; a sport may
///   repeat)
/// - Form inputs for each leg
///
/// FOA COMPLIANT: Contains form state management only, business logic
/// delegated to services.
@Riverpod(keepAlive: true)
class BrickInputController extends _$BrickInputController {
  @override
  BrickFormState build() {
    final now = DateTime.now();

    // Default: Swim → Run (classic brick)
    final defaultLegs = _renumber([
      _createDefaultSegmentInput('swimming', 1),
      _createDefaultSegmentInput('running', 2),
    ]);

    return BrickFormState(
      activityTitle: _buildBrickTitle(defaultLegs),
      activityTitleManuallySet: false,
      legs: defaultLegs,
      preActivityMinutes: _recommendedPreActivityMinutes(
        legs: defaultLegs,
        // build() runs before state exists — pass the initial schedule.
        date: now,
        time: const TimeOfDay(hour: 7, minute: 0),
      ),
      preActivityMinutesManuallySet: false,
      selectedDate: now,
      selectedTime: const TimeOfDay(hour: 7, minute: 0),
    );
  }

  /// Update date and time
  void updateDateTime(DateTime date, TimeOfDay time) {
    state = state.copyWith(selectedDate: date, selectedTime: time);
    // §3a: the default window depends on start time (early-start overlay +
    // clamp), so a schedule change re-derives it unless manually set.
    if (!state.preActivityMinutesManuallySet) {
      state = state.copyWith(
        preActivityMinutes: _recommendedPreActivityMinutes(),
      );
    }
    DebugLogger.info(
      '🧱 BRICK CONTROLLER: Updated date/time - $date ${time.hour}:${time.minute}',
    );
  }

  /// Append a leg of [sport] at the end of the brick. The same sport may be
  /// added more than once. Enforces the maximum leg count.
  void addLeg(String sport) {
    if (!state.canAddLeg) {
      DebugLogger.warning(
        '🧱 BRICK CONTROLLER: Cannot add $sport - maximum '
        '${BrickFormState.maxLegs} legs allowed',
      );
      return;
    }
    final newLegs = _renumber([
      ...state.legs,
      _createDefaultSegmentInput(sport, state.legs.length + 1),
    ]);
    _commitLegs(newLegs);
    DebugLogger.info('🧱 BRICK CONTROLLER: Added leg: $sport');
  }

  /// Remove the leg at [index]. Enforces the minimum leg count.
  void removeLegAt(int index) {
    if (index < 0 || index >= state.legs.length) return;
    if (!state.canRemoveLeg) {
      DebugLogger.warning(
        '🧱 BRICK CONTROLLER: Cannot remove leg - minimum '
        '${BrickFormState.minLegs} legs required',
      );
      return;
    }
    final newLegs = List<BrickSegmentInput>.from(state.legs)..removeAt(index);
    _commitLegs(_renumber(newLegs));
    DebugLogger.info('🧱 BRICK CONTROLLER: Removed leg at $index');
  }

  /// Reorder legs (drag to reorder)
  void reorderLegs(int oldIndex, int newIndex) {
    final newLegs = List<BrickSegmentInput>.from(state.legs);

    // Handle Flutter's ReorderableListView behavior (newIndex adjusts if moving down)
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final leg = newLegs.removeAt(oldIndex);
    newLegs.insert(newIndex, leg);
    final renumbered = _renumber(newLegs);
    final updatedTitle = state.activityTitleManuallySet
        ? state.activityTitle
        : _buildBrickTitle(renumbered);

    state = state.copyWith(legs: renumbered, activityTitle: updatedTitle);
    DebugLogger.info(
      '🧱 BRICK CONTROLLER: Reordered legs - new order: ${state.segmentOrder}',
    );
  }

  /// Update the leg at [index]. The leg's sport and order are preserved.
  void updateSegmentInput(int index, BrickSegmentInput input) {
    if (index < 0 || index >= state.legs.length) {
      DebugLogger.warning(
        '🧱 BRICK CONTROLLER: Cannot update leg $index - out of range',
      );
      return;
    }
    final current = state.legs[index];
    final newLegs = List<BrickSegmentInput>.from(state.legs)
      ..[index] = input.copyWith(sport: current.sport, order: index + 1);

    if (state.preActivityMinutesManuallySet) {
      state = state.copyWith(legs: newLegs);
      DebugLogger.info('🧱 BRICK CONTROLLER: Updated leg $index input');
      return;
    }

    state = state.copyWith(
      legs: newLegs,
      preActivityMinutes: _recommendedPreActivityMinutes(legs: newLegs),
    );
    DebugLogger.info('🧱 BRICK CONTROLLER: Updated leg $index input');
  }

  void updatePreActivityMinutes(int minutes) {
    // D-016: clamp into the ratified 0–240 domain — pre-cap activities can
    // carry persisted lead times up to 480 (see FuelingWindowLimits).
    state = state.copyWith(
      preActivityMinutes: clampFuelingWindowMinutes(minutes),
      preActivityMinutesManuallySet: true,
    );
  }

  /// Update intensity distribution for the leg at [index]
  void updateSegmentIntensity(int index, IntensityDistribution intensity) {
    if (index < 0 || index >= state.legs.length) {
      DebugLogger.warning(
        '🧱 BRICK CONTROLLER: Cannot update intensity - no leg at $index',
      );
      return;
    }
    updateSegmentInput(
      index,
      state.legs[index].copyWith(intensityDistribution: intensity),
    );
    DebugLogger.info(
      '🧱 BRICK CONTROLLER: Updated leg $index intensity distribution - $intensity',
    );
  }

  /// Get list of BrickSegment objects in brick order (order = 1..n)
  List<BrickSegment> getSegments() => [
    for (var i = 0; i < state.legs.length; i++)
      state.legs[i].copyWith(order: i + 1).toBrickSegment(),
  ];

  /// Check if all form data is valid for macro generation
  bool isValid() =>
      state.legs.length >= BrickFormState.minLegs &&
      state.legs.every((leg) => leg.isValid());

  /// Get total duration across all legs
  int getTotalDuration() =>
      state.legs.fold(0, (sum, leg) => sum + leg.effectiveDurationMinutes);

  /// Get a human-readable brick type (e.g., "SWIM/RUN BRICK")
  String getBrickType() => _buildBrickTitle(state.legs);

  /// Initialize form from event subtype distances (triathlon/duathlon/multisport)
  ///
  /// Adds one leg per provided distance in swim → bike → run order, with
  /// default paces/speeds, using byPace mode so duration auto-computes.
  void initializeFromEventSubtype({
    double? swimMeters,
    double? bikeMiles,
    double? runMiles,
  }) {
    DebugLogger.info(
      '🧱 BRICK CONTROLLER: Initializing from event subtype '
      '(swim=${swimMeters}m, bike=${bikeMiles}mi, run=${runMiles}mi)',
    );

    final defaultIntensity = IntensityDistribution.defaultDistribution();
    final legs = <BrickSegmentInput>[];

    if (swimMeters != null) {
      const defaultPace = 120; // 2:00 per 100m
      final duration = ((swimMeters / 100) * (defaultPace / 60)).round();
      legs.add(
        BrickSegmentInput(
          sport: 'swimming',
          order: legs.length + 1,
          intensityDistribution: defaultIntensity,
          durationPaceMode: DurationPaceMode.byPace,
          poolOrOpenWater: 'open_water',
          waterTempC: 20.0,
          distanceMeters: swimMeters,
          pacePer100mSeconds: defaultPace,
          sessionGoal: 'endurance',
          deckTemperature: 22.0,
          deckHumidity: 50.0,
          preActivityMinutes: _preMinutesFor(
            ActivityType.swimming,
            defaultIntensity,
            duration,
          ),
          durationMinutes: duration,
        ),
      );
    }

    if (bikeMiles != null) {
      const defaultSpeed = 18.0; // 18 mph
      final duration = ((bikeMiles / defaultSpeed) * 60).round();
      legs.add(
        BrickSegmentInput(
          sport: 'cycling',
          order: legs.length + 1,
          intensityDistribution: defaultIntensity,
          durationPaceMode: DurationPaceMode.byPace,
          terrain: 'flat_outdoor',
          indoorOutdoor: 'outdoor',
          distanceMiles: bikeMiles,
          speedMph: defaultSpeed,
          sessionGoal: 'endurance',
          temperatureC: 20.0,
          humidityPct: 50.0,
          windCondition: 'still',
          sunExposure: 'mixed',
          preActivityMinutes: _preMinutesFor(
            ActivityType.cycling,
            defaultIntensity,
            duration,
          ),
          durationMinutes: duration,
        ),
      );
    }

    if (runMiles != null) {
      const defaultPace = 9.0; // 9:00/mile
      final duration = (runMiles * defaultPace).round();
      legs.add(
        BrickSegmentInput(
          sport: 'running',
          order: legs.length + 1,
          intensityDistribution: defaultIntensity,
          durationPaceMode: DurationPaceMode.byPace,
          distanceMiles: runMiles,
          paceMinutesPerMile: defaultPace,
          temperatureC: 20.0,
          humidityPct: 50.0,
          preActivityMinutes: _preMinutesFor(
            ActivityType.running,
            defaultIntensity,
            duration,
          ),
          durationMinutes: duration,
        ),
      );
    }

    // Must have at least 2 legs for a brick
    if (legs.length < BrickFormState.minLegs) {
      DebugLogger.warning(
        '🧱 BRICK CONTROLLER: Not enough legs from event subtype, keeping defaults',
      );
      return;
    }

    state = BrickFormState(
      activityTitle: _buildBrickTitle(legs),
      activityTitleManuallySet: false,
      legs: legs,
      preActivityMinutes: _recommendedPreActivityMinutes(legs: legs),
      preActivityMinutesManuallySet: false,
      selectedDate: state.selectedDate,
      selectedTime: state.selectedTime,
    );

    DebugLogger.info(
      '🧱 BRICK CONTROLLER: Initialized from event subtype with '
      '${legs.length} legs in order: ${state.segmentOrder}',
    );
  }

  /// Initialize form from existing brick metadata
  /// Called when opening an existing brick activity that needs a nutrition plan
  ///
  /// Every segment becomes its own leg, in `order`, with its own duration —
  /// two runs stay two runs.
  void initializeFromBrickMetadata(
    BrickMetadata metadata,
    DateTime activityDate,
  ) {
    DebugLogger.info(
      '🧱 BRICK CONTROLLER: Initializing from existing brick metadata',
    );

    final defaultIntensity = IntensityDistribution.defaultDistribution();
    final ordered = List<BrickSegment>.from(metadata.segments)
      ..sort((a, b) => a.order.compareTo(b.order));

    final legs = <BrickSegmentInput>[];
    for (final segment in ordered) {
      // Note: intensityDistribution is nullable to support existing segments
      // without this field. Defaults to 70/20/10 if not present.
      final sportType = switch (segment.sport) {
        'swimming' => ActivityType.swimming,
        'cycling' => ActivityType.cycling,
        'running' => ActivityType.running,
        _ => null,
      };
      final preActivityMinutes = sportType == null
          ? 0
          : _preMinutesFor(
              sportType,
              defaultIntensity,
              segment.durationMinutes,
            );

      final input = BrickSegmentInput(
        sport: segment.sport,
        order: legs.length + 1,
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
      legs.add(_hydrateDerivedFields(input));
    }

    // Update state with loaded data
    state = BrickFormState(
      activityTitle: _buildBrickTitle(legs),
      activityTitleManuallySet: false,
      legs: legs,
      preActivityMinutes: _recommendedPreActivityMinutes(legs: legs),
      preActivityMinutesManuallySet: false,
      selectedDate: activityDate,
      selectedTime: TimeOfDay(
        hour: activityDate.hour,
        minute: activityDate.minute,
      ),
    );

    DebugLogger.info(
      '🧱 BRICK CONTROLLER: Loaded ${legs.length} legs in order: '
      '${state.segmentOrder}',
    );
  }

  void updateActivityTitle(String title) {
    state = state.copyWith(
      activityTitle: title.trim(),
      activityTitleManuallySet: true,
    );
  }

  void seedActivityTitle(String title, {bool markManuallySet = true}) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(
      activityTitle: trimmed,
      activityTitleManuallySet: markManuallySet,
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────

  /// Commit a new leg list, refreshing the derived pre-activity window and
  /// title unless the user pinned them.
  void _commitLegs(List<BrickSegmentInput> legs) {
    state = state.copyWith(
      legs: legs,
      preActivityMinutes: state.preActivityMinutesManuallySet
          ? state.preActivityMinutes
          : _recommendedPreActivityMinutes(legs: legs),
      activityTitle: state.activityTitleManuallySet
          ? state.activityTitle
          : _buildBrickTitle(legs),
    );
  }

  /// Keep every leg's `order` equal to its position + 1.
  static List<BrickSegmentInput> _renumber(List<BrickSegmentInput> legs) => [
    for (var i = 0; i < legs.length; i++) legs[i].copyWith(order: i + 1),
  ];

  /// Per-leg seed for `BrickSegmentInput.preActivityMinutes` — the pure §3a
  /// table applied to the leg's own duration/intensity, no early-start or
  /// clamp overlay (those are session-level and applied by
  /// [_recommendedPreActivityMinutes], which needs built state; this seed is
  /// also called during build()). The table is sport-neutral
  /// (food-recommendation §3a retires the per-sport windows), so [sport] is
  /// accepted for call-site continuity and ignored.
  static int _preMinutesFor(
    ActivityType sport,
    IntensityDistribution intensity,
    int durationMinutes,
  ) {
    final sessionClass = classifySession(
      durationMinutes: durationMinutes,
      intensity: intensity,
    );
    return tableDefaultWindowMin(sessionClass);
  }

  /// Whole minutes between [now] and the scheduled start; never negative.
  static int _minutesUntil(DateTime now, DateTime date, TimeOfDay time) {
    final scheduled =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final diff = scheduled.difference(now).inMinutes;
    return diff > 0 ? diff : 0;
  }

  /// Create a default segment input for a sport
  BrickSegmentInput _createDefaultSegmentInput(String sport, int order) {
    // All segments start with default 70/20/10 intensity distribution
    final defaultIntensity = IntensityDistribution.defaultDistribution();
    // Default durations for each sport (used for fueling window calculation)
    const defaultSwimDuration = 30; // 1500m at 2:00/100m
    const defaultCycleDuration = 67; // 20mi at 18mph
    const defaultRunDuration = 27; // 3mi at 9:00/mi

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
          preActivityMinutes: _preMinutesFor(
            ActivityType.swimming,
            defaultIntensity,
            defaultSwimDuration,
          ),
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
          preActivityMinutes: _preMinutesFor(
            ActivityType.cycling,
            defaultIntensity,
            defaultCycleDuration,
          ),
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
          preActivityMinutes: _preMinutesFor(
            ActivityType.running,
            defaultIntensity,
            defaultRunDuration,
          ),
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

  /// §3a (food-recommendation, RATIFIED 2026-09-03): the ratified table
  /// replaces the retired recommendedHoursBefore formula. A brick is ONE
  /// session, so the class comes from the TOTAL leg duration; the intensity
  /// input is the hardest leg's distribution (lowest conversational share),
  /// which is what the preset mapping (Race Pace ⇒ race row · Long ⇒ +1 row)
  /// reads. With no legs (or all-zero durations) the total known duration is
  /// 0, which is the table's own <60 row (45 min) — a provisional default
  /// that re-derives as soon as legs carry durations. (W-10: the ratified
  /// table names no per-sport or per-leg windows; this session-level mapping
  /// is the implementation's reading, raised in the bundle findings.)
  int _recommendedPreActivityMinutes({
    List<BrickSegmentInput>? legs,
    DateTime? date,
    TimeOfDay? time,
  }) {
    final inputs = legs ?? state.legs;
    final scheduleDate = date ?? state.selectedDate;
    final scheduleTime = time ?? state.selectedTime;
    final defaultIntensity = IntensityDistribution.defaultDistribution();

    var totalMinutes = 0;
    IntensityDistribution hardest = defaultIntensity;
    var hardestConversational = 1 << 30;
    for (final input in inputs) {
      totalMinutes += input.durationMinutes;
      final intensity = input.intensityDistribution ?? defaultIntensity;
      if (intensity.conversationalPct < hardestConversational) {
        hardestConversational = intensity.conversationalPct;
        hardest = intensity;
      }
    }

    return defaultFuelingWindowMinutes(
      durationMinutes: totalMinutes,
      intensity: hardest,
      startHour: scheduleTime.hour,
      minutesUntilStart: _minutesUntil(
        DateTime.now(),
        scheduleDate,
        scheduleTime,
      ),
    );
  }

  /// "RUN/BIKE/RUN BRICK" — one short name per leg, in brick order.
  static String _buildBrickTitle(List<BrickSegmentInput> legs) {
    if (legs.isEmpty) return 'BRICK';
    return '${legs.map((l) => brickLegShortName(l.sport)).join('/')} BRICK';
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

    return input.copyWith(speedMph: speed, durationMinutes: durationMinutes);
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

/// Short display name for a brick leg's sport: SWIM / BIKE / RUN.
String brickLegShortName(String sport) => switch (sport) {
  'swimming' => 'SWIM',
  'cycling' => 'BIKE',
  'running' => 'RUN',
  _ => sport.toUpperCase(),
};
