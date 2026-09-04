import 'dart:async';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/fueling_window_limits.dart';
import '../../domain/intensity_distribution.dart';
import '../../domain/fueling_window_authority.dart';
import '../../domain/run_parameters.dart' show UnitSystem;
import '../../../activities/domain/activity_title_formatter.dart';
import '../../../auth/data/user_repository.dart';
import 'macro_targets_controller.dart';
import '../../../integrations/presentation/providers/athlete_zones_provider.dart';
import '../../../weather/domain/location.dart' as weather_domain;
import '../../../weather/domain/weather_forecast.dart';
import '../../../weather/application/weather_service.dart';
import '../../../../shared/services/location_service.dart';
import '../../../../shared/widgets/kyle_design/inputs/duration_pace_toggle.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';

part 'swimming_input_controller.g.dart';

/// Swimming-specific form state that persists during tab switches
class SwimmingFormState {
  final String activityTitle;
  final bool activityTitleManuallySet;
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

  // Intensity distribution fields
  final IntensityDistribution intensity;
  final DurationPaceMode durationPaceMode;
  final Duration? estimatedDuration;

  // Zone-based pace suggestion
  final bool zonePaceApplied;
  final int? zoneSuggestedPacePer100mSeconds;

  // V3: Track if user manually changed the pre-swim timing
  final bool preSwimMinutesManuallySet;

  // Unit system preference (imperial = °F, metric = °C)
  final UnitSystem unitSystem;

  // Weather integration fields
  final weather_domain.Location? location;
  final WeatherForecast? weatherForecast;
  final bool isLoadingLocation;
  final bool isLoadingWeather;
  final bool hasAttemptedWeatherFetch;
  final LocationFailureReason? locationFailureReason;

