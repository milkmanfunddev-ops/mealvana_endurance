import 'dart:async';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/fueling_window_limits.dart';
import '../../domain/run_parameters.dart';
import '../../domain/intensity_distribution.dart';
import '../../domain/fueling_window_authority.dart';
import '../../../activities/domain/activity_title_formatter.dart';
import '../../../auth/data/user_repository.dart';
import 'macro_targets_controller.dart';
import '../../../weather/domain/location.dart' as weather_domain;
import '../../../weather/domain/weather_forecast.dart';
import '../../../weather/application/weather_service.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';
import '../../../../shared/services/location_service.dart';
import '../../../../shared/widgets/kyle_design/inputs/duration_pace_toggle.dart';

part 'cycling_input_controller.g.dart';

/// Cycling-specific form state that persists during tab switches
class CyclingFormState {
  final String activityTitle;
  final bool activityTitleManuallySet;
  final double distance;
  final double speedMph;
  final int preRideMinutes;
  final String intensityTarget;
  final String sessionGoal;
  final String terrain;
  final int elevationGainFt;
  final bool showEnvironment;
  final double temperatureC;
  final double humidityPct;
  final String windCondition;
  final String sunExposure;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final DistanceUnit distanceUnit;

  // Intensity distribution fields
  final IntensityDistribution intensity;
  final DurationPaceMode durationPaceMode;
  final Duration? estimatedDuration;

  // V3: Track if user manually changed the pre-ride timing
  final bool preRideMinutesManuallySet;

  // Unit system preference (imperial = °F, metric = °C)
  final UnitSystem unitSystem;

  // CF-7 (RULED 2026-09-03): a manual step on a forecast-filled value makes
  // it the athlete's — the AUTO badge drops until the next forecast refresh.
  final bool temperatureManuallySet;
  final bool humidityManuallySet;

  // Weather integration fields
  final weather_domain.Location? location;
  final WeatherForecast? weatherForecast;
  final bool isLoadingLocation;
  final bool isLoadingWeather;
  final bool hasAttemptedWeatherFetch;
  final LocationFailureReason? locationFailureReason;

  CyclingFormState({
    this.activityTitle = '25 mi Ride',
    this.activityTitleManuallySet = false,
    this.distance = 25.0,
    this.speedMph = 15.0,
    this.preRideMinutes =
        120, // V3: will be pre-filled from recommendation in controller build()

    this.intensityTarget = 'zone_2',
    this.sessionGoal = 'endurance',
    this.terrain = 'flat_outdoor',
    this.elevationGainFt = 0,
    this.showEnvironment = false,
    this.temperatureC = 20.0,
    this.humidityPct = 60.0,
    this.windCondition = 'breezy',
    this.sunExposure = 'mixed',
    required this.selectedDate,
    required this.selectedTime,
    this.distanceUnit = DistanceUnit.miles,
    IntensityDistribution? intensity,
    this.durationPaceMode = DurationPaceMode.byDuration,
    this.estimatedDuration,
    this.preRideMinutesManuallySet = false,
    this.unitSystem = UnitSystem.imperial,
    this.temperatureManuallySet = false,
    this.humidityManuallySet = false,
    this.location,
    this.weatherForecast,
    this.isLoadingLocation = false,
    this.isLoadingWeather = false,
    this.hasAttemptedWeatherFetch = false,
    this.locationFailureReason,
  }) : intensity =
           intensity ??
           IntensityDistribution(
             conversationalPct: 70,
             tempoPct: 20,
             allOutPct: 10,
           );

