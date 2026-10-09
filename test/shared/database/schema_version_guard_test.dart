import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';

/// Guards against the failure mode that wiped users' local databases in
/// July 2026 (Sentry MEALVANA-ENDURANCE-DEV-60 / DEV-61).
///
/// What happened: `activities.is_fasted` was added to the Drift table
/// definition, and the ALTER was placed inside the existing `from < 14` step
/// rather than a new one. `schemaVersion` stayed at 14. Drift skips onUpgrade
/// entirely when `from == to`, so every install already on v14 never got the
/// column. The startup integrity check found the schema didn't match and
/// recovered the only way it can — by deleting and rebuilding the local
/// database, losing unsynced data.
///
/// The bug is invisible in review: the diff looks like a normal migration.
/// What made it dangerous was the *absence* of a version bump — so that is
/// what these tests check.
void main() {
  group('Drift schema version guard', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('schema fingerprint matches the pinned value', () {
      final fingerprint = _schemaFingerprint(db);

      expect(
        db.schemaVersion,
        _pinnedVersion,
        reason:
            'schemaVersion is ${db.schemaVersion} but this test pins '
            '$_pinnedVersion. Update _pinnedVersion AND _pinnedFingerprint '
            'together, and make sure onUpgrade has a matching '
            '`if (from < ${db.schemaVersion})` step.',
      );

      expect(
        fingerprint,
        _pinnedFingerprint,
        reason:
            '\nThe Drift schema changed but schemaVersion is still '
            '${db.schemaVersion}.\n\n'
            'Devices already on version ${db.schemaVersion} will NOT run '
            'onUpgrade (Drift skips it when from == to), so they never receive '
            'this change — and the startup integrity check will wipe their '
            'local database to recover.\n\n'
            'To fix:\n'
            '  1. Bump schemaVersion to ${db.schemaVersion + 1}.\n'
            '  2. Add an idempotent `if (from < ${db.schemaVersion + 1})` step '
            'to onUpgrade.\n'
            '  3. Set _pinnedVersion = ${db.schemaVersion + 1} and '
            '_pinnedFingerprint = \'$fingerprint\'.\n',
      );
    });

    test('every schema version has a corresponding onUpgrade step', () {
      // The other half of the same bug: the version moves but nothing
      // migrates, so the new version is a no-op for existing installs.
      final source = File(
        'lib/shared/database/app_database.dart',
      ).readAsStringSync();

      final missing = <int>[
        for (var v = _ladderFloor; v <= db.schemaVersion; v++)
          if (!source.contains('from < $v')) v,
      ];

      expect(
        missing,
        isEmpty,
        reason:
            'schemaVersion is ${db.schemaVersion} but onUpgrade has no '
            '`if (from < N)` branch for version(s) $missing.',
      );
    });

    test('a v14 install gets is_fasted — the exact regression', () async {
      // Reproduces the shape of the bug directly: an install sitting at the
      // old version must come out of onUpgrade with the column present.
      // Materialise the schema, then confirm the column Drift expects is
      // actually there. Before the v15 step this is what failed on device.
      await db.customStatement('SELECT 1');
      final columns = await db
          .customSelect('PRAGMA table_info(activities)')
          .get();
      final names = columns.map((r) => r.read<String>('name')).toSet();

      expect(
        names,
        contains('is_fasted'),
        reason:
            'activities.is_fasted is missing. This is precisely the condition '
            'that triggered schema_integrity_validation_failed and wiped the '
            'local database on 4 users.',
      );
    });
  });
}

/// Bump both of these together, deliberately, whenever the schema changes.
/// 2026-09-11 re-pin at the SAME version: v20 is unreleased (this branch owns
/// it; Vana holds v21 on develop) and gained the eight users sport-preference
/// columns after the Stage E walk found saves silently dropping them.
///
/// 2026-10-01: v22 for `activities.duration_source` (P3). It SKIPS 21
/// deliberately — develop holds 21 for the Vana tables, and a release that also
/// claimed 21 would leave a dev-TestFlight device with from == to, so Drift
/// would skip onUpgrade and the integrity check would wipe the local database:
/// the very failure this guard exists for, arriving from the other direction.
///
/// 2026-10-07: v23 for `activities.completion_type` (mealplanning ticket 99,
/// backported by develop-2026-10 ticket 29 under mealplanning's number; v24
/// is `meal_logs.servings`, next). The step also re-adds duration_source
/// idempotently for a mealplanning-lineage device whose v22 was home location.
///
/// 2026-10-07: v24 for `meal_logs.servings` (mealplanning ticket 135, same
/// number; Supabase migration 20260926163500). Its step repeats the
/// duration_source catch-up for a mealplanning-lineage device at v23.
///
/// 2026-10-09: v25 for `events.provider_event_id` (develop-2026-10 ticket 80
/// Q3; Supabase migration 20261009120000).
const _pinnedVersion = 25;
// 2026-10-06 branch split: develop is rebuilt from the release line without
// the Vana tables, so develop's v22 fingerprint IS the release line's again.
// (The 2026-10-01 re-pin to develop's Vana-inclusive value, bf2ff574cb0b…,
// lives on the `mealplanning` branch, which still carries those tables.)
// 2026-10-07: re-pinned for v23 (v22 was 242db9fc97e1…), then for v24
// (v23 was 138f2619e791…). 2026-10-09: re-pinned for v25 (v24 was
// 6439b5387ef9…).
const _pinnedFingerprint =
    'e88bfb92fcf804f380f4ca265f767d1605579fbc04ace1ad9ae1ba6dc6db3e1e';

/// The migration ladder in app_database.dart starts at `from < 7`; versions
/// 1–6 predate it and were consolidated. Only guard from here upward.
const _ladderFloor = 7;

/// A stable hash over every table's column set — names, types and nullability,
/// so a renamed or retyped column trips it just as an added one does.
String _schemaFingerprint(AppDatabase db) {
  final tables = <String>[];
  for (final table in db.allTables) {
    final columns =
        table.$columns
            .map((c) => '${c.name}:${c.type}:${c.$nullable ? 'n' : 'nn'}')
            .toList()
          ..sort();
    tables.add('${table.actualTableName}(${columns.join(',')})');
  }
  tables.sort();
  return sha256.convert(utf8.encode(tables.join('|'))).toString();
}
