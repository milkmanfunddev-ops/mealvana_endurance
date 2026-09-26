import '../../../weather/domain/forecast_window.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../shared/utils/unit_formatter.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../auth/data/user_repository.dart';
import '../../../integrations/presentation/providers/athlete_zones_provider.dart';
import '../../domain/conditions_source.dart';
import '../../domain/fueling_window_limits.dart';
import '../../domain/run_parameters.dart';
import '../../domain/intensity_distribution.dart';
import '../../domain/fueling_window_authority.dart';
import '../../../activities/domain/activity_title_formatter.dart';
import 'macro_targets_controller.dart';
import '../../../weather/domain/location.dart' as weather_domain;
import '../../../weather/domain/weather_forecast.dart';
import '../../../weather/application/weather_service.dart';
import '../../../../core/utils/debug_logger.dart';
import '../../../../shared/services/location_service.dart';
import '../../../../shared/widgets/kyle_design/inputs/duration_pace_toggle.dart';

part 'running_input_controller.g.dart';

/// Placeholders shown for temperature / humidity until a forecast lands.
/// Named so the schedule-change path and the per-activity reset (Q-CA2) cannot
/// drift apart.
///
/// CP-1 (RULED Xuan, 2026-09-21 — `docs/ssot/spec/fueling/during-workout-hydration.md`):
/// these are now ruled SPEC values, not app-local placeholders. Changing them
/// is a ruling, not a code edit. Every path that seeds them must also set
/// [ConditionsSource.assumed] — see CP-5.
const double _kDefaultTemperatureC = 20.0;
const double _kDefaultHumidityPct = 60.0;

/// Running-specific form state that persists during tab switches
class RunningFormState {
  final String activityTitle;
  final bool activityTitleManuallySet;
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

  // V3: Track if user manually changed the pre-run timing
  final bool preRunMinutesManuallySet;

  // Unit system preference (imperial = °F, metric = °C)
  final UnitSystem unitSystem;

  // CP-2/CP-5 (RULED Xuan, 2026-09-21): provenance is a property of WHERE THE
  // VALUE CAME FROM, so it is stored beside the value and set by every path
  // that writes one — never derived from whether a fetch failed.
  final ConditionsSource temperatureSource;
  final ConditionsSource humiditySource;

  // CF-7 (RULED 2026-09-03): a manual step on a forecast-filled value makes
  // it the athlete's — the AUTO badge drops until the next forecast refresh.
  // Now a VIEW of the provenance field rather than a second stored bit: an
  // athlete-supplied value and a `manual` source are the same fact, and two
  // copies of one fact are two chances to disagree.
  bool get temperatureManuallySet =>
      temperatureSource == ConditionsSource.manual;
  bool get humidityManuallySet => humiditySource == ConditionsSource.manual;

  /// The plan-level CP-2 flag this form would generate with.
  ConditionsSource get conditionsSource =>
      ConditionsSource.resolve(temperatureSource, humiditySource);

  // Weather integration fields
  final weather_domain.Location? location;
  final WeatherForecast? weatherForecast;
  final bool isLoadingLocation;
  final bool isLoadingWeather;
  final bool hasAttemptedWeatherFetch;
  final LocationFailureReason? locationFailureReason;

  RunningFormState({
    this.activityTitle = '12 mi Run',
    this.activityTitleManuallySet = false,
    this.distance = 12.0,
    this.paceMinutes = 9.0,
    this.preRunMinutes =
        150, // V3: default from recommendedHoursBefore (2.5h for moderate running)
    this.gutTraining = GutTraining.moderate,
    this.sweatRate = SweatRateCat.medium,
    this.temperatureC = _kDefaultTemperatureC,
    this.humidityPct = _kDefaultHumidityPct,
    required this.selectedDate,
    required this.selectedTime,
    this.distanceUnit = DistanceUnit.miles,
    this.paceUnit = PaceUnit.minPerMile,
    IntensityDistribution? intensity,
    // CF-6 reference rendering: the create flow opens PACE-held
    // (duration wears EST.) — the prototype's default `held: 'pace'`.
    this.durationPaceMode = DurationPaceMode.byPace,
    this.estimatedDuration,
    this.preRunMinutesManuallySet = false,
    this.zonePaceApplied = false,
    this.zoneSuggestedPace,
    this.unitSystem = UnitSystem.imperial,
    // CP-1/CP-5: the constructor defaults ARE the ruled placeholders, so a
    // freshly built form is `assumed` before any fetch has been attempted.
    this.temperatureSource = ConditionsSource.assumed,
    this.humiditySource = ConditionsSource.assumed,
    this.location,
    this.weatherForecast,
    this.isLoadingLocation = false,
    this.isLoadingWeather = false,
    this.hasAttemptedWeatherFetch = false,
    this.locationFailureReason,
  }) : intensity = intensity ?? IntensityDistribution.defaultDistribution();

