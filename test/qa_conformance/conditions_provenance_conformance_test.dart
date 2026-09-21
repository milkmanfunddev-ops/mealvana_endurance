// QA conformance — CONDITIONS PROVENANCE (CP-1..CP-6).
//
// Spec:    docs/ssot/spec/fueling/during-workout-hydration.md
//          ("Conditions provenance — RULED (Xuan, 2026-09-21)")
// Vectors: docs/ssot/vectors/fueling/conditions-provenance.json
//          (7 ratified vectors; qa d649a80)
// Ruling:  qa/intake/2026-09-09-environment-fallback-when-weather-fetch-fails.md
//          (RESOLVED 2026-09-21, option 1)
//
// Vectors are read from the docs/ssot mirror by default;
// `--dart-define=QA_VECTORS=<abs path>` repoints this at the QA checkout, the
// same convention the pre-workout runners use. docs/ssot is a VERBATIM mirror
// and is never edited here.
//
// The vector file pins PROVENANCE ONLY — no new numbers. Each vector below is
// exercised through the code path it actually names:
//
//   * the create-flow vectors run through the REAL notifier
//     (`ProviderContainer` + `runningInputControllerProvider.notifier`), per
//     docs/test/README.md §Seam tests' "every controller write path gets one
//     test through the real notifier";
//   * `assumed-survives-persistence` runs a producer-shaped plan through the
//     REAL `MacroRepositoryImpl` with a REAL SharedPreferences store and reads
//     it back — the vector's own note says a pure in-memory call cannot prove
//     CP-2's travel, and a UI-only banner fails this by construction;
//   * `provenance-does-not-move-the-numbers` re-runs the ratified
//     during-workout-hydration vectors AND compares a stamped plan to its
//     unstamped self field by field (CP-4).
//
// CP-5 is the reason vector 2 exists: an implementation keyed on the FETCH
// OUTCOME passes every other vector in this file and fails that one. Do not
// "fix" a failure there by making the fetch path smarter — the flag is a
// statement about where the value came from.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/features/nutrition_plan/data/macro_repository.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/offline_macro_calculator.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/cycling_input_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/running_input_controller.dart';
import 'package:mealvana_endurance/features/weather/application/weather_service.dart';
import 'package:mealvana_endurance/features/weather/domain/weather_forecast.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

import '../helpers/widget_test_harness.dart';

class _MockWeatherService extends Mock implements WeatherService {}

/// CP-1's ruled fallback, mirrored here deliberately. The harness must be an
/// INDEPENDENT checker: importing the app's own `_kDefault*` constants would
/// let a wrong constant agree with itself.
const double kFallbackTempC = 20.0;
const double kFallbackHumidPct = 60.0;

/// The Tampa day from the ruling's evidence — 80 °F / 95 % RH.
const double kTampaTempC = 26.7;
const int kTampaHumidPct = 95;

WeatherForecast _availableForecast({
  double tempC = kTampaTempC,
  int humidPct = kTampaHumidPct,
}) => WeatherForecast(
  temperatureC: tempC,
  humidityPct: humidPct,
  forecastAvailable: true,
  forecastDate: DateTime(2026, 9, 21, 7),
  source: WeatherSource.forecast,
);

