// Unit tests for the Sentry session-replay cohort sampler.
//
// Guards the 2026-07-16 battery fix. The invariant that matters most here is
// that the resolved rate is only ever exactly 1.0 or 0.0: any other value would
// start sentry-cocoa's recorder for the whole session (its start gate is
// `onErrorSampleRate == 0`) while discarding most of the replays — full battery
// cost, a fraction of the value. See sentry_replay_sampling.dart.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/shared/services/sentry/sentry_replay_sampling.dart';

/// Deterministic stand-in for [Random], so cohort assignment is testable.
class _FixedRandom implements Random {
  _FixedRandom(this.value);

  final double value;

  @override
  double nextDouble() => value;

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  int nextInt(int max) => throw UnimplementedError();
}

Future<SharedPreferences> _prefs([Map<String, Object> initial = const {}]) {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resolveReplayOnErrorSampleRate', () {
    test('never arms a user who has not consented', () async {
      final prefs = await _prefs();

      final rate = await resolveReplayOnErrorSampleRate(
        prefs,
        analyticsConsented: false,
        armedFraction: 1.0, // would arm everyone if consent were ignored
        random: _FixedRandom(0.0),
      );

      expect(rate, kReplayOff);
    });

    test(
      'assigns no cohort when unconsented, so a later grant rolls fairly',
      () async {
        final prefs = await _prefs();

        await resolveReplayOnErrorSampleRate(
          prefs,
          analyticsConsented: false,
          random: _FixedRandom(0.0),
        );

        // Burning the roll here would permanently bias a user we must not record.
        expect(prefs.getBool('sentry_replay_cohort_armed_v1'), isNull);
      },
    );

    test('arms when the roll lands inside the cohort', () async {
      final prefs = await _prefs();

      final rate = await resolveReplayOnErrorSampleRate(
        prefs,
        analyticsConsented: true,
        armedFraction: 0.1,
        random: _FixedRandom(0.05),
      );

      expect(rate, kReplayArmed);
    });

    test('does not arm when the roll lands outside the cohort', () async {
      final prefs = await _prefs();

      final rate = await resolveReplayOnErrorSampleRate(
        prefs,
        analyticsConsented: true,
        armedFraction: 0.1,
        random: _FixedRandom(0.5),
      );

      expect(rate, kReplayOff);
    });

    test('boundary: a roll exactly at the fraction is NOT armed', () async {
      final prefs = await _prefs();

      final rate = await resolveReplayOnErrorSampleRate(
        prefs,
        analyticsConsented: true,
        armedFraction: 0.1,
        random: _FixedRandom(0.1),
      );

      expect(rate, kReplayOff);
    });

    test(
      'an armed install stays armed across launches, ignoring later rolls',
      () async {
        final prefs = await _prefs();

        final first = await resolveReplayOnErrorSampleRate(
          prefs,
          analyticsConsented: true,
          armedFraction: 0.1,
          random: _FixedRandom(0.05), // armed
        );
        // A per-session roll would flip this one to off; a cohort must not.
        final second = await resolveReplayOnErrorSampleRate(
          prefs,
          analyticsConsented: true,
          armedFraction: 0.1,
          random: _FixedRandom(0.99),
        );

        expect(first, kReplayArmed);
        expect(second, kReplayArmed);
      },
    );

    test('an unarmed install stays unarmed across launches', () async {
      final prefs = await _prefs();

      final first = await resolveReplayOnErrorSampleRate(
        prefs,
        analyticsConsented: true,
        armedFraction: 0.1,
        random: _FixedRandom(0.99), // unarmed
      );
      final second = await resolveReplayOnErrorSampleRate(
        prefs,
        analyticsConsented: true,
        armedFraction: 0.1,
        random: _FixedRandom(0.0),
      );

      expect(first, kReplayOff);
      expect(second, kReplayOff);
    });

    test('persists the cohort decision exactly once', () async {
      final prefs = await _prefs();

      await resolveReplayOnErrorSampleRate(
        prefs,
        analyticsConsented: true,
        armedFraction: 0.1,
        random: _FixedRandom(0.05),
      );

      expect(prefs.getBool('sentry_replay_cohort_armed_v1'), isTrue);
    });

    test('honours a cohort persisted by an earlier launch', () async {
      final prefs = await _prefs({'sentry_replay_cohort_armed_v1': true});

      final rate = await resolveReplayOnErrorSampleRate(
        prefs,
        analyticsConsented: true,
        armedFraction: 0.0, // would arm nobody on a fresh roll
        random: _FixedRandom(0.99),
      );

      expect(rate, kReplayArmed);
    });

    test(
      'only ever returns exactly 1.0 or 0.0 — never a fractional rate',
      () async {
        // The whole point of the fix: a fractional rate is the worst case.
        for (final roll in [0.0, 0.05, 0.1, 0.5, 0.99]) {
          final prefs = await _prefs();
          final rate = await resolveReplayOnErrorSampleRate(
            prefs,
            analyticsConsented: true,
            armedFraction: 0.1,
            random: _FixedRandom(roll),
          );
          expect(rate, anyOf(equals(1.0), equals(0.0)), reason: 'roll=$roll');
        }
      },
    );

    test(
      'default cohort fraction stays a documented, deliberate value',
      () async {
        // A silent bump here is a silent battery regression across the fleet.
        expect(kReplayArmedCohortFraction, 0.1);
      },
    );
  });
}
