import 'dart:async';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'macro_targets_controller.dart';
import '../../../weather/domain/location.dart' as weather_domain;
import '../../../weather/domain/weather_forecast.dart';
import '../../../weather/application/weather_service.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';

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

  // Weather integration fields
  final weather_domain.Location? location;
  final WeatherForecast? weatherForecast;
  final bool isLoadingLocation;
  final bool isLoadingWeather;

  const CyclingFormState({
    this.distance = 25.0,
    this.speedMph = 15.0,
    this.preRideMinutes = 120,
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
    this.location,
    this.weatherForecast,
    this.isLoadingLocation = false,
    this.isLoadingWeather = false,
  });

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
    weather_domain.Location? location,
    WeatherForecast? weatherForecast,
    bool? isLoadingLocation,
    bool? isLoadingWeather,
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
      location: location ?? this.location,
      weatherForecast: weatherForecast ?? this.weatherForecast,
      isLoadingLocation: isLoadingLocation ?? this.isLoadingLocation,
      isLoadingWeather: isLoadingWeather ?? this.isLoadingWeather,
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

    final initialState = CyclingFormState(
      selectedDate: now,
      selectedTime: const TimeOfDay(hour: 7, minute: 0),
    );

    // NOTE: Location fetching is now triggered explicitly when this tab becomes active
    // or when user opens the screen. This prevents race conditions where multiple
    // controllers try to request location permissions simultaneously.
    // See: fetchLocationIfNeeded() method

    return initialState;
  }

  /// Fetch location if this controller needs it and doesn't already have it.
  /// Called when this sport tab becomes active or the screen initializes.
  Future<void> fetchLocationIfNeeded() async {
    if (!state.isLoadingLocation && !state.isLoadingWeather && state.location == null) {
      await fetchCurrentLocation();
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
    state = state.copyWith(distance: distance);
  }

  void updateSpeed(double speedMph) {
    state = state.copyWith(speedMph: speedMph);
  }

  void updatePreRideMinutes(int minutes) {
    state = state.copyWith(preRideMinutes: minutes);
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
    state = state.copyWith(
      selectedDate: date,
      selectedTime: time,
    );

    // Auto-fetch weather when date changes if location is set
    if (state.location != null) {
      fetchWeatherForecast();
    }
  }

  /// Fetch current GPS location
  Future<void> fetchCurrentLocation() async {
    state = state.copyWith(isLoadingLocation: true);

    try {
      final location = await _weatherService.getCurrentLocation();
      state = state.copyWith(
        location: location,
        isLoadingLocation: false,
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
    state = state.copyWith(isLoadingWeather: true);

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
        );
      } else {
        state = state.copyWith(
          weatherForecast: forecast,
          isLoadingWeather: false,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoadingWeather: false);
    }
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

    // Delegate to the main controller
    DebugLogger.info('🚴 CYCLING CONTROLLER: About to call distancePageGutEntryController.generateCyclingMacros...');
    await ref.read(macroTargetsControllerProvider.notifier).generateCyclingMacros(
      distanceMiles: currentState.distance,
      speedMph: currentState.speedMph,
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
      activityId: activityId,
      eventId: eventId,
      forUserId: forUserId, // NEW: Pass through forUserId for coach-created activities
    );
    DebugLogger.info('🚴 CYCLING CONTROLLER: distancePageGutEntryController.generateCyclingMacros completed!');
  }
}