  RunningFormState copyWith({
    String? activityTitle,
    bool? activityTitleManuallySet,
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
    bool? preRunMinutesManuallySet,
    bool? zonePaceApplied,
    double? zoneSuggestedPace,
    UnitSystem? unitSystem,
    ConditionsSource? temperatureSource,
    ConditionsSource? humiditySource,
    weather_domain.Location? location,
    WeatherForecast? weatherForecast,
    bool? isLoadingLocation,
    bool? isLoadingWeather,
    bool? hasAttemptedWeatherFetch,
    LocationFailureReason? locationFailureReason,
  }) {
    return RunningFormState(
      activityTitle: activityTitle ?? this.activityTitle,
      activityTitleManuallySet:
          activityTitleManuallySet ?? this.activityTitleManuallySet,
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
      preRunMinutesManuallySet:
          preRunMinutesManuallySet ?? this.preRunMinutesManuallySet,
      zonePaceApplied: zonePaceApplied ?? this.zonePaceApplied,
      zoneSuggestedPace: zoneSuggestedPace ?? this.zoneSuggestedPace,
      unitSystem: unitSystem ?? this.unitSystem,
      temperatureSource: temperatureSource ?? this.temperatureSource,
      humiditySource: humiditySource ?? this.humiditySource,
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
      seconds:
          (((defaultDistance * defaultPace) -
                      (defaultDistance * defaultPace).floor()) *
                  60)
              .round(),
    );

    // §3a (food-recommendation, RATIFIED 2026-09-03): the default window
    // comes from the ratified table — the sport-specific formula is retired.
    final defaultIntensity = IntensityDistribution.defaultDistribution();
    const defaultStart = TimeOfDay(hour: 7, minute: 0);
    final recommendedMinutes = defaultFuelingWindowMinutes(
      durationMinutes: initialDuration.inMinutes,
      intensity: defaultIntensity,
      startHour: defaultStart.hour,
      minutesUntilStart: _minutesUntil(now, now, defaultStart),
    );

    final initialState = RunningFormState(
      activityTitle: ActivityTitleFormatter.formatRunningTitle(defaultDistance),
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
      durationPaceMode: DurationPaceMode.byPace,
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
      final zone2Pace = await ref.read(
        zone2PaceMinPerMileProvider(userId).future,
      );
      if (zone2Pace != null && zone2Pace > 4.0 && zone2Pace < 20.0) {
        state = state.copyWith(
          paceMinutes: zone2Pace,
          zonePaceApplied: true,
          zoneSuggestedPace: zone2Pace,
          estimatedDuration: _estimateDuration(paceMinutes: zone2Pace),
        );
        DebugLogger.info(
          '🏃 RUNNING CONTROLLER: Applied zone-based pace: ${zone2Pace.toStringAsFixed(1)} min/mi',
        );
      }
    } catch (e) {
      // Non-blocking - keep default pace if zone fetch fails
      DebugLogger.error(
        '🏃 RUNNING CONTROLLER: Zone pace unavailable',
        error: e,
      );
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
          unitSystem: userProfile.unitSystem,
        );
        DebugLogger.info(
          '🏃 RUNNING CONTROLLER: Loaded user preferences - gut training: ${userProfile.gutTraining.name}, sweat rate: ${userProfile.sweatRate.name}, unitSystem: ${userProfile.unitSystem.name}',
        );
      }
    } catch (e) {
      DebugLogger.error(
        '🏃 RUNNING CONTROLLER: Failed to load user preferences',
        error: e,
      );
      // Keep defaults on error
    }
  }

  /// Fetch location if this controller needs it and doesn't already have it.
  /// Called when this sport tab becomes active or the screen initializes.
  Future<void> fetchLocationIfNeeded() async {
    // Only an upcoming activity inside the forecast window asks for
    // location (Finding 100-004); a past or far-off date never does.
    if (!ForecastWindow.covers(state.selectedDate)) return;
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
        : ActivityTitleFormatter.formatRunningTitle(distance);
    final hasDuration =
        state.estimatedDuration != null &&
        state.estimatedDuration!.inSeconds > 0;

    if (state.durationPaceMode == DurationPaceMode.byDuration && hasDuration) {
      final newPace = _estimatePace(
        distance: distance,
        duration: state.estimatedDuration,
      );
      state = state.copyWith(
        activityTitle: resolvedTitle,
        distance: distance,
        paceMinutes: newPace ?? state.paceMinutes,
      );
      _autoUpdateFuelingWindow();
      return;
    }

    state = state.copyWith(
      activityTitle: resolvedTitle,
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
  Duration _estimateDuration({double? distance, double? paceMinutes}) {
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
  double? _estimatePace({double? distance, Duration? duration}) {
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

  /// Reset the create-flow form state to its derived defaults for a NEW
  /// activity.
  ///
  /// The sport input controllers are `keepAlive` singletons, so without this a
  /// value the athlete set by hand on one activity — and the `*ManuallySet`
  /// flag that latched with it — rode into every later activity and
  /// permanently suppressed re-derivation (§3a defaults, incl. Race Pace ⇒ 3 h,
  /// could never fire again; the title stayed the old event's name; a manual
  /// 31 °C outlived the day it was typed on). Xuan, on-device 2026-09-03;
  /// ops/data/bug-reports/2026-09-03-fueling-window-sticks-across-activities.md
  ///
  /// Q-CA2 (RULED Xuan, 2026-09-21 — option (a), PER-ACTIVITY): ONE lifetime for
  /// ALL form state. Opening the create flow for a NEW activity resets the
  /// values *and* the flags; CF-1/CF-7's "a manual change persists" means
  /// *within the activity being edited*; editing an EXISTING activity
  /// re-hydrates from that activity (the screen's seeds run after this reset
  /// and still win).
  void resetFormStateForNewActivity() {
    final forecast = state.weatherForecast;
    final hasForecast = forecast != null && forecast.forecastAvailable;
    state = state.copyWith(
      // Window (shipped first in 7418566f) — re-derived below.
      preRunMinutesManuallySet: false,
      // Title: back to the distance-derived default.
      activityTitleManuallySet: false,
      activityTitle: ActivityTitleFormatter.formatRunningTitle(state.distance),
      // CF-7: the AUTO badge returns, and the value returns with it — to the
      // forecast when one is loaded, otherwise to the same placeholders
      // updateDateTime shows while a refreshed forecast loads.
      //
      // CP-6: the reset restores the AUTO SOURCE, not a flat constant — so the
      // provenance follows the value it restored. This is the second path that
      // seeds the CP-1 placeholders with no fetch failure anywhere (CP-5); a
      // fetch-outcome-driven flag would miss exactly this one.
      temperatureC: hasForecast
          ? forecast.temperatureC.clamp(-5.0, 40.0)
          : _kDefaultTemperatureC,
      humidityPct: hasForecast
          ? forecast.humidityPct.toDouble().clamp(20.0, 95.0)
          : _kDefaultHumidityPct,
      temperatureSource: hasForecast
          ? ConditionsSource.measured
          : ConditionsSource.assumed,
      humiditySource: hasForecast
          ? ConditionsSource.measured
          : ConditionsSource.assumed,
    );
    _autoUpdateFuelingWindow();
  }

  void updatePreRunMinutes(int minutes) {
    // D-016: clamp into the ratified 0–240 domain — pre-cap activities can
    // carry persisted lead times up to 480 (see FuelingWindowLimits).
    final cap = fuelingWindowMaxMinutes();
    final capped = minutes < cap ? minutes : cap;
    state = state.copyWith(
      preRunMinutes: clampFuelingWindowMinutes(capped),
      preRunMinutesManuallySet: true,
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

  /// Auto-update fueling window when duration, intensity or schedule
  /// changes, unless user has manually overridden it. Default and clamp per
  /// food-recommendation §3/§3a (the ratified table replaces the retired
  /// recommendedHoursBefore formula; CF-1/CF-2).
  void _autoUpdateFuelingWindow() {
    if (!state.preRunMinutesManuallySet) {
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
        preRunMinutes: clampFuelingWindowMinutes(recommended),
      );
    }
  }

  /// Whole minutes between [now] and the scheduled start; never negative.
  static int _minutesUntil(DateTime now, DateTime date, TimeOfDay time) {
    final scheduled = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
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
    final floored = untilStart > kFuelingWindowFloorMin
        ? untilStart
        : kFuelingWindowFloorMin;
    return floored < FuelingWindowLimits.maxMinutes
        ? floored
        : FuelingWindowLimits.maxMinutes;
  }

  /// Q-CF1 class caption / CF-2 clamp explanation for the stepper (RULED
  /// Xuan, 2026-09-03) — null when the athlete's manual value needs no label.
  String? fuelingWindowCaption() {
    final sessionClass = classifySession(
      durationMinutes: state.estimatedDuration?.inMinutes ?? 90,
      intensity: state.intensity,
    );
    return fuelingWindowCaptionText(
      sessionClass: sessionClass,
      earlyStartApplied: earlyStartOverlayApplies(
        sessionClass: sessionClass,
        startHour: state.selectedTime.hour,
      ),
      currentMinutes: state.preRunMinutes,
      maxMinutes: fuelingWindowMaxMinutes(),
      manuallySet: state.preRunMinutesManuallySet,
    );
  }

  void updateGutTraining(GutTraining gutTraining) {
    state = state.copyWith(gutTraining: gutTraining);
  }

  void updateSweatRate(SweatRateCat sweatRate) {
    state = state.copyWith(sweatRate: sweatRate);
  }

  void updateTemperature(double temperatureC) {
    // CF-7: a manual step makes the value the athlete's — AUTO badge drops.
    // CP-2: an override typed AFTER a failed fetch is `manual`, never
    // `assumed` — the athlete's input outranks the fallback.
    state = state.copyWith(
      temperatureC: temperatureC,
      temperatureSource: ConditionsSource.manual,
    );
  }

  void updateHumidity(double humidityPct) {
    state = state.copyWith(
      humidityPct: humidityPct,
      humiditySource: ConditionsSource.manual,
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
      // CP-5: a third path onto the CP-1 placeholders — the stale forecast on
      // state still describes the OLD date/time, so these values are assumed
      // until the refetch lands and re-marks them measured.
      temperatureC: _kDefaultTemperatureC,
      humidityPct: _kDefaultHumidityPct,
      temperatureSource: ConditionsSource.assumed,
      humiditySource: ConditionsSource.assumed,
    );

    // §3a: the default window depends on start time (early-start overlay +
    // clamp), so a schedule change re-derives it unless manually set.
    _autoUpdateFuelingWindow();

    // A date moved into the forecast window asks for location now; until
    // then no prompt was spent (Finding 100-004).
    if (state.location == null && ForecastWindow.covers(date)) {
      fetchLocationIfNeeded();
    }
    // Auto-fetch weather when date/time changes if location is set
    // or if weather was previously fetched successfully (via GPS fallback).
    if (state.location != null || state.weatherForecast != null) {
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
          temperatureC: forecast.temperatureC.clamp(-5.0, 40.0),
          humidityPct: forecast.humidityPct.toDouble().clamp(20.0, 95.0),
          // CF-7: a refresh restores the AUTO badge on both values.
          // CP-2: these are the only values in this controller that a
          // measurement actually produced.
          temperatureSource: ConditionsSource.measured,
          humiditySource: ConditionsSource.measured,
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
    String?
    forUserId, // NEW: If provided, create activity for this user (coach creating for athlete)
  }) async {
    final currentState = state;

    DebugLogger.info('🏃 RUNNING CONTROLLER: generateMacros called');
    DebugLogger.info(
      '📍 RUNNING CONTROLLER: Current state - distance: ${currentState.distance}, pace: ${currentState.paceMinutes}',
    );

    // Convert pace to M:SS format
    final paceText = UnitFormatter.formatMinutesAsMinSec(
      currentState.paceMinutes,
    );

    DebugLogger.info(
      '⏩ RUNNING CONTROLLER: Delegating to distancePageGutEntryController.generateRunningMacros...',
    );

    // Delegate to the main controller
    await ref
        .read(macroTargetsControllerProvider.notifier)
        .generateRunningMacros(
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
          // CP-2: the flag travels WITH the plan, resolved from where each
          // value came from — not from whether the fetch succeeded.
          conditionsSource: currentState.conditionsSource,
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
      '✅ RUNNING CONTROLLER: generateRunningMacros completed successfully',
    );
  }
}
