import 'dart:async';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../domain/run_parameters.dart';
import 'distance_page_gut_entry_controller.dart';
import '../../../weather/domain/location.dart' as weather_domain;
import '../../../weather/domain/weather_forecast.dart';
import '../../../weather/application/weather_service.dart';

part 'running_input_controller.g.dart';

/// Running-specific form state that persists during tab switches
class RunningFormState {
  final double distance;
  final double paceMinutes;
  final int preRunMinutes;
  final GutTraining gutTraining;
  final SweatRateCat sweatRate;
  final double temperatureC;
  final double humidityPct;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;

  // Weather integration fields
  final weather_domain.Location? location;
  final WeatherForecast? weatherForecast;
  final bool isLoadingLocation;
  final bool isLoadingWeather;

  const RunningFormState({
    this.distance = 12.0,
    this.paceMinutes = 9.0,
    this.preRunMinutes = 120,
    this.gutTraining = GutTraining.high,
    this.sweatRate = SweatRateCat.medium,
    this.temperatureC = 20.0,
    this.humidityPct = 60.0,
    required this.selectedDate,
    required this.selectedTime,
    this.location,
    this.weatherForecast,
    this.isLoadingLocation = false,
    this.isLoadingWeather = false,
  });

  RunningFormState copyWith({
    double? distance,
    double? paceMinutes,
    int? preRunMinutes,
    GutTraining? gutTraining,
    SweatRateCat? sweatRate,
    double? temperatureC,
    double? humidityPct,
    DateTime? selectedDate,
    TimeOfDay? selectedTime,
    weather_domain.Location? location,
    WeatherForecast? weatherForecast,
    bool? isLoadingLocation,
    bool? isLoadingWeather,
  }) {
    return RunningFormState(
      distance: distance ?? this.distance,
      paceMinutes: paceMinutes ?? this.paceMinutes,
      preRunMinutes: preRunMinutes ?? this.preRunMinutes,
      gutTraining: gutTraining ?? this.gutTraining,
      sweatRate: sweatRate ?? this.sweatRate,
      temperatureC: temperatureC ?? this.temperatureC,
      humidityPct: humidityPct ?? this.humidityPct,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedTime: selectedTime ?? this.selectedTime,
      location: location ?? this.location,
      weatherForecast: weatherForecast ?? this.weatherForecast,
      isLoadingLocation: isLoadingLocation ?? this.isLoadingLocation,
      isLoadingWeather: isLoadingWeather ?? this.isLoadingWeather,
    );
  }
}

/// Running Input Controller - manages form state and delegates macro generation
/// FOA COMPLIANT: Contains form state management and business logic coordination
@Riverpod(keepAlive: true)
class RunningInputController extends _$RunningInputController {
  WeatherService get _weatherService => ref.read(weatherServiceProvider);

  @override
  RunningFormState build() {
    final now = DateTime.now();

    final initialState = RunningFormState(
      selectedDate: now,
      selectedTime: const TimeOfDay(hour: 7, minute: 0),
    );

    // Auto-fetch location and weather on first build
    Future.microtask(() async {

      // Always fetch location and weather on first build
      if (!state.isLoadingLocation && !state.isLoadingWeather) {
        if (state.location == null) {
          await fetchCurrentLocation();
        } else {
          await fetchWeatherForecast();
        }
      } else {
      }
    });

    return initialState;
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

  void updatePace(double paceMinutes) {
    state = state.copyWith(paceMinutes: paceMinutes);
  }

  void updatePreRunMinutes(int minutes) {
    state = state.copyWith(preRunMinutes: minutes);
  }

  void updateGutTraining(GutTraining gutTraining) {
    state = state.copyWith(gutTraining: gutTraining);
  }

  void updateSweatRate(SweatRateCat sweatRate) {
    state = state.copyWith(sweatRate: sweatRate);
  }

  void updateTemperature(double temperatureC) {
    state = state.copyWith(temperatureC: temperatureC);
  }

  void updateHumidity(double humidityPct) {
    state = state.copyWith(humidityPct: humidityPct);
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
          temperatureC: forecast.temperatureC.clamp(-5.0, 40.0),
          humidityPct: forecast.humidityPct.toDouble().clamp(20.0, 95.0),
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
  }) async {
    final currentState = state;

    // Convert pace to M:SS format
    final paceMinutePart = currentState.paceMinutes.floor();
    final paceSecondPart = ((currentState.paceMinutes - paceMinutePart) * 60).round();
    final paceText = '$paceMinutePart:${paceSecondPart.toString().padLeft(2, '0')}';

    // Delegate to the main controller
    await ref.read(distancePageGutEntryControllerProvider.notifier).generateRunningMacros(
      distanceText: currentState.distance.toString(),
      paceText: paceText,
      timeBeforeRunMinutes: currentState.preRunMinutes,
      gutTraining: currentState.gutTraining,
      distanceUnit: DistanceUnit.miles,
      paceUnit: PaceUnit.minPerMile,
      scheduledDate: currentState.selectedDate,
      scheduledTime: currentState.selectedTime,
      sweatRateCat: currentState.sweatRate,
      temperatureC: currentState.temperatureC,
      humidityPct: currentState.humidityPct,
      activityId: activityId,
      eventId: eventId,
    );
  }
}
