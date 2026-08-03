/// CI/CD configuration contract — runs in the ordinary unit lane.
///
/// Deploy configuration only fails where it is expensive to fail: on a push to
/// `develop` or `release/*`, on a build machine, minutes into a signing step,
/// or — worse — silently, by shipping a build pointed at the wrong backend.
/// None of that is caught by any Dart test, and `codemagic.yaml` is not
/// validated by anything today.
///
/// These tests assert the invariants that make a merge to develop or release
/// safe, using only files in the repo. They cannot see Codemagic's stored
/// secrets (that is the one class of problem left to the dashboard), but they
/// do catch every structural way the config has actually drifted:
///
///   • a lane pointed at the wrong flavor or the wrong `.env` file
///   • a dev lane granted the prod variable group, or vice versa
///   • a deploy lane with no test gate on the same trigger
///   • the two Patrol lanes disagreeing about which flows run
///   • an AI-billing flow sneaking into a lane that runs on every push
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Flows deliberately excluded from every automated lane, with the reason.
const _mustNeverAutoRun = <String, String>{
  'jade_chat_flow_test':
      'calls the jade-chat edge function — bills real AI spend per run',
  'google_login_flow_test':
      'drives the native Google OAuth sheet, needs interactive consent',
  'onboarding_signup_flow_test': 'requires a clean install with no session',
};

