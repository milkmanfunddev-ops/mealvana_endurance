import 'dart:async';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/run_parameters.dart';
import '../../domain/intensity_distribution.dart';
import '../../domain/meal_type.dart';
import '../../../../shared/domain/activity_type.dart';
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

  // V3: Fasted workout toggle
  final bool isFasted;

  // V3: Track if user manually changed the pre-ride timing
  final bool preRideMinutesManuallySet;

  // Weather integration fields
  final weather_domain.Location? location;
  final WeatherForecast? weatherForecast;
  final bool isLoadingLocation;
  final bool isLoadingWeather;
  final bool hasAttemptedWeatherFetch;
  final LocationFailureReason? locationFailureReason;

  CyclingFormState({
    this.distance = 25.0,
    this.speedMph = 15.0,
    this.preRideMinutes = 120, // V3: will be pre-filled from recommendation in controller build()

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
    this.isFasted = false,
    this.preRideMinutesManuallySet = false,
    this.location,
    this.weatherForecast,
    this.isLoadingLocation = false,
    this.isLoadingWeather = false,
    this.hasAttemptedWeatherFetch = false,
    this.locationFailureReason,
  }) : intensity = intensity ?? IntensityDistribution(conversationalPct: 70, tempoPct: 20, allOutPct: 10);

  CyclingFormState copyWith({
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
    bool? isFasted,
    bool? preRideMinutesManuallySet,
    weather_domain.Location? location,
    WeatherForecast? weatherForecast,
    bool? isLoadingLocation,
    bool? isLoadingWeather,
    bool? hasAttemptedWeatherFetch,
    LocationFailureReason? locationFailureReason,
  }) {
    return CyclingFormState(
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
      isFasted: isFasted ?? this.isFasted,
      preRideMinutesManuallySet: preRideMinutesManuallySet ?? this.preRideMinutesManuallySet,
      location: location ?? this.location,
      weatherForecast: weatherForecast ?? this.weatherForecast,
      isLoadingLocation: isLoadingLocation ?? this.isLoadingLocation,
      isLoadingWeather: isLoadingWeather ?? this.isLoadingWeather,
      hasAttemptedWeatherFetch: hasAttemptedWeatherFetch ?? this.hasAttemptedWeatherFetch,
      locationFailureReason: locationFailureReason ?? this.locationFailureReason,
    );
  }
}

/// Cycling Input Controller - manages form state and delegates macro generation
/// FOA COMPLIANT: Contains form state management and business logic coordination
@Riverpod(keepAlive: true)
class CyclingInputController extends _$CyclingInputController {
  WeatherService get _weatherService => ref.read(weatherServiceProvider);