  SwimmingFormState({
    this.activityTitle = '2000 m Swim',
    this.activityTitleManuallySet = false,
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
    IntensityDistribution? intensity,
    // CF-6 reference rendering: the create flow opens PACE-held
    // (duration wears EST.) — the prototype's default `held: 'pace'`.
    this.durationPaceMode = DurationPaceMode.byPace,
    this.estimatedDuration,
    this.zonePaceApplied = false,
    this.zoneSuggestedPacePer100mSeconds,
    this.preSwimMinutesManuallySet = false,
    this.unitSystem = UnitSystem.imperial,
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

  SwimmingFormState copyWith({
    String? activityTitle,
    bool? activityTitleManuallySet,
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
    IntensityDistribution? intensity,
    DurationPaceMode? durationPaceMode,
    Duration? estimatedDuration,
    bool? zonePaceApplied,
    int? zoneSuggestedPacePer100mSeconds,
    bool? preSwimMinutesManuallySet,
    UnitSystem? unitSystem,
    weather_domain.Location? location,
    WeatherForecast? weatherForecast,
    bool? isLoadingLocation,
    bool? isLoadingWeather,
    bool? hasAttemptedWeatherFetch,
    LocationFailureReason? locationFailureReason,
  }) {
    return SwimmingFormState(
      activityTitle: activityTitle ?? this.activityTitle,
      activityTitleManuallySet:
          activityTitleManuallySet ?? this.activityTitleManuallySet,
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
      intensity: intensity ?? this.intensity,
      durationPaceMode: durationPaceMode ?? this.durationPaceMode,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      zonePaceApplied: zonePaceApplied ?? this.zonePaceApplied,
      zoneSuggestedPacePer100mSeconds:
          zoneSuggestedPacePer100mSeconds ??
          this.zoneSuggestedPacePer100mSeconds,
      preSwimMinutesManuallySet:
          preSwimMinutesManuallySet ?? this.preSwimMinutesManuallySet,
      unitSystem: unitSystem ?? this.unitSystem,
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

/// Swimming Input Controller - manages form state and delegates macro generation
/// FOA COMPLIANT: Contains form state management and business logic coordination
@Riverpod(keepAlive: true)
class SwimmingInputController extends _$SwimmingInputController {
  WeatherService get _weatherService => ref.read(weatherServiceProvider);

  @override
  SwimmingFormState build() {
    final now = DateTime.now();

    // Calculate initial estimated duration using default values
    // Default: 2000 meters at 120 seconds per 100m = 20 * 120 seconds = 2400 seconds = 40 minutes
    final initialDurationMinutes = ((2000 / 100) * 120 / 60).round();

    // V3: Pre-fill timing from recommendation based on default intensity
    final defaultIntensity = IntensityDistribution(
      conversationalPct: 70,
      tempoPct: 20,
      allOutPct: 10,
    );
    // §3a (food-recommendation, RATIFIED 2026-09-03): default from the
    // ratified sport-neutral table; the per-sport formula is retired.
    const defaultStart = TimeOfDay(hour: 6, minute: 0);
    final recommendedMinutes = defaultFuelingWindowMinutes(
      durationMinutes: initialDurationMinutes,
      intensity: defaultIntensity,
      startHour: defaultStart.hour,
      minutesUntilStart: _minutesUntil(now, now, defaultStart),
    );

    // Load unit system from user preferences
    _loadUserPreferences();

    final initialState = SwimmingFormState(
      activityTitle: ActivityTitleFormatter.formatSwimmingTitle(2000),
      selectedDate: now,
      selectedTime: const TimeOfDay(hour: 6, minute: 0),
      preSwimMinutes: recommendedMinutes,
      estimatedDuration: Duration(minutes: initialDurationMinutes),
    );

    // NOTE: Location fetching is now triggered explicitly when this tab becomes active
    // or when user opens the screen. This prevents race conditions where multiple
    // controllers try to request location permissions simultaneously.
    // See: fetchLocationIfNeeded() method

    return initialState;
  }

  /// Load unit system from user profile
  Future<void> _loadUserPreferences() async {
    try {
      final userRepository = await ref.read(userRepositoryProvider.future);
      final userProfile = await userRepository.getCurrentUser();

      if (userProfile != null) {
        state = state.copyWith(unitSystem: userProfile.unitSystem);
        DebugLogger.info(
          '🏊 SWIMMING CONTROLLER: Loaded user preferences - unitSystem: ${userProfile.unitSystem.name}',
        );
      }
    } catch (e) {
      DebugLogger.error(
        '🏊 SWIMMING CONTROLLER: Failed to load user preferences',
        error: e,
      );
    }
  }

  /// Try to load zone-based swim pace suggestion from Training Peaks zones.
  ///
  /// Fetches the athlete's Zone 2 swim pace (sec/100m) and applies it as the default pace
  /// if available. This is called once when the tab becomes active.
  Future<void> applyZonePaceIfAvailable(String userId) async {
    if (state.zonePaceApplied) return; // Only apply once
    // Avoid overriding an existing pace (e.g., from event data or manual edits)
    if (state.pacePer100mSeconds != 120) return;

    try {
      final zones = await ref.read(athleteZonesProvider(userId).future);
      final zone2PaceSeconds = zones?.zone2SwimPaceSecondsPer100m;
      if (zone2PaceSeconds != null &&
          zone2PaceSeconds > 30 &&
          zone2PaceSeconds < 300) {
        final paceSeconds = zone2PaceSeconds.round();
        final estimatedSeconds = ((state.distanceMeters / 100) * paceSeconds)
            .round();
        state = state.copyWith(
          pacePer100mSeconds: paceSeconds,
          zonePaceApplied: true,
          zoneSuggestedPacePer100mSeconds: paceSeconds,
          estimatedDuration: Duration(seconds: estimatedSeconds),
        );
        DebugLogger.info(
          '🏊 SWIMMING CONTROLLER: Applied zone-based pace: ${paceSeconds}s/100m',
        );
      }
    } catch (e) {
      // Non-blocking - keep default pace if zone fetch fails
      DebugLogger.error(
        '🏊 SWIMMING CONTROLLER: Zone pace unavailable',
        error: e,
      );
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
  void updateDistance(int distanceMeters) {
    final resolvedTitle = state.activityTitleManuallySet
        ? state.activityTitle
        : ActivityTitleFormatter.formatSwimmingTitle(distanceMeters);
    final hasDuration =
        state.estimatedDuration != null &&
        state.estimatedDuration!.inSeconds > 0;

    if (state.durationPaceMode == DurationPaceMode.byDuration && hasDuration) {
      final newPace = _estimatePaceFromDuration(
        distanceMeters: distanceMeters,
        duration: state.estimatedDuration,
      );
      state = state.copyWith(
        activityTitle: resolvedTitle,
        distanceMeters: distanceMeters,
        pacePer100mSeconds: newPace ?? state.pacePer100mSeconds,
      );
      _autoUpdateFuelingWindow();
      return;
    }

    state = state.copyWith(
      activityTitle: resolvedTitle,
      distanceMeters: distanceMeters,
    );
    _estimateDuration(
      distanceMeters: distanceMeters,
      pacePer100mSeconds: state.pacePer100mSeconds,
    );
    _autoUpdateFuelingWindow();
  }

  void updatePace(int pacePer100mSeconds) {
    state = state.copyWith(pacePer100mSeconds: pacePer100mSeconds);
    _estimateDuration(
      distanceMeters: state.distanceMeters,
      pacePer100mSeconds: pacePer100mSeconds,
    );
    _autoUpdateFuelingWindow();
  }

  void updatePreSwimMinutes(int minutes) {
    // D-016: clamp into the ratified 0–240 domain — pre-cap activities can
    // carry persisted lead times up to 480 (see FuelingWindowLimits).
    final cap = fuelingWindowMaxMinutes();
    final capped = minutes < cap ? minutes : cap;
    state = state.copyWith(
      preSwimMinutes: clampFuelingWindowMinutes(capped),
      preSwimMinutesManuallySet: true,
    );
  }

  /// Auto-update fueling window when duration, intensity or schedule
  /// changes, unless user has manually overridden it (food-recommendation
  /// §3/§3a: table default + clamp; CF-1/CF-2).
  void _autoUpdateFuelingWindow() {
    if (!state.preSwimMinutesManuallySet) {
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
        preSwimMinutes: clampFuelingWindowMinutes(recommended),
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

    state = state.copyWith(
      selectedDate: date,
      selectedTime: time,
      // Reset to defaults immediately while refreshed forecast loads.
      deckTemperature: 24.0,
      deckHumidity: 70.0,
    );

    // §3a: the default window depends on start time (early-start overlay +
    // clamp), so a schedule change re-derives it unless manually set.
    _autoUpdateFuelingWindow();

    // Auto-fetch weather when date/time changes if location is set
    // or if weather was previously fetched successfully (via GPS fallback).
    if (state.location != null || state.weatherForecast != null) {
      unawaited(fetchWeatherForecast());
    }
  }

  /// Update intensity distribution
  void updateIntensityDistribution(IntensityDistribution intensity) {
    state = state.copyWith(intensity: intensity);
    _autoUpdateFuelingWindow();
  }

  void updateDuration(Duration duration) {
    final newPace = _estimatePaceFromDuration(duration: duration);
    state = state.copyWith(
      estimatedDuration: duration,
      pacePer100mSeconds: newPace ?? state.pacePer100mSeconds,
    );
    _autoUpdateFuelingWindow();
  }

  /// Update duration/pace mode
  void updateDurationPaceMode(DurationPaceMode mode) {
    if (mode == DurationPaceMode.byDuration) {
      state = state.copyWith(durationPaceMode: mode);
      _estimateDuration(
        distanceMeters: state.distanceMeters,
        pacePer100mSeconds: state.pacePer100mSeconds,
      );
      return;
    }

    final newPace = _estimatePaceFromDuration();
    state = state.copyWith(
      durationPaceMode: mode,
      pacePer100mSeconds: newPace ?? state.pacePer100mSeconds,
    );
  }

  /// Calculate estimated duration from distance and pace per 100m
  /// For swimming: estimatedDuration = (distance / 100) * pacePer100mSeconds
  void _estimateDuration({int? distanceMeters, int? pacePer100mSeconds}) {
    final currentDistance = distanceMeters ?? state.distanceMeters;
    final currentPace = pacePer100mSeconds ?? state.pacePer100mSeconds;

    if (currentDistance > 0 && currentPace > 0) {
      // Calculate number of 100m segments
      final segments = currentDistance / 100;
      // Total seconds = segments * pace per 100m
      final totalSeconds = (segments * currentPace).round();

      state = state.copyWith(
        estimatedDuration: Duration(seconds: totalSeconds),
      );
    }
  }

  int? _estimatePaceFromDuration({int? distanceMeters, Duration? duration}) {
    final currentDistance = distanceMeters ?? state.distanceMeters;
    final currentDuration = duration ?? state.estimatedDuration;

    if (currentDuration == null || currentDistance <= 0) {
      return null;
    }

    final segments = currentDistance / 100;
    if (segments <= 0) {
      return null;
    }

    final totalSeconds = currentDuration.inSeconds;
    if (totalSeconds <= 0) {
      return null;
    }

    return (totalSeconds / segments).round();
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

      // Update deck temp/humidity from forecast if available
      if (forecast.forecastAvailable) {
        state = state.copyWith(
          weatherForecast: forecast,
          deckTemperature: forecast.temperatureC,
          deckHumidity: forecast.humidityPct.toDouble(),
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
    final currentState = state;

    // Delegate to the main controller
    await ref
        .read(macroTargetsControllerProvider.notifier)
        .generateSwimmingMacros(
          distanceMeters: currentState.distanceMeters,
          paceSecondsper100m: currentState.pacePer100mSeconds,
          poolOrOpenWater: currentState.poolOrOpenWater,
          waterTempC: currentState.waterTempC,
          intensityTarget: currentState.intensityTarget,
          sessionGoal: currentState.sessionGoal,
          timeBeforeMinutes: currentState.preSwimMinutes,
          intensity: currentState.intensity,
          scheduledDate: currentState.selectedDate,
          scheduledTime: currentState.selectedTime,
          activityTitle: currentState.activityTitleManuallySet
              ? currentState.activityTitle
              : null,
          activityId: activityId,
          eventId: eventId,
          forUserId:
              forUserId, // NEW: Pass through forUserId for coach-created activities
        );
  }
}