void main() {
  final repoRoot = Directory.current;
  final codemagicFile = File('${repoRoot.path}/codemagic.yaml');
  final m1File = File(
    '${repoRoot.path}/.github/workflows/tests-selfhosted.yml',
  );

  late YamlMap codemagic;
  late String m1Source;

  setUpAll(() {
    expect(
      codemagicFile.existsSync(),
      isTrue,
      reason: 'codemagic.yaml missing — tests run from the repo root.',
    );
    expect(m1File.existsSync(), isTrue, reason: 'M1 workflow missing.');
    codemagic = loadYaml(codemagicFile.readAsStringSync()) as YamlMap;
    m1Source = m1File.readAsStringSync();
  });

  YamlMap workflow(String name) {
    final w = (codemagic['workflows'] as YamlMap)[name];
    expect(
      w,
      isNotNull,
      reason:
          'codemagic.yaml has no "$name" workflow. If it was renamed, update '
          'this contract — do not delete the assertion.',
    );
    return w as YamlMap;
  }

  List<String> groupsOf(String name) =>
      ((workflow(name)['environment'] as YamlMap)['groups'] as YamlList)
          .cast<String>()
          .toList();

  String scriptsOf(String name) => workflow(name)['scripts'].toString();

  List<String> eventsOf(String name) {
    final t = workflow(name)['triggering'] as YamlMap?;
    if (t == null) return const [];
    return ((t['events'] as YamlList?) ?? const []).cast<String>().toList();
  }

  List<String> branchesOf(String name) {
    final t = workflow(name)['triggering'] as YamlMap?;
    if (t == null) return const [];
    final pats = (t['branch_patterns'] as YamlList?) ?? const [];
    return [
      for (final p in pats)
        if ((p as YamlMap)['include'] == true) p['pattern'] as String,
    ];
  }

  group('dev lanes talk to DEV, prod lanes talk to PROD', () {
    test('the dev deploy + dev test lanes use the dev group and env', () {
      for (final name in [
        'dev-ios',
        'integration-tests-develop',
        'integration-tests',
      ]) {
        expect(
          groupsOf(name),
          contains('mealvana_dev'),
          reason: '$name must have the mealvana_dev variable group.',
        );
        expect(
          groupsOf(name),
          isNot(contains('mealvana_prod')),
          reason:
              '$name is a DEV lane but was granted the prod variable group — '
              'that points dev testing at the production backend.',
        );
      }
    });

    test('the prod deploy + prod test lanes use the prod group', () {
      for (final name in [
        'prod-ios',
        'prod-android',
        'integration-tests-prod',
      ]) {
        expect(
          groupsOf(name),
          contains('mealvana_prod'),
          reason: '$name must have the mealvana_prod variable group.',
        );
      }
    });

    test('each Patrol lane loads the env file matching its flavor', () {
      // Only what patrol is *given* counts. The shared write_dotenv_files
      // anchor creates all three .env files (the other flavor's as an empty
      // stub), so a substring search over the whole script blob would see
      // ".env.prod.local" in a dev lane and mean nothing by it.
      List<String> definesIn(String name) => RegExp(
        r'--dart-define-from-file=([^\s\\]+)',
      ).allMatches(scriptsOf(name)).map((m) => m.group(1)!).toList();

      for (final name in ['integration-tests', 'integration-tests-develop']) {
        final s = scriptsOf(name);
        final defines = definesIn(name);
        expect(
          s,
          contains('--flavor dev'),
          reason: '$name must build the dev flavor.',
        );
        expect(
          defines,
          contains('.env.dev.local'),
          reason: '$name must be given the dev env file. Got: $defines',
        );
        expect(
          defines,
          isNot(contains('.env.prod.local')),
          reason:
              '$name is a DEV lane but patrol is handed the PROD env file, so '
              'it would drive the production backend. Got: $defines',
        );
      }

      final prodDefines = definesIn('integration-tests-prod');
      expect(scriptsOf('integration-tests-prod'), contains('--flavor prod'));
      expect(prodDefines, contains('.env.prod.local'));
      expect(
        prodDefines,
        isNot(contains('.env.dev.local')),
        reason:
            'The prod-backend lane is handed the dev env file. Got: '
            '$prodDefines',
      );
    });
  });

  group('every deploy has a test gate on the same trigger', () {
    test('a push to develop runs the dev tests as well as the dev build', () {
      expect(
        eventsOf('dev-ios').contains('push') &&
            branchesOf('dev-ios').contains('develop'),
        isTrue,
        reason: 'dev-ios should deploy on push to develop.',
      );
      expect(
        eventsOf('integration-tests-develop').contains('push') &&
            branchesOf('integration-tests-develop').contains('develop'),
        isTrue,
        reason:
            'Nothing would exercise the flows on a push to develop — the dev '
            'TestFlight build would ship untested.',
      );
      expect(
        eventsOf('pr-validation').contains('push') &&
            branchesOf('pr-validation').contains('develop'),
        isTrue,
        reason: 'Unit tests / analyze / format must gate a push to develop.',
      );
    });

    test('a push to release/* runs the prod-backend tests', () {
      expect(
        eventsOf('integration-tests-prod').contains('push') &&
            branchesOf(
              'integration-tests-prod',
            ).any((b) => b.startsWith('release')),
        isTrue,
        reason:
            'A release push deploys to the App Store lane; the prod-backend '
            'Patrol suite has to run on that same trigger.',
      );
    });

    test('the dev-backend suite does NOT also run on a release push', () {
      // Decided 2026-07-31: release pushes run the prod suite only, so the
      // mac_mini_m2 minutes are not spent twice on the same flows.
      final dev = 'integration-tests-develop';
      expect(
        branchesOf(dev).any((b) => b.startsWith('release')),
        isFalse,
        reason:
            '$dev would double up with integration-tests-prod on a release '
            'push.',
      );
    });
  });

  group('flows that must never run automatically', () {
    test('are absent from every Codemagic dev lane', () {
      for (final lane in ['integration-tests', 'integration-tests-develop']) {
        final s = scriptsOf(lane);
        // A bare directory target sweeps in everything, including the ones
        // below — this is exactly how jade_chat billed AI on every push.
        expect(
          RegExp(r'--target integration_test\s').hasMatch(s),
          isFalse,
          reason:
              '$lane uses a bare `--target integration_test`, which globs the '
              'whole directory and re-admits the excluded flows. List targets '
              'explicitly.',
        );
        for (final entry in _mustNeverAutoRun.entries) {
          // Match the flag, not the bare name — these files are referenced by
          // name in the comments that explain *why* they are excluded, and a
          // substring search would trip over the explanation itself.
          expect(
            RegExp('--target [^\\s]*${entry.key}').hasMatch(s),
            isFalse,
            reason: '$lane must not run ${entry.key}: ${entry.value}.',
          );
        }
      }
    });

    test('are absent from the M1 workflow', () {
      for (final entry in _mustNeverAutoRun.entries) {
        expect(
          RegExp('--target [^\\s]*${entry.key}').hasMatch(m1Source),
          isFalse,
          reason: 'The M1 workflow must not run ${entry.key}: ${entry.value}.',
        );
      }
    });
  });

  group('the two CI systems agree about what they run', () {
    List<String> targetsIn(String source) => RegExp(
      r'--target (integration_test/[A-Za-z0-9_/]+\.dart)',
    ).allMatches(source).map((m) => m.group(1)!).toSet().toList()..sort();

    test('the M1 and Codemagic dev lanes run the same flow list', () {
      final m1 = targetsIn(m1Source);
      final cm = targetsIn(scriptsOf('integration-tests-develop'));

      expect(
        m1,
        isNotEmpty,
        reason: 'The M1 workflow declares no --target flows.',
      );
      expect(
        cm,
        m1,
        reason:
            'The M1 runner and the Codemagic dev lane disagree about which '
            'flows run, so a flow could pass one gate and never run on the '
            'other.\nM1 only: ${m1.toSet().difference(cm.toSet())}\n'
            'Codemagic only: ${cm.toSet().difference(m1.toSet())}',
      );
    });

    test('every declared target exists on disk', () {
      for (final t in targetsIn(m1Source)) {
        expect(
          File('${repoRoot.path}/$t').existsSync(),
          isTrue,
          reason:
              '$t is listed as a CI target but does not exist — patrol fails '
              'the whole bundle on a missing target.',
        );
      }
    });
  });

  group('the M1 suite cannot pass by skipping', () {
    // Match the STEP definition (`- name: …`), not a bare substring. These
    // names also appear in the comments that explain them, so a `contains`
    // check stays green when the step itself is deleted and only the
    // explanation survives — which is exactly how a guard rots away.
    bool hasStep(String name) => RegExp(
      '-\\s*name:\\s*${RegExp.escape(name)}\\s*\$',
      multiLine: true,
    ).hasMatch(m1Source);

    test('it verifies credentials before running Patrol', () {
      expect(
        hasStep('Verify integration credentials are present'),
        isTrue,
        reason:
            'Without this step, empty credentials make every flow self-skip, '
            'patrol exits 0, and the job reports success having tested '
            'nothing at all.',
      );
    });

    test('it fails the job when any test skipped', () {
      expect(
        hasStep('Assert the suite actually ran'),
        isTrue,
        reason:
            'The skip guard step was removed — a skip would read as a pass.',
      );
      expect(
        m1Source,
        contains(RegExp(r'if \[ "\$skipped" -gt 0 \]')),
        reason:
            'The skip guard no longer fails on a non-zero skip count, so a '
            'flow that quietly stops testing keeps the job green.',
      );
      expect(
        m1Source,
        contains('EXPECTED_PATROL_TESTS'),
        reason:
            'The expected-count guard was removed — a silently dropped target '
            'would still exit 0.',
      );
    });
  });
}