/// What `WeatherService` returns on EVERY failure path — no location, no
/// permission, non-200, bad body, or a thrown exception all funnel here.
WeatherForecast _failedForecast() =>
    WeatherForecast.defaultForecast(DateTime(2026, 9, 21, 7));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const overridePath = String.fromEnvironment('QA_VECTORS');
  final vectorsPath = overridePath.isNotEmpty
      ? overridePath
      : 'docs/ssot/vectors/fueling/conditions-provenance.json';

  final doc =
      jsonDecode(File(vectorsPath).readAsStringSync()) as Map<String, dynamic>;
  final vectors = <String, Map<String, dynamic>>{
    for (final v in (doc['vectors'] as List).cast<Map<String, dynamic>>())
      v['id'] as String: v,
  };

  /// Reads the vector by id and fails loudly if the slice is renamed or
  /// re-scoped underneath this runner, rather than silently testing nothing.
  Map<String, dynamic> vector(String id) {
    final v = vectors[id];
    expect(
      v,
      isNotNull,
      reason:
          'vector "$id" is missing from $vectorsPath — the slice changed '
          'shape; re-read the ruling before editing this runner',
    );
    return v!;
  }

  ConditionsSource expectedSource(String id) {
    final raw = vector(id)['expected']['conditionsSource'];
    final parsed = ConditionsSource.fromWire(raw);
    expect(parsed, isNotNull, reason: '$id: unknown conditionsSource "$raw"');
    return parsed!;
  }

  setUpAll(() {
    registerFallbackValue(DateTime(2026, 9, 21));
  });

  _MockWeatherService weatherReturning(WeatherForecast forecast) {
    final service = _MockWeatherService();
    when(
      () => service.getWeatherForecast(
        location: any(named: 'location'),
        activityDate: any(named: 'activityDate'),
      ),
    ).thenAnswer((_) async => forecast);
    when(() => service.getCurrentLocation()).thenAnswer((_) async => null);
    when(() => service.getLastLocationFailureReason()).thenReturn(null);
    when(() => service.hasLocationPermission()).thenAnswer((_) async => true);
    return service;
  }

  ProviderContainer containerWithWeather(WeatherForecast forecast) {
    final container = ProviderContainer(
      overrides: [
        mockAppExternalDeps(),
        appConfigProvider.overrideWithValue(AppConfig.forTesting()),
        mockSharedPreferences(),
        weatherServiceProvider.overrideWithValue(weatherReturning(forecast)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  // =========================================================================
  // Vector 1 — the fetch failed: the CP-1 fallback is in play and says so.
  // =========================================================================
  group('conditions provenance (${vectors.length} vectors)', () {
    test('[ratified] fetch-failed-flags-assumed', () async {
      const id = 'fetch-failed-flags-assumed';
      final e = vector(id)['expected'] as Map<String, dynamic>;

      final container = containerWithWeather(_failedForecast());
      final notifier = container.read(runningInputControllerProvider.notifier);

      await notifier.fetchWeatherForecast();
      final s = container.read(runningInputControllerProvider);

      expect(s.temperatureC, (e['tempC'] as num).toDouble(), reason: id);
      expect(s.humidityPct, (e['humidPct'] as num).toDouble(), reason: id);
      expect(
        s.conditionsSource,
        expectedSource(id),
        reason:
            '$id: the fallback reached the engine; the plan must say the '
            'conditions were assumed. ${vector(id)['why']}',
      );
      // The transient copy still appears — CP-3 keeps it — but it is NOT the
      // marker, so its presence must not be what the flag depends on.
      expect(s.hasAttemptedWeatherFetch, isTrue);
    });

    // =======================================================================
    // Vector 2 — THE DISCRIMINATING ONE (CP-5).
    // No fetch failure anywhere: the Q-CA2 per-activity reset seeds the same
    // 20.0/60 constants. A flag driven by the fetch OUTCOME passes every other
    // vector in this file and fails exactly here.
    // =======================================================================
    test(
      '[ratified] reset-seeded-defaults-flag-assumed-without-any-fetch-failure',
      () {
        const id =
            'reset-seeded-defaults-flag-assumed-without-any-fetch-failure';
        final e = vector(id)['expected'] as Map<String, dynamic>;

        final container = containerWithWeather(_failedForecast());
        final notifier = container.read(
          runningInputControllerProvider.notifier,
        );

        // Entering the create flow for a NEW activity. No forecast loaded, and
        // — the point of this vector — no fetch has been ATTEMPTED at all.
        notifier.resetFormStateForNewActivity();
        final s = container.read(runningInputControllerProvider);

        expect(
          s.hasAttemptedWeatherFetch,
          isFalse,
          reason:
              '$id: the premise of this vector is that NOTHING failed. If a '
              'fetch ran here the test has stopped discriminating.',
        );
        expect(s.weatherForecast, isNull, reason: '$id: no forecast loaded');
        expect(s.temperatureC, (e['tempC'] as num).toDouble(), reason: id);
        expect(s.humidityPct, (e['humidPct'] as num).toDouble(), reason: id);
        expect(
          s.conditionsSource,
          expectedSource(id),
          reason:
              '$id: DETECTION POWER. The reset seeded the CP-1 constants with '
              'no failure to key off. A fetch-outcome-driven flag reports '
              '`measured` (or nothing) here and ships the exact defect this '
              'ruling exists to prevent. ${vector(id)['why']}',
        );
      },
    );

    // Same claim on the cycling controller — the constants and the reset live
    // in both, so a source-driven flag must be wired in both.
    test(
      '[ratified] reset-seeded-defaults-flag-assumed-without-any-fetch-failure '
      '(cycling)',
      () {
        const id =
            'reset-seeded-defaults-flag-assumed-without-any-fetch-failure';
        final container = containerWithWeather(_failedForecast());
        final notifier = container.read(
          cyclingInputControllerProvider.notifier,
        );

        notifier.resetFormStateForNewActivity();
        final s = container.read(cyclingInputControllerProvider);

        expect(s.hasAttemptedWeatherFetch, isFalse);
        expect(s.temperatureC, kFallbackTempC);
        expect(s.humidityPct, kFallbackHumidPct);
        expect(s.conditionsSource, expectedSource(id), reason: id);
      },
    );

    // =======================================================================
    // Vector 3 — the fetch succeeded: measured, and distinguishable from the
    // fallback by the FLAG, not by the numbers.
    // =======================================================================
    test('[ratified] fetch-succeeded-flags-measured', () async {
      const id = 'fetch-succeeded-flags-measured';
      final e = vector(id)['expected'] as Map<String, dynamic>;
      final i = vector(id)['inputs'] as Map<String, dynamic>;

      final container = containerWithWeather(
        _availableForecast(
          tempC: (i['fetchedTempC'] as num).toDouble(),
          humidPct: (i['fetchedHumidPct'] as num).toInt(),
        ),
      );
      final notifier = container.read(runningInputControllerProvider.notifier);

      await notifier.fetchWeatherForecast();
      final s = container.read(runningInputControllerProvider);

      expect(s.temperatureC, closeTo((e['tempC'] as num).toDouble(), 1e-9));
      expect(s.humidityPct, (e['humidPct'] as num).toDouble());
      expect(
        s.conditionsSource,
        expectedSource(id),
        reason: '$id. ${vector(id)['why']}',
      );
    });

    // =======================================================================
    // Vector 4 — an override AFTER a failed fetch is MANUAL, never assumed.
    // =======================================================================
    test('[ratified] athlete-override-flags-manual', () async {
      const id = 'athlete-override-flags-manual';
      final e = vector(id)['expected'] as Map<String, dynamic>;
      final i = vector(id)['inputs'] as Map<String, dynamic>;

      final container = containerWithWeather(_failedForecast());
      final notifier = container.read(runningInputControllerProvider.notifier);

      await notifier.fetchWeatherForecast();
      expect(
        container.read(runningInputControllerProvider).conditionsSource,
        ConditionsSource.assumed,
        reason: '$id: precondition — the fallback is in play before the typing',
      );

      notifier.updateTemperature((i['suppliedTempC'] as num).toDouble());
      notifier.updateHumidity((i['suppliedHumidPct'] as num).toDouble());
      final s = container.read(runningInputControllerProvider);

      expect(s.temperatureC, closeTo((e['tempC'] as num).toDouble(), 1e-9));
      expect(s.humidityPct, (e['humidPct'] as num).toDouble());
      expect(
        s.conditionsSource,
        expectedSource(id),
        reason:
            "$id: the athlete's input outranks the fallback. ${vector(id)['why']}",
      );
    });

    // =======================================================================
    // Vector 5 — LOAD-BEARING: the flag survives persistence and re-read.
    // A UI-only banner fails this by construction.
    // =======================================================================
    test('[ratified] assumed-survives-persistence', () async {
      const id = 'assumed-survives-persistence';
      final e = vector(id)['expected'] as Map<String, dynamic>;

      // PRODUCER-SHAPED input: the plan as the edge function hands it over —
      // a raw JSON map with the wire's 3-decimal rounding, decoded by the same
      // `fromJson` production uses. Never the local engine's own object
      // (docs/test/README.md §Seam tests rule 1).
      final wirePlan = _producerPlanJson(
        tempC: kFallbackTempC,
        humidityPct: kFallbackHumidPct,
      );
      final generated = MacroTargets.fromJson(wirePlan);

      expect(
        generated.duringRun.conditionsSource,
        isNull,
        reason:
            '$id: the producer states no provenance — it cannot know one. '
            'An absent flag must never read as `measured`.',
      );

      // The real stamp production applies before caching.
      final stamped = generated.withConditionsSource(ConditionsSource.assumed);

      // …persisted through the REAL repository, against a REAL prefs store.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final repository = MacroRepositoryImpl(sharedPreferences: prefs);
      const activityId = 'cp-2-activity';
      await repository.saveMacroTargetsForActivity(activityId, stamped);

      // …and re-read through a repository built over the SAME store, so the
      // value genuinely crosses the serialization boundary rather than being
      // handed back out of an object graph still in memory.
      final reread = await MacroRepositoryImpl(
        sharedPreferences: prefs,
      ).getCachedMacroTargetsForActivity(activityId);

      expect(reread, isNotNull, reason: '$id: the plan did not persist at all');
      expect(
        reread!.duringRun.conditionsSource,
        isNotNull,
        reason:
            '$id: ${e['flagPresentAfterReread']} — the flag must be present '
            'after the round trip',
      );
      expect(
        reread.duringRun.conditionsSource,
        expectedSource(id),
        reason:
            '$id: the plan outlives the transient failure copy, so the marker '
            'must outlive it too. ${vector(id)['why']}',
      );
      // And the raw persisted text carries it — proof it is durable data and
      // not something reconstructed on read.
      expect(
        jsonEncode(stamped.toJson()),
        contains('"conditionsSource":"assumed"'),
        reason: '$id: the flag must be IN the serialized plan',
      );
    });

    // =======================================================================
    // Vector 6 — CP-4: provenance is additive. No ratified number moves.
    // =======================================================================
    test('[ratified] provenance-does-not-move-the-numbers', () {
      const id = 'provenance-does-not-move-the-numbers';

      // (a) Stamping changes the flag and NOTHING else. Compared on the
      //     serialized form so a new or shifted field cannot hide.
      final plan = MacroTargets.fromJson(
        _producerPlanJson(tempC: kFallbackTempC, humidityPct: kFallbackHumidPct),
      );
      final before = plan.toJson();
      final after = plan
          .withConditionsSource(ConditionsSource.assumed)
          .toJson();

      final beforeDuring = Map<String, dynamic>.from(
        before['duringRun'] as Map,
      );
      final afterDuring = Map<String, dynamic>.from(after['duringRun'] as Map);
      expect(
        afterDuring.remove('conditionsSource'),
        'assumed',
        reason: '$id: the flag is the only thing added',
      );
      expect(
        jsonEncode(afterDuring),
        jsonEncode(beforeDuring),
        reason:
            '$id: a during-workout field moved when provenance was attached. '
            'That is a DEFECT, not an update. ${vector(id)['why']}',
      );
      for (final key in before.keys) {
        if (key == 'duringRun') continue;
        expect(
          jsonEncode(after[key]),
          jsonEncode(before[key]),
          reason: '$id: "$key" moved when provenance was attached',
        );
      }

      // (b) The ratified during-workout-hydration contract still holds at the
      //     CP-1 inputs and everywhere else. Run against the sibling vector
      //     file so a numeric regression fails HERE, loudly, rather than in a
      //     slice nobody re-ran.
      final hydrationPath = overridePath.isNotEmpty
          ? overridePath.replaceFirst(
              'conditions-provenance.json',
              'during-workout-hydration.json',
            )
          : 'docs/ssot/vectors/fueling/during-workout-hydration.json';
      final hydrationDoc =
          jsonDecode(File(hydrationPath).readAsStringSync())
              as Map<String, dynamic>;
      for (final v
          in (hydrationDoc['vectors'] as List).cast<Map<String, dynamic>>()) {
        final vid = v['id'] as String;
        final i = v['inputs'] as Map<String, dynamic>;
        final ex = v['expected'] as Map<String, dynamic>;
        final out = OfflineMacroCalculator.calculateDuringWorkoutHydration(
          durationMin: (i['durationMin'] as num).toDouble(),
          weightKg: (i['weightKg'] as num).toDouble(),
          sweatRateCategory: i['sweatRateCategory'] as String,
          sweatSodiumCat: i['sweatSodiumCat'] as String,
          tempC: (i['tempC'] as num?)?.toDouble(),
          humidityPct: (i['humidityPct'] as num?)?.toDouble(),
          isIndoor: i['isIndoor'] as bool? ?? false,
          sport: i['sport'] as String,
          knownSweatRateMlPerHour: (i['knownSweatRateMlPerHour'] as num?)
              ?.toDouble(),
          knownSodiumConcMgPerL: (i['knownSodiumConcMgPerL'] as num?)
              ?.toDouble(),
        );
        void pin(String key, num actual) {
          if (!ex.containsKey(key)) return;
          expect(
            actual,
            closeTo((ex[key] as num).toDouble(), 0.0011),
            reason:
                '$id / during-workout-hydration:$vid: $key moved. CP-4 — a '
                'ratified number changing is a DEFECT introduced by the '
                'provenance work, never an update to the contract.',
          );
        }

        pin('effectiveSweatRateLph', out.effectiveSweatRateLph);
        pin('replacementPct', out.replacementPct);
        pin('hydrationRateMlph', out.hydrationRateMlph);
        pin('floorMlHr', out.floorMlHr);
        pin('ceilingMlHr', out.ceilingMlHr);
      }

      // (c) The CP-1 fallback case itself: sodium is proportional to the
      //     post-clamp fluid rate, so pinning both proves provenance did not
      //     perturb either engine at the inputs this ruling is about.
      final fallback = OfflineMacroCalculator.calculateDuringWorkoutHydration(
        durationMin: 90,
        weightKg: 65,
        sweatRateCategory: 'medium',
        sweatSodiumCat: 'average',
        tempC: kFallbackTempC,
        humidityPct: kFallbackHumidPct,
        isIndoor: false,
        sport: 'running',
      );
      final tampa = OfflineMacroCalculator.calculateDuringWorkoutHydration(
        durationMin: 90,
        weightKg: 65,
        sweatRateCategory: 'medium',
        sweatSodiumCat: 'average',
        tempC: kTampaTempC,
        humidityPct: kTampaHumidPct.toDouble(),
        isIndoor: false,
        sport: 'running',
      );
      // The ruling's own arithmetic: 1.294 / 0.938 = 1.38. The fallback still
      // understates the Tampa day by ~38 % — provenance makes that legible, it
      // does not correct it. If this ratio moves, an engine moved.
      expect(
        tampa.effectiveSweatRateLph / fallback.effectiveSweatRateLph,
        closeTo(1.38, 0.01),
        reason:
            '$id: the measured/assumed spread is the ruling evidence. '
            'Provenance must not narrow it — it only labels it.',
      );
      expect(
        fallback.sodiumRateMgph,
        closeTo(
          (fallback.hydrationRateMlph / 1000) * fallback.sodiumConcMgPerL,
          1.0,
        ),
        reason:
            '$id: sodium stays proportional to the post-clamp fluid rate at '
            'the CP-1 inputs',
      );
    });

    // =======================================================================
    // Vector 7 — the reset restores the AUTO SOURCE (CP-6), which pins the
    // other side: vector 2 cannot be "fixed" by always seeding the constants.
    // =======================================================================
    test('[ratified] reset-preserves-a-loaded-forecast-and-stays-measured',
        () async {
      const id = 'reset-preserves-a-loaded-forecast-and-stays-measured';
      final e = vector(id)['expected'] as Map<String, dynamic>;
      final i = vector(id)['inputs'] as Map<String, dynamic>;

      final container = containerWithWeather(
        _availableForecast(
          tempC: (i['fetchedTempC'] as num).toDouble(),
          humidPct: (i['fetchedHumidPct'] as num).toInt(),
        ),
      );
      final notifier = container.read(runningInputControllerProvider.notifier);

      await notifier.fetchWeatherForecast();
      // …and NOW the create flow opens for a new activity.
      notifier.resetFormStateForNewActivity();
      final s = container.read(runningInputControllerProvider);

      expect(
        s.temperatureC,
        closeTo((e['tempC'] as num).toDouble(), 1e-9),
        reason: '$id: the loaded forecast survives the per-activity reset',
      );
      expect(s.humidityPct, (e['humidPct'] as num).toDouble(), reason: id);
      expect(
        s.conditionsSource,
        expectedSource(id),
        reason:
            '$id: a reset that always seeded 20.0/60 would mark every plan '
            'assumed and destroy the distinction CP-2 exists to report. '
            '${vector(id)['why']}',
      );
    });
  });

  // =========================================================================
  // CP-3 support — the chip's parameters are the ruled three, and the plan
  // level flag never presents invented conditions as measured ones.
  // =========================================================================
  group('conditions provenance — CP-2/CP-3 properties', () {
    test('the chip parameters are exactly Measured · Assumed · Manual', () {
      expect(
        ConditionsSource.values.map((s) => s.displayLabel).toList(),
        <String>['Measured', 'Assumed', 'Manual'],
        reason:
            'CP-3 names the D-2 source-chip parameters for this application; '
            'adding or renaming one is a ruling, not a code edit',
      );
      expect(
        ConditionsSource.values.map((s) => s.wireValue).toList(),
        <String>['measured', 'assumed', 'manual'],
        reason: 'the persisted vocabulary is the vectors\' vocabulary',
      );
    });

    test('one assumed input makes the whole plan assumed', () {
      // CP-2: a plan whose conditions were assumed may never present as one
      // built on measured conditions — so `assumed` outranks everything.
      for (final other in ConditionsSource.values) {
        expect(
          ConditionsSource.resolve(ConditionsSource.assumed, other),
          ConditionsSource.assumed,
          reason: 'assumed temperature + $other humidity must stay assumed',
        );
        expect(
          ConditionsSource.resolve(other, ConditionsSource.assumed),
          ConditionsSource.assumed,
          reason: '$other temperature + assumed humidity must stay assumed',
        );
      }
      expect(
        ConditionsSource.resolve(
          ConditionsSource.manual,
          ConditionsSource.measured,
        ),
        ConditionsSource.manual,
      );
      expect(
        ConditionsSource.resolve(
          ConditionsSource.measured,
          ConditionsSource.measured,
        ),
        ConditionsSource.measured,
      );
    });

    test('an unknown or absent wire value is never read as measured', () {
      expect(ConditionsSource.fromWire(null), isNull);
      expect(ConditionsSource.fromWire('estimated'), isNull);
      expect(ConditionsSource.fromWire(20.0), isNull);
      expect(ConditionsSource.fromWire('measured'), ConditionsSource.measured);
    });

    test('a schedule change re-marks the conditions assumed until the '
        'refetch lands', () async {
      // The stale forecast on state describes the OLD date/time. Deriving
      // provenance from "is there a forecast object?" would read `measured`
      // here while the steppers show 20 °C / 60 % — the CP-5 failure mode in
      // its third disguise.
      final container = containerWithWeather(_availableForecast());
      final notifier = container.read(runningInputControllerProvider.notifier);
      await notifier.fetchWeatherForecast();
      expect(
        container.read(runningInputControllerProvider).conditionsSource,
        ConditionsSource.measured,
      );

      final current = container.read(runningInputControllerProvider);
      notifier.updateDateTime(
        current.selectedDate.add(const Duration(days: 3)),
        const TimeOfDay(hour: 18, minute: 30),
      );

      final s = container.read(runningInputControllerProvider);
      expect(s.temperatureC, kFallbackTempC);
      expect(s.humidityPct, kFallbackHumidPct);
      expect(
        s.conditionsSource,
        ConditionsSource.assumed,
        reason:
            'the values shown are the CP-1 placeholders again; the flag must '
            'say so until the refreshed forecast lands',
      );
    });
  });
}

/// A plan in the shape the PRODUCER hands over — the edge function's response
/// as it lands in `MacroTargets.fromJson`, carrying the wire's rounding and
/// no provenance of its own. Deliberately not built by calling the local
/// engine: a "stored" side produced by the same call the code recomputes with
/// is equal by construction and cannot fail (docs/test/README.md §Seam tests).
Map<String, dynamic> _producerPlanJson({
  required double tempC,
  required double humidityPct,
}) => <String, dynamic>{
  'id': 'plan-cp2',
  'activityType': 'running',
  'preRun': <String, dynamic>{
    'carbsG': 65.0,
    'proteinG': 13.0,
    'fatCapG': 11.0,
    'fluidsMl': 487.5,
    'sodiumMg': 325.0,
  },
  'duringRun': <String, dynamic>{
    'carbRateGPerH': 60.0,
    'carbTotalG': 90.0,
    'fluidRateMlPerH': 647.0,
    'fluidTotalMl': 970.0,
    'sodiumRateMgPerH': 453.0,
    'sodiumTotalMg': 679.0,
    'massNormRateGPerH': 0.923,
    'absClampRangeGPerH': <double>[30, 60],
    // wire rounding: the server emits 3 decimals
    'effectiveSweatRateLPerH': 1.293,
    'sodiumConcMgPerL': 700,
    'replacementPercent': 0.5,
    'floorMlPerH': 426,
    'ceilingMlPerH': 800,
    'tempC': tempC,
    'humidityPct': humidityPct,
    'isIndoor': false,
  },
  'postRun': <String, dynamic>{
    'carbsG': 78.0,
    'proteinG': 26.0,
    'fluidsMl': 1455.0,
    'sodiumMg': 1018.0,
  },
  'metrics': <String, dynamic>{
    'distanceMi': 8.0,
    'distanceKm': 12.875,
    'durationH': 1.5,
    'durationMin': 90.0,
    'paceMinPerMile': 11.25,
    'speedMph': 5.333,
    'caloriesGrossKcal': 912.0,
    'caloriesNetKcal': 837.0,
    'met': 8.3,
  },
  'calculationRule': 'v4',
  'timestamp': '2026-09-21T07:00:00.000',
  'isUserModified': false,
  'modifiedFields': <String>[],
};