  CyclingFormState copyWith({
    String? activityTitle,
    bool? activityTitleManuallySet,
    double? distance,
    double? speedMph,
    int? preRideMinutes,
    String? intensityTarget,
    String? sessionGoal,
    String? terrain,
    int? elevationGainFt,
    bool? showEnvironment,
    double? temperatureC,
    double? humidityPct,
    String? windCondition,
    String? sunExposure,
    DateTime? selectedDate,
    TimeOfDay? selectedTime,
    DistanceUnit? distanceUnit,
    IntensityDistribution? intensity,
    DurationPaceMode? durationPaceMode,
    Duration? estimatedDuration,
    bool? preRideMinutesManuallySet,
    UnitSystem? unitSystem,
    bool? temperatureManuallySet,
    bool? humidityManuallySet,
    weather_domain.Location? location,
    WeatherForecast? weatherForecast,
    bool? isLoadingLocation,
    bool? isLoadingWeather,
    bool? hasAttemptedWeatherFetch,
    LocationFailureReason? locationFailureReason,
  }) {
    return CyclingFormState(
      activityTitle: activityTitle ?? this.activityTitle,
      activityTitleManuallySet:
          activityTitleManuallySet ?? this.activityTitleManuallySet,
      distance: distance ?? this.distance,
      speedMph: speedMph ?? this.speedMph,
      preRideMinutes: preRideMinutes ?? this.preRideMinutes,
      intensityTarget: intensityTarget ?? this.intensityTarget,
      sessionGoal: sessionGoal ?? this.sessionGoal,
      terrain: terrain ?? this.terrain,
      elevationGainFt: elevationGainFt ?? this.elevationGainFt,
      showEnvironment: showEnvironment ?? this.showEnvironment,
      temperatureC: temperatureC ?? this.temperatureC,
      humidityPct: humidityPct ?? this.humidityPct,
      windCondition: windCondition ?? this.windCondition,
      sunExposure: sunExposure ?? this.sunExposure,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedTime: selectedTime ?? this.selectedTime,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      intensity: intensity ?? this.intensity,
      durationPaceMode: durationPaceMode ?? this.durationPaceMode,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      preRideMinutesManuallySet:
          preRideMinutesManuallySet ?? this.preRideMinutesManuallySet,
      unitSystem: unitSystem ?? this.unitSystem,
      temperatureManuallySet:
          temperatureManuallySet ?? this.temperatureManuallySet,
      humidityManuallySet: humidityManuallySet ?? this.humidityManuallySet,
      location: location ?? this.location,
      weatherForecast: weatherForecast ?? this.weatherForecast,
      isLoadingLocation: isLoadingLocation ?? this.isLoadingLocation,
      isLoadingWeather: isLoadingWeather ?? this.isLoadingWeather,
      hasAttemptedWeatherFetch:
          hasAttemptedWeatherFetch ?? this.hasAttemptedWeatherFetch,
      locationFailureReason:
          locationFailureReason ?? this.locationFailureReason,
    );
  }
}

/// Cycling Input Controller - manages form state and delegates macro generation
/// FOA COMPLIANT: Contains form state management and business logic coordination
@Riverpod(keepAlive: true)
class CyclingInputController extends _$CyclingInputController {
  WeatherService get _weatherService => ref.read(weatherServiceProvider);
  Completer<void>? _preferencesLoadedCompleter;
  bool _preferencesLoaded = false;
  double _defaultSpeedMph = 15.0;

  @override
  CyclingFormState build() {
    final now = DateTime.now();

    // Fetch user profile to get distance unit and default speed
    unawaited(_loadUserPreferences());

    // Calculate initial estimated duration using default values
    // Default: 25 miles at 15 mph = 1.67 hours = 100 minutes
    final initialDurationMinutes = (25.0 / 15.0 * 60).round();

    // V3: Pre-fill timing from recommendation based on default intensity
    final defaultIntensity = IntensityDistribution(
      conversationalPct: 70,
      tempoPct: 20,
      allOutPct: 10,
    );
    // §3a (food-recommendation, RATIFIED 2026-09-03): default from the
    // ratified sport-neutral table; the per-sport formula is retired.
    const defaultStart = TimeOfDay(hour: 7, minute: 0);
    final recommendedMinutes = defaultFuelingWindowMinutes(
      durationMinutes: initialDurationMinutes,
      intensity: defaultIntensity,
      startHour: defaultStart.hour,
      minutesUntilStart: _minutesUntil(now, now, defaultStart),
    );

    final initialState = CyclingFormState(
      activityTitle: ActivityTitleFormatter.formatCyclingTitle(25.0),
      selectedDate: now,
      selectedTime: const TimeOfDay(hour: 7, minute: 0),
      preRideMinutes: recommendedMinutes,
      estimatedDuration: Duration(minutes: initialDurationMinutes),
    );

    // NOTE: Location fetching is now triggered explicitly when this tab becomes active
    // or when user opens the screen. This prevents race conditions where multiple
    // controllers try to request location permissions simultaneously.
    // See: fetchLocationIfNeeded() method

    return initialState;
  }

  /// Ensure async user preferences initialization is complete before applying
  /// external prefill values (e.g., synced provider workouts).
  Future<void> waitForPreferencesLoaded() async {
    await _loadUserPreferences();
  }

