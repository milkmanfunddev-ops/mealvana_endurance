import 'dart:async';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'macro_targets_controller.dart';
import '../../../weather/domain/location.dart' as weather_domain;
import '../../../weather/domain/weather_forecast.dart';
import '../../../weather/application/weather_service.dart';

part 'swimming_input_controller.g.dart';

/// Swimming-specific form state that persists during tab switches
class SwimmingFormState {
  final int distanceMeters;
  final int pacePer100mSeconds;
  final int preSwimMinutes;
  final String intensityTarget;
  final String sessionGoal;
  final String poolOrOpenWater;
  final double waterTempC;
  final bool showEnvironment;
  final double deckTemperature;
  final double deckHumidity;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;

  // Weather integration fields
  final weather_domain.Location? location;
  final WeatherForecast? weatherForecast;
  final bool isLoadingLocation;
  final bool isLoadingWeather;

  const SwimmingFormState({
    this.distanceMeters = 2000,
    this.pacePer100mSeconds = 120,
    this.preSwimMinutes = 120,
    this.intensityTarget = 'zone_2',
    this.sessionGoal = 'endurance',
    this.poolOrOpenWater = 'pool',
    this.waterTempC = 26.0,
    this.showEnvironment = false,
    this.deckTemperature = 24.0,
    this.deckHumidity = 70.0,
    required this.selectedDate,
    required this.selectedTime,
    this.location,
    this.weatherForecast,
    this.isLoadingLocation = false,
    this.isLoadingWeather = false,
  });

  SwimmingFormState copyWith({
    int? distanceMeters,
    int? pacePer100mSeconds,
    int? preSwimMinutes,
    String? intensityTarget,
    String? sessionGoal,
    String? poolOrOpenWater,
    double? waterTempC,
    bool? showEnvironment,
    double? deckTemperature,
    double? deckHumidity,
    DateTime? selectedDate,
    TimeOfDay? selectedTime,
    weather_domain.Location? location,
    WeatherForecast? weatherForecast,
    bool? isLoadingLocation,
    bool? isLoadingWeather,
  }) {
    return SwimmingFormState(
      distanceMeters: distanceMeters ?? this.distanceMeters,
      pacePer100mSeconds: pacePer100mSeconds ?? this.pacePer100mSeconds,
      preSwimMinutes: preSwimMinutes ?? this.preSwimMinutes,
      intensityTarget: intensityTarget ?? this.intensityTarget,
      sessionGoal: sessionGoal ?? this.sessionGoal,
      poolOrOpenWater: poolOrOpenWater ?? this.poolOrOpenWater,
      waterTempC: waterTempC ?? this.waterTempC,
      showEnvironment: showEnvironment ?? this.showEnvironment,
      deckTemperature: deckTemperature ?? this.deckTemperature,
      deckHumidity: deckHumidity ?? this.deckHumidity,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedTime: selectedTime ?? this.selectedTime,
      location: location ?? this.location,
      weatherForecast: weatherForecast ?? this.weatherForecast,
      isLoadingLocation: isLoadingLocation ?? this.isLoadingLocation,
      isLoadingWeather: isLoadingWeather ?? this.isLoadingWeather,
    );
  }
}

/// Swimming Input Controller - manages form state and delegates macro generation
/// FOA COMPLIANT: Contains form state management and business logic coordination
@Riverpod(keepAlive: true)
class SwimmingInputController extends _$SwimmingInputController {
  WeatherService get _weatherService => ref.read(weatherServiceProvider);

  @override
  SwimmingFormState build() {
    final now = DateTime.now();

    final initialState = SwimmingFormState(
      selectedDate: now,
      selectedTime: const TimeOfDay(hour: 6, minute: 0),
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
  void updateDistance(int distanceMeters) {
    state = state.copyWith(distanceMeters: distanceMeters);
  }

  void updatePace(int pacePer100mSeconds) {
    state = state.copyWith(pacePer100mSeconds: pacePer100mSeconds);
  }

  void updatePreSwimMinutes(int minutes) {
    state = state.copyWith(preSwimMinutes: minutes);
  }

  void updateIntensityTarget(String intensityTarget) {
    state = state.copyWith(intensityTarget: intensityTarget);
  }

  void updateSessionGoal(String sessionGoal) {
    state = state.copyWith(sessionGoal: sessionGoal);
  }

  void updatePoolOrOpenWater(String poolOrOpenWater) {
    state = state.copyWith(poolOrOpenWater: poolOrOpenWater);
  }

  void updateWaterTemp(double waterTempC) {
    state = state.copyWith(waterTempC: waterTempC);
  }

  void toggleEnvironmentSection() {
    state = state.copyWith(showEnvironment: !state.showEnvironment);
  }

  void updateDeckTemperature(double deckTemperature) {
    state = state.copyWith(deckTemperature: deckTemperature);
  }

  void updateDeckHumidity(double deckHumidity) {
    state = state.copyWith(deckHumidity: deckHumidity);
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

      // Update deck temp/humidity from forecast if available
      if (forecast.forecastAvailable) {
        state = state.copyWith(
          weatherForecast: forecast,
          deckTemperature: forecast.temperatureC,
          deckHumidity: forecast.humidityPct.toDouble(),
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
    final currentState = state;

    // Delegate to the main controller
    await ref.read(macroTargetsControllerProvider.notifier).generateSwimmingMacros(
      distanceMeters: currentState.distanceMeters,
      paceSecondsper100m: currentState.pacePer100mSeconds,
      poolOrOpenWater: currentState.poolOrOpenWater,
      waterTempC: currentState.waterTempC,
      intensityTarget: currentState.intensityTarget,
      sessionGoal: currentState.sessionGoal,
      timeBeforeMinutes: currentState.preSwimMinutes,
      scheduledDate: currentState.selectedDate,
      scheduledTime: currentState.selectedTime,
      activityId: activityId,
      eventId: eventId,
      forUserId: forUserId, // NEW: Pass through forUserId for coach-created activities
    );
  }
}
