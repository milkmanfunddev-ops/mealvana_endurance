import 'dart:async';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../auth/data/user_repository.dart';
import '../../../integrations/presentation/providers/athlete_zones_provider.dart';
import '../../domain/run_parameters.dart';
import '../../domain/intensity_distribution.dart';
import '../../domain/meal_type.dart';
import '../../../../shared/domain/activity_type.dart';
import 'macro_targets_controller.dart';
import '../../../weather/domain/location.dart' as weather_domain;
import '../../../weather/domain/weather_forecast.dart';
import '../../../weather/application/weather_service.dart';
import '../../../../core/utils/debug_logger.dart';
import '../../../../shared/services/location_service.dart';
import '../../../../shared/widgets/kyle_design/inputs/duration_pace_toggle.dart';

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
  final DistanceUnit distanceUnit;
  final PaceUnit paceUnit;

  // Intensity distribution
  final IntensityDistribution intensity;

  // Duration/Pace mode
  final DurationPaceMode durationPaceMode;

  // Estimated duration (calculated from distance and pace)
  final Duration? estimatedDuration;

  // Zone-based pace suggestion
  final bool zonePaceApplied;
  final double? zoneSuggestedPace;

  // V3: Fasted workout toggle
  final bool isFasted;

  // V3: Track if user manually changed the pre-run timing
  final bool preRunMinutesManuallySet;

  // Weather integration fields
  final weather_domain.Location? location;
  final WeatherForecast? weatherForecast;
  final bool isLoadingLocation;
  final bool isLoadingWeather;
  final bool hasAttemptedWeatherFetch;
  final LocationFailureReason? locationFailureReason;

  RunningFormState({
    this.distance = 12.0,
    this.paceMinutes = 9.0,
    this.preRunMinutes = 150, // V3: default from recommendedHoursBefore (2.5h for moderate running)
    this.gutTraining = GutTraining.moderate,
    this.sweatRate = SweatRateCat.medium,
    this.temperatureC = 20.0,
    this.humidityPct = 60.0,
    required this.selectedDate,
    required this.selectedTime,
    this.distanceUnit = DistanceUnit.miles,
    this.paceUnit = PaceUnit.minPerMile,
    IntensityDistribution? intensity,
    this.durationPaceMode = DurationPaceMode.byDuration,
    this.estimatedDuration,
    this.isFasted = false,
    this.preRunMinutesManuallySet = false,
    this.zonePaceApplied = false,
    this.zoneSuggestedPace,
    this.location,
    this.weatherForecast,
    this.isLoadingLocation = false,
    this.isLoadingWeather = false,
    this.hasAttemptedWeatherFetch = false,
    this.locationFailureReason,
  }) : intensity = intensity ?? IntensityDistribution.defaultDistribution();

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
    DistanceUnit? distanceUnit,
    PaceUnit? paceUnit,
    IntensityDistribution? intensity,
    DurationPaceMode? durationPaceMode,
    Duration? estimatedDuration,
    bool? isFasted,
    bool? preRunMinutesManuallySet,
    bool? zonePaceApplied,
    double? zoneSuggestedPace,
    weather_domain.Location? location,
    WeatherForecast? weatherForecast,
    bool? isLoadingLocation,
    bool? isLoadingWeather,
    bool? hasAttemptedWeatherFetch,
    LocationFailureReason? locationFailureReason,
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
      distanceUnit: distanceUnit ?? this.distanceUnit,
      paceUnit: paceUnit ?? this.paceUnit,
      intensity: intensity ?? this.intensity,
      durationPaceMode: durationPaceMode ?? this.durationPaceMode,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      isFasted: isFasted ?? this.isFasted,
      preRunMinutesManuallySet: preRunMinutesManuallySet ?? this.preRunMinutesManuallySet,
      zonePaceApplied: zonePaceApplied ?? this.zonePaceApplied,
      zoneSuggestedPace: zoneSuggestedPace ?? this.zoneSuggestedPace,
      location: location ?? this.location,
      weatherForecast: weatherForecast ?? this.weatherForecast,
      isLoadingLocation: isLoadingLocation ?? this.isLoadingLocation,
      isLoadingWeather: isLoadingWeather ?? this.isLoadingWeather,
      hasAttemptedWeatherFetch: hasAttemptedWeatherFetch ?? this.hasAttemptedWeatherFetch,
      locationFailureReason: locationFailureReason ?? this.locationFailureReason,
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

    // Fetch user profile to get gut training and sweat rate
    // This is done asynchronously, so we start with defaults
    _loadUserPreferences();

    // Calculate initial estimated duration (12 miles * 9 min/mile = 108 minutes = 1:48)
    const defaultDistance = 12.0;
    const defaultPace = 9.0;
    final initialDuration = Duration(
      minutes: (defaultDistance * defaultPace).floor(),
      seconds: (((defaultDistance * defaultPace) - (defaultDistance * defaultPace).floor()) * 60).round(),
    );

    // V3: Pre-fill timing from recommendation based on default intensity
    final defaultIntensity = IntensityDistribution.defaultDistribution();
    final recommendedMinutes = (recommendedHoursBefore(
      ActivityType.running, defaultIntensity,
      durationMinutes: initialDuration.inMinutes,
    ) * 60).round();

    final initialState = RunningFormState(
      selectedDate: now,
      selectedTime: const TimeOfDay(hour: 7, minute: 0),
      // Default values - will be updated when user profile loads
      gutTraining: GutTraining.moderate,
      sweatRate: SweatRateCat.medium,
      distance: defaultDistance,
      paceMinutes: defaultPace,
      preRunMinutes: recommendedMinutes,
      estimatedDuration: initialDuration,
      intensity: defaultIntensity,
      durationPaceMode: DurationPaceMode.byDuration,
    );

    // NOTE: Location fetching is now triggered explicitly when this tab becomes active
    // or when user opens the screen. This prevents race conditions where multiple
    // controllers try to request location permissions simultaneously.
    // See: fetchLocationIfNeeded() method

    return initialState;
  }

  /// Try to load zone-based pace suggestion from Training Peaks zones.
  ///
  /// Fetches the athlete's Zone 2 pace and applies it as the default pace
  /// if available. This is called once when the tab becomes active.
  Future<void> applyZonePaceIfAvailable(String userId) async {
    if (state.zonePaceApplied) return; // Only apply once
    // Avoid overriding an existing pace (e.g., from event data or manual edits)
    if (state.paceMinutes != 9.0) return;

    try {
      final zone2Pace = await ref.read(zone2PaceMinPerMileProvider(userId).future);
      if (zone2Pace != null && zone2Pace > 4.0 && zone2Pace < 20.0) {
        state = state.copyWith(
          paceMinutes: zone2Pace,
          zonePaceApplied: true,
          zoneSuggestedPace: zone2Pace,
          estimatedDuration: _estimateDuration(paceMinutes: zone2Pace),
        );
        DebugLogger.info('🏃 RUNNING CONTROLLER: Applied zone-based pace: ${zone2Pace.toStringAsFixed(1)} min/mi');
      }
    } catch (e) {
      // Non-blocking - keep default pace if zone fetch fails
      DebugLogger.error('🏃 RUNNING CONTROLLER: Zone pace unavailable', error: e);
    }
  }

  /// Load gut training and sweat rate from user profile
  Future<void> _loadUserPreferences() async {
    try {
      final userRepository = await ref.read(userRepositoryProvider.future);
      final userProfile = await userRepository.getCurrentUser();

      if (userProfile != null) {
        state = state.copyWith(
          gutTraining: userProfile.gutTraining,
          sweatRate: userProfile.sweatRate,
          distanceUnit: userProfile.preferredDistanceUnit,
          paceUnit: userProfile.preferredPaceUnit,
        );
        DebugLogger.info('🏃 RUNNING CONTROLLER: Loaded user preferences - gut training: ${userProfile.gutTraining.name}, sweat rate: ${userProfile.sweatRate.name}');
      }
    } catch (e) {
      DebugLogger.error('🏃 RUNNING CONTROLLER: Failed to load user preferences', error: e);
      // Keep defaults on error
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
      final newPace = _estimatePace(distance: distance, duration: state.estimatedDuration);
      state = state.copyWith(
        distance: distance,
        paceMinutes: newPace ?? state.paceMinutes,
      );
      _autoUpdateFuelingWindow();
      return;
    }

    state = state.copyWith(
      distance: distance,
      estimatedDuration: _estimateDuration(distance: distance),
    );
    _autoUpdateFuelingWindow();
  }

  void updatePace(double paceMinutes) {
    state = state.copyWith(
      paceMinutes: paceMinutes,
      estimatedDuration: _estimateDuration(paceMinutes: paceMinutes),
    );
    _autoUpdateFuelingWindow();
  }

  void updateIntensityDistribution(IntensityDistribution intensity) {
    state = state.copyWith(intensity: intensity);
    _autoUpdateFuelingWindow();
  }

  void updateDuration(Duration duration) {
    final newPace = _estimatePace(duration: duration);
    state = state.copyWith(
      estimatedDuration: duration,
      paceMinutes: newPace ?? state.paceMinutes,
    );
    _autoUpdateFuelingWindow();
  }

  void updateDurationPaceMode(DurationPaceMode mode) {
    if (mode == DurationPaceMode.byDuration) {
      state = state.copyWith(
        durationPaceMode: mode,
        estimatedDuration: state.estimatedDuration ?? _estimateDuration(),
      );
      return;
    }

    final newPace = _estimatePace();
    state = state.copyWith(
      durationPaceMode: mode,
      paceMinutes: newPace ?? state.paceMinutes,
    );
  }

  /// Calculate estimated duration from distance and pace.
  ///
  /// When mode is byDuration: use user's default pace from profile if available,
  /// or fall back to current pace value.
  ///
  /// Formula: estimatedDuration = distance * paceMinutesPerMile
  Duration _estimateDuration({
    double? distance,
    double? paceMinutes,
  }) {
    final currentDistance = distance ?? state.distance;
    final currentPace = paceMinutes ?? state.paceMinutes;

    // Calculate total minutes
    final totalMinutes = currentDistance * currentPace;

    // Convert to Duration
    final minutes = totalMinutes.floor();
    final seconds = ((totalMinutes - minutes) * 60).round();

    return Duration(minutes: minutes, seconds: seconds);
  }

  /// Calculate pace (minutes per unit) from duration and distance.
  double? _estimatePace({
    double? distance,
    Duration? duration,
  }) {
    final currentDistance = distance ?? state.distance;
    final currentDuration = duration ?? state.estimatedDuration;

    if (currentDuration == null || currentDistance <= 0) {
      return null;
    }

    final totalMinutes = currentDuration.inSeconds / 60.0;
    if (totalMinutes <= 0) {
      return null;
    }

    return totalMinutes / currentDistance;
  }

  void updatePreRunMinutes(int minutes) {
    state = state.copyWith(
      preRunMinutes: minutes,
      preRunMinutesManuallySet: true,
    );
  }

  /// Auto-update fueling window when duration or intensity changes,
  /// unless user has manually overridden it.
  void _autoUpdateFuelingWindow() {
    if (!state.preRunMinutesManuallySet) {
      final recommended = recommendedHoursBefore(
        ActivityType.running, state.intensity,
        durationMinutes: state.estimatedDuration?.inMinutes ?? 90,
      );
      state = state.copyWith(preRunMinutes: (recommended * 60).round());
    }
  }

  /// V3: Update fasted workout toggle
  void updateFasted(bool isFasted) {
    state = state.copyWith(isFasted: isFasted);
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
    final currentDate = state.selectedDate;
    final currentTime = state.selectedTime;
    final hasChanged = currentDate.year != date.year ||
        currentDate.month != date.month ||
        currentDate.day != date.day ||
        currentTime.hour != time.hour ||
        currentTime.minute != time.minute;

    if (!hasChanged) return;

    state = state.copyWith(
      selectedDate: date,
      selectedTime: time,
      // Reset to defaults immediately while refreshed forecast loads.
      temperatureC: 20.0,
      humidityPct: 60.0,
    );

    // Auto-fetch weather when date/time changes if location is set.
    if (state.location != null) {
      unawaited(fetchWeatherForecast());
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
          temperatureC: forecast.temperatureC.clamp(-5.0, 40.0),
          humidityPct: forecast.humidityPct.toDouble().clamp(20.0, 95.0),
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
    String? forUserId, // NEW: If provided, create activity for this user (coach creating for athlete)
  }) async {
    final currentState = state;

    DebugLogger.info('🏃 RUNNING CONTROLLER: generateMacros called');
    DebugLogger.info('📍 RUNNING CONTROLLER: Current state - distance: ${currentState.distance}, pace: ${currentState.paceMinutes}');

    // Convert pace to M:SS format
    final paceMinutePart = currentState.paceMinutes.floor();
    final paceSecondPart = ((currentState.paceMinutes - paceMinutePart) * 60).round();
    final paceText = '$paceMinutePart:${paceSecondPart.toString().padLeft(2, '0')}';

    DebugLogger.info('⏩ RUNNING CONTROLLER: Delegating to distancePageGutEntryController.generateRunningMacros...');

    // Delegate to the main controller
    await ref.read(macroTargetsControllerProvider.notifier).generateRunningMacros(
      distanceText: currentState.distance.toString(),
      paceText: paceText,
      timeBeforeRunMinutes: currentState.preRunMinutes,
      gutTraining: currentState.gutTraining,
      distanceUnit: currentState.distanceUnit,
      paceUnit: currentState.paceUnit,
      scheduledDate: currentState.selectedDate,
      scheduledTime: currentState.selectedTime,
      sweatRateCat: currentState.sweatRate,
      temperatureC: currentState.temperatureC,
      humidityPct: currentState.humidityPct,
      isFasted: currentState.isFasted,
      intensity: currentState.intensity,
      activityId: activityId,
      eventId: eventId,
      forUserId: forUserId, // NEW: Pass through forUserId for coach-created activities
    );

    DebugLogger.info('✅ RUNNING CONTROLLER: generateRunningMacros completed successfully');
  }
}