  @override
  CyclingFormState build() {
    final now = DateTime.now();

    // Fetch user profile to get distance unit and default speed
    _loadUserPreferences();

    // Calculate initial estimated duration using default values
    // Default: 25 miles at 15 mph = 1.67 hours = 100 minutes
    final initialDurationMinutes = (25.0 / 15.0 * 60).round();

    // V3: Pre-fill timing from recommendation based on default intensity
    final defaultIntensity = IntensityDistribution(conversationalPct: 70, tempoPct: 20, allOutPct: 10);
    final recommendedMinutes = (recommendedHoursBefore(
      ActivityType.cycling, defaultIntensity,
      durationMinutes: initialDurationMinutes,
    ) * 60).round();

    final initialState = CyclingFormState(
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

  /// Load user preferences
  Future<void> _loadUserPreferences() async {
    try {
      final userRepository = await ref.read(userRepositoryProvider.future);
      final userProfile = await userRepository.getCurrentUser();

      if (userProfile != null) {
        // If user has a default cycling speed, use it to update speed and recalculate duration
        final defaultSpeed = userProfile.defaultCyclingSpeedMph;
        if (defaultSpeed != null && defaultSpeed > 0) {
          state = state.copyWith(
            distanceUnit: userProfile.preferredDistanceUnit,
            speedMph: defaultSpeed,
          );
          // Recalculate estimated duration with user's default speed
          _estimateDuration();
          DebugLogger.info('🚴 CYCLING CONTROLLER: Loaded user preferences - distance unit: ${userProfile.preferredDistanceUnit.name}, default speed: ${defaultSpeed}mph');
        } else {
          state = state.copyWith(
            distanceUnit: userProfile.preferredDistanceUnit,
          );
          DebugLogger.info('🚴 CYCLING CONTROLLER: Loaded user preferences - distance unit: ${userProfile.preferredDistanceUnit.name}');
        }
      }
    } catch (e) {
      DebugLogger.error('🚴 CYCLING CONTROLLER: Failed to load user preferences', error: e);
    }
  }

  /// Fetch location if this controller needs it and doesn't already have it.
  /// Called when this sport tab becomes active or the screen initializes.
  Future<void> fetchLocationIfNeeded() async {
    if (!state.isLoadingLocation && !state.isLoadingWeather && state.location == null) {
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
    final hasDuration =
        state.estimatedDuration != null && state.estimatedDuration!.inSeconds > 0;

    if (state.durationPaceMode == DurationPaceMode.byDuration && hasDuration) {
      final newSpeed = _estimateSpeed(distance: distance, duration: state.estimatedDuration);
      state = state.copyWith(
        distance: distance,
        speedMph: newSpeed ?? state.speedMph,
      );
      _autoUpdateFuelingWindow();
      return;
    }

    state = state.copyWith(distance: distance);
    _estimateDuration(distance: distance, speedMph: state.speedMph);
    _autoUpdateFuelingWindow();
  }

  void updateSpeed(double speedMph) {
    state = state.copyWith(speedMph: speedMph);
    _estimateDuration(distance: state.distance, speedMph: speedMph);
    _autoUpdateFuelingWindow();
  }

  void updatePreRideMinutes(int minutes) {
    state = state.copyWith(
      preRideMinutes: minutes,
      preRideMinutesManuallySet: true,
    );
  }

  /// Auto-update fueling window when duration or intensity changes,
  /// unless user has manually overridden it.
  void _autoUpdateFuelingWindow() {
    if (!state.preRideMinutesManuallySet) {
      final recommended = recommendedHoursBefore(
        ActivityType.cycling, state.intensity,
        durationMinutes: state.estimatedDuration?.inMinutes ?? 90,
      );
      state = state.copyWith(preRideMinutes: (recommended * 60).round());
    }
  }

  /// V3: Update fasted workout toggle
  void updateFasted(bool isFasted) {
    state = state.copyWith(isFasted: isFasted);
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
        humidityPct: 45.0,  // Comfortable room humidity
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
    state = state.copyWith(temperatureC: temperatureC);
  }

  void updateHumidity(double humidityPct) {
    state = state.copyWith(humidityPct: humidityPct);
  }

  void updateWindCondition(String windCondition) {
    state = state.copyWith(windCondition: windCondition);
  }

  void updateSunExposure(String sunExposure) {
    state = state.copyWith(sunExposure: sunExposure);
  }

  void updateDateTime(DateTime date, TimeOfDay time) {
    final currentDate = state.selectedDate;
    final currentTime = state.selectedTime;
    final hasChanged = currentDate.year != date.year ||
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

    // Auto-fetch weather when date/time changes for outdoor rides if location is set.
    if (!isIndoor && state.location != null) {
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
        locationFailureReason: location != null ? null : state.locationFailureReason,
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
      state = state.copyWith(locationFailureReason: LocationFailureReason.permissionDenied);
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
    state = state.copyWith(
      location: null,
      weatherForecast: null,
    );
  }

  /// Delegate to the main controller for macro generation
  Future<void> generateMacros({
    String? activityId,
    String? eventId,
    String? forUserId,
  }) async {
    DebugLogger.info('🚴 CYCLING CONTROLLER: generateMacros called - activityId: $activityId');
    final currentState = state;
    DebugLogger.info('🚴 CYCLING CONTROLLER: Current state - distance: ${currentState.distance}mi, speed: ${currentState.speedMph}mph');

    // Extract terrain type (e.g., 'flat' from 'flat_outdoor')
    final terrainType = currentState.terrain.split('_')[0];
    final indoorOutdoorType = currentState.terrain.contains('indoor') ? 'indoor' : 'outdoor';
    DebugLogger.info('🚴 CYCLING CONTROLLER: Extracted terrain: $terrainType, indoorOutdoor: $indoorOutdoorType');

    // Convert units if necessary (Backend expects Miles/MPH)
    double distanceMiles = currentState.distance;
    double speedMph = currentState.speedMph;

    if (currentState.distanceUnit == DistanceUnit.kilometers) {
      // 1 km = 0.621371 miles
      distanceMiles = currentState.distance * 0.621371;
      // Assume speed is in kph if distance is km
      speedMph = currentState.speedMph * 0.621371;
      DebugLogger.info('🚴 CYCLING CONTROLLER: Converted from Metric - Distance: ${currentState.distance}km -> ${distanceMiles.toStringAsFixed(2)}mi, Speed: ${currentState.speedMph}kph -> ${speedMph.toStringAsFixed(2)}mph');
    }

    // Delegate to the main controller
    DebugLogger.info('🚴 CYCLING CONTROLLER: About to call distancePageGutEntryController.generateCyclingMacros...');
    await ref.read(macroTargetsControllerProvider.notifier).generateCyclingMacros(
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
      isFasted: currentState.isFasted,
      intensity: currentState.intensity,
      activityId: activityId,
      eventId: eventId,
      forUserId: forUserId, // NEW: Pass through forUserId for coach-created activities
    );
    DebugLogger.info('🚴 CYCLING CONTROLLER: distancePageGutEntryController.generateCyclingMacros completed!');
  }
}