  /// Baseline speed (user preference when available) for deterministic prefill.
  double getDefaultSpeedMph() => _defaultSpeedMph;

  /// Load user preferences
  Future<void> _loadUserPreferences() async {
    if (_preferencesLoaded) {
      return;
    }

    final existingCompleter = _preferencesLoadedCompleter;
    if (existingCompleter != null) {
      await existingCompleter.future;
      return;
    }

    final completer = Completer<void>();
    _preferencesLoadedCompleter = completer;

    try {
      final userRepository = await ref.read(userRepositoryProvider.future);
      final userProfile = await userRepository.getCurrentUser();

      if (userProfile != null) {
        // If user has a default cycling speed, use it to update speed and recalculate duration
        final defaultSpeed = userProfile.defaultCyclingSpeedMph;
        if (defaultSpeed != null && defaultSpeed > 0) {
          _defaultSpeedMph = defaultSpeed;
          state = state.copyWith(
            distanceUnit: userProfile.preferredDistanceUnit,
            speedMph: defaultSpeed,
            unitSystem: userProfile.unitSystem,
          );
          // Recalculate estimated duration with user's default speed
          _estimateDuration();
          DebugLogger.info(
            '🚴 CYCLING CONTROLLER: Loaded user preferences - distance unit: ${userProfile.preferredDistanceUnit.name}, default speed: ${defaultSpeed}mph, unitSystem: ${userProfile.unitSystem.name}',
          );
        } else {
          _defaultSpeedMph = 15.0;
          state = state.copyWith(
            distanceUnit: userProfile.preferredDistanceUnit,
            unitSystem: userProfile.unitSystem,
          );
          DebugLogger.info(
            '🚴 CYCLING CONTROLLER: Loaded user preferences - distance unit: ${userProfile.preferredDistanceUnit.name}, unitSystem: ${userProfile.unitSystem.name}',
          );
        }
      }
    } catch (e) {
      DebugLogger.error(
        '🚴 CYCLING CONTROLLER: Failed to load user preferences',
        error: e,
      );
    } finally {
      _preferencesLoaded = true;
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  /// Fetch location if this controller needs it and doesn't already have it.
  /// Called when this sport tab becomes active or the screen initializes.
  Future<void> fetchLocationIfNeeded() async {
    if (!state.isLoadingLocation &&
        !state.isLoadingWeather &&
        state.location == null) {
      await fetchCurrentLocation();
      if (state.location == null && state.weatherForecast == null) {
        await fetchWeatherForecast();
      }
    } else if (state.location != null && state.weatherForecast == null) {
      await fetchWeatherForecast();
    }
  }

  /// Initialize with specific date if needed (called from screen's initState)
  void initializeWithDate(DateTime? initialDate) {
    if (initialDate != null) {
      final currentState = state;
      state = currentState.copyWith(
        selectedDate: initialDate,
        selectedTime: TimeOfDay.fromDateTime(initialDate),
      );
    }
  }

  /// Update form field values
  void updateDistance(double distance) {
    final resolvedTitle = state.activityTitleManuallySet
        ? state.activityTitle
        : ActivityTitleFormatter.formatCyclingTitle(
            _distanceToMilesForTitle(distance),
          );
    final hasDuration =
        state.estimatedDuration != null &&
        state.estimatedDuration!.inSeconds > 0;

    if (state.durationPaceMode == DurationPaceMode.byDuration && hasDuration) {
      final newSpeed = _estimateSpeed(
        distance: distance,
        duration: state.estimatedDuration,
      );
      state = state.copyWith(
        activityTitle: resolvedTitle,
        distance: distance,
        speedMph: newSpeed ?? state.speedMph,
      );
      _autoUpdateFuelingWindow();
      return;
    }

    state = state.copyWith(activityTitle: resolvedTitle, distance: distance);
    _estimateDuration(distance: distance, speedMph: state.speedMph);
    _autoUpdateFuelingWindow();
  }

  void updateSpeed(double speedMph) {
    state = state.copyWith(speedMph: speedMph);
    _estimateDuration(distance: state.distance, speedMph: speedMph);
    _autoUpdateFuelingWindow();
  }

  void updatePreRideMinutes(int minutes) {
    // D-016: clamp into the ratified 0–240 domain — pre-cap activities can
    // carry persisted lead times up to 480 (see FuelingWindowLimits).
    final cap = fuelingWindowMaxMinutes();
    final capped = minutes < cap ? minutes : cap;
    state = state.copyWith(
      preRideMinutes: clampFuelingWindowMinutes(capped),
      preRideMinutesManuallySet: true,
    );
  }

  /// Auto-update fueling window when duration, intensity or schedule
  /// changes, unless user has manually overridden it (food-recommendation
  /// §3/§3a: table default + clamp; CF-1/CF-2).
  void _autoUpdateFuelingWindow() {
    if (!state.preRideMinutesManuallySet) {
      final recommended = defaultFuelingWindowMinutes(
        durationMinutes: state.estimatedDuration?.inMinutes ?? 90,
        intensity: state.intensity,
        startHour: state.selectedTime.hour,
        minutesUntilStart: _minutesUntil(
          DateTime.now(),
          state.selectedDate,
          state.selectedTime,
        ),
      );
      state = state.copyWith(
        preRideMinutes: clampFuelingWindowMinutes(recommended),
      );
    }
  }

  /// Whole minutes between [now] and the scheduled start; never negative.
  static int _minutesUntil(DateTime now, DateTime date, TimeOfDay time) {
    final scheduled =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final diff = scheduled.difference(now).inMinutes;
    return diff > 0 ? diff : 0;
  }

  /// CF-1: the stepper's MAXIMUM is the ruled clamp —
  /// min(table cap 240, time-until-start), floor 15 (food-recommendation §3).
  int fuelingWindowMaxMinutes() {
    final untilStart = _minutesUntil(
      DateTime.now(),
      state.selectedDate,
      state.selectedTime,
    );
    final floored =
        untilStart > kFuelingWindowFloorMin ? untilStart : kFuelingWindowFloorMin;
    return floored < FuelingWindowLimits.maxMinutes
        ? floored
        : FuelingWindowLimits.maxMinutes;
  }

  void updateIntensityTarget(String intensityTarget) {
    state = state.copyWith(intensityTarget: intensityTarget);
  }

  void updateSessionGoal(String sessionGoal) {
    state = state.copyWith(sessionGoal: sessionGoal);
  }

  void updateTerrain(String terrain) {
    state = state.copyWith(terrain: terrain);
  }

  void updateIndoorOutdoor(bool isIndoor) {
    // When toggling indoor/outdoor, we need to update the terrain to a valid value
    // for that context to maintain consistency.
    String newTerrain;
    if (isIndoor) {
      // Default to flat_indoor if switching to indoor
      newTerrain = 'flat_indoor';
      // Also reset temp/humidity to room defaults
      state = state.copyWith(
        terrain: newTerrain,
        temperatureC: 20.0, // Room temp
        humidityPct: 45.0, // Comfortable room humidity
        windCondition: 'still',
        sunExposure: 'shade',
      );
    } else {
      // Default to flat_outdoor if switching to outdoor
      newTerrain = 'flat_outdoor';
      state = state.copyWith(terrain: newTerrain);
      // Trigger weather fetch for outdoor
      if (state.location != null) {
        fetchWeatherForecast();
      }
    }
  }

  void updateElevationGain(int elevationGainFt) {
    state = state.copyWith(elevationGainFt: elevationGainFt);
  }

  void toggleEnvironmentSection() {
    state = state.copyWith(showEnvironment: !state.showEnvironment);
  }

  void updateTemperature(double temperatureC) {
    // CF-7: a manual step makes the value the athlete's — AUTO badge drops.
    state = state.copyWith(
      temperatureC: temperatureC,
      temperatureManuallySet: true,
    );
  }

  void updateHumidity(double humidityPct) {
    state = state.copyWith(humidityPct: humidityPct, humidityManuallySet: true);
  }

  void updateWindCondition(String windCondition) {
    state = state.copyWith(windCondition: windCondition);
  }

  void updateSunExposure(String sunExposure) {
    state = state.copyWith(sunExposure: sunExposure);
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

  double _distanceToMilesForTitle(double distance) {
    if (state.distanceUnit == DistanceUnit.kilometers) {
      return distance * 0.621371;
    }
    return distance;
  }

  void updateDateTime(DateTime date, TimeOfDay time) {
    final currentDate = state.selectedDate;
    final currentTime = state.selectedTime;
    final hasChanged =
        currentDate.year != date.year ||
        currentDate.month != date.month ||
        currentDate.day != date.day ||
        currentTime.hour != time.hour ||
        currentTime.minute != time.minute;

    if (!hasChanged) return;

    final isIndoor = state.terrain.contains('indoor');

    state = state.copyWith(
      selectedDate: date,
      selectedTime: time,
      // Reset to environment defaults immediately while refreshed forecast loads.
      temperatureC: 20.0,
      humidityPct: isIndoor ? 45.0 : 60.0,
    );

    // §3a: the default window depends on start time (early-start overlay +
    // clamp), so a schedule change re-derives it unless manually set.
    _autoUpdateFuelingWindow();

    // Auto-fetch weather when date/time changes for outdoor rides if location is set
    // or if weather was previously fetched successfully (via GPS fallback).
    if (!isIndoor &&
        (state.location != null || state.weatherForecast != null)) {
      unawaited(fetchWeatherForecast());
    }
  }

  /// Update intensity distribution
  void updateIntensityDistribution(IntensityDistribution intensity) {
    state = state.copyWith(intensity: intensity);
    _autoUpdateFuelingWindow();
  }

  void updateDuration(Duration duration) {
    final newSpeed = _estimateSpeed(duration: duration);
    state = state.copyWith(
      estimatedDuration: duration,
      speedMph: newSpeed ?? state.speedMph,
    );
    _autoUpdateFuelingWindow();
  }

  /// Update duration/pace mode
  void updateDurationPaceMode(DurationPaceMode mode) {
    if (mode == DurationPaceMode.byDuration) {
      state = state.copyWith(durationPaceMode: mode);
      _estimateDuration(distance: state.distance, speedMph: state.speedMph);
      return;
    }

    final newSpeed = _estimateSpeed();
    state = state.copyWith(
      durationPaceMode: mode,
      speedMph: newSpeed ?? state.speedMph,
    );
  }

  /// Calculate estimated duration from distance and speed
  /// For cycling: estimatedDuration = (distance / speedMph) * 60 minutes
  void _estimateDuration({double? distance, double? speedMph}) {
    final currentDistance = distance ?? state.distance;
    final currentSpeed = speedMph ?? state.speedMph;

    if (currentSpeed > 0 && currentDistance > 0) {
      // Convert to hours, then to minutes
      final durationHours = currentDistance / currentSpeed;
      final durationMinutes = (durationHours * 60).round();

      state = state.copyWith(
        estimatedDuration: Duration(minutes: durationMinutes),
      );
    }
  }

  double? _estimateSpeed({double? distance, Duration? duration}) {
    final currentDistance = distance ?? state.distance;
    final currentDuration = duration ?? state.estimatedDuration;
    if (currentDuration == null || currentDistance <= 0) {
      return null;
    }

    final hours = currentDuration.inSeconds / 3600.0;
    if (hours <= 0) {
      return null;
    }

    return currentDistance / hours;
  }

  /// Fetch current GPS location
  Future<void> fetchCurrentLocation() async {
    state = state.copyWith(isLoadingLocation: true);

    try {
      final location = await _weatherService.getCurrentLocation();
      state = state.copyWith(
        location: location,
        isLoadingLocation: false,
        locationFailureReason: location != null
            ? null
            : state.locationFailureReason,
      );

      // Auto-fetch weather after getting location
      if (location != null) {
        fetchWeatherForecast();
      }
    } catch (e) {
      state = state.copyWith(isLoadingLocation: false);
    }
  }

  /// Fetch weather forecast for the selected date/time
  Future<void> fetchWeatherForecast() async {
    state = state.copyWith(
      isLoadingWeather: true,
      hasAttemptedWeatherFetch: true,
    );

    try {
      // Get activity date/time
      final activityDateTime = DateTime(
        state.selectedDate.year,
        state.selectedDate.month,
        state.selectedDate.day,
        state.selectedTime.hour,
        state.selectedTime.minute,
      );

      // Fetch weather (uses location if set, otherwise GPS)
      final forecast = await _weatherService.getWeatherForecast(
        location: state.location,
        activityDate: activityDateTime,
      );

      // Update temp/humidity from forecast if available
      if (forecast.forecastAvailable) {
        state = state.copyWith(
          weatherForecast: forecast,
          temperatureC: forecast.temperatureC,
          humidityPct: forecast.humidityPct.toDouble(),
          // CF-7: a refresh restores the AUTO badge on both values.
          temperatureManuallySet: false,
          humidityManuallySet: false,
          isLoadingWeather: false,
          locationFailureReason: null,
        );
      } else {
        LocationFailureReason? failureReason;
        if (state.location == null) {
          failureReason = _weatherService.getLastLocationFailureReason();
          if (failureReason == null) {
            final hasPermission = await _weatherService.hasLocationPermission();
            if (!hasPermission) {
              failureReason = LocationFailureReason.permissionDenied;
            }
          }
        }
        state = state.copyWith(
          weatherForecast: forecast,
          isLoadingWeather: false,
          locationFailureReason: failureReason,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoadingWeather: false);
    }
  }

  /// Request location permission and retry weather fetch
  Future<void> requestLocationPermissionAndFetch() async {
    final granted = await _weatherService.requestLocationPermission();
    if (granted) {
      state = state.copyWith(locationFailureReason: null);
      await fetchCurrentLocation();
    } else {
      state = state.copyWith(
        locationFailureReason: LocationFailureReason.permissionDenied,
      );
    }
  }

  /// Open OS location settings
  Future<void> openLocationSettings() async {
    await _weatherService.openLocationSettings();
  }

  /// Open OS app settings
  Future<void> openAppSettings() async {
    await _weatherService.openAppSettings();
  }

  /// Clear location (allows manual entry)
  void clearLocation() {
    state = state.copyWith(location: null, weatherForecast: null);
  }

  /// Delegate to the main controller for macro generation
  Future<void> generateMacros({
    String? activityId,
    String? eventId,
    String? forUserId,
  }) async {
    DebugLogger.info(
      '🚴 CYCLING CONTROLLER: generateMacros called - activityId: $activityId',
    );
    final currentState = state;
    DebugLogger.info(
      '🚴 CYCLING CONTROLLER: Current state - distance: ${currentState.distance}mi, speed: ${currentState.speedMph}mph',
    );

    // Extract terrain type (e.g., 'flat' from 'flat_outdoor')
    final terrainType = currentState.terrain.split('_')[0];
    final indoorOutdoorType = currentState.terrain.contains('indoor')
        ? 'indoor'
        : 'outdoor';
    DebugLogger.info(
      '🚴 CYCLING CONTROLLER: Extracted terrain: $terrainType, indoorOutdoor: $indoorOutdoorType',
    );

    // Convert units if necessary (Backend expects Miles/MPH)
    double distanceMiles = currentState.distance;
    double speedMph = currentState.speedMph;

    if (currentState.distanceUnit == DistanceUnit.kilometers) {
      // 1 km = 0.621371 miles
      distanceMiles = currentState.distance * 0.621371;
      // Assume speed is in kph if distance is km
      speedMph = currentState.speedMph * 0.621371;
      DebugLogger.info(
        '🚴 CYCLING CONTROLLER: Converted from Metric - Distance: ${currentState.distance}km -> ${distanceMiles.toStringAsFixed(2)}mi, Speed: ${currentState.speedMph}kph -> ${speedMph.toStringAsFixed(2)}mph',
      );
    }

    // Delegate to the main controller
    DebugLogger.info(
      '🚴 CYCLING CONTROLLER: About to call distancePageGutEntryController.generateCyclingMacros...',
    );
    await ref
        .read(macroTargetsControllerProvider.notifier)
        .generateCyclingMacros(
          distanceMiles: distanceMiles,
          speedMph: speedMph,
          terrain: terrainType,
          indoorOutdoor: indoorOutdoorType,
          elevationGainFt: currentState.elevationGainFt,
          sessionGoal: currentState.sessionGoal,
          intensityTarget: currentState.intensityTarget,
          timeBeforeMinutes: currentState.preRideMinutes,
          scheduledDate: currentState.selectedDate,
          scheduledTime: currentState.selectedTime,
          temperatureC: currentState.temperatureC,
          humidityPct: currentState.humidityPct,
          intensity: currentState.intensity,
          activityTitle: currentState.activityTitleManuallySet
              ? currentState.activityTitle
              : null,
          activityId: activityId,
          eventId: eventId,
          forUserId:
              forUserId, // NEW: Pass through forUserId for coach-created activities
        );
    DebugLogger.info(
      '🚴 CYCLING CONTROLLER: distancePageGutEntryController.generateCyclingMacros completed!',
    );
  }
}
