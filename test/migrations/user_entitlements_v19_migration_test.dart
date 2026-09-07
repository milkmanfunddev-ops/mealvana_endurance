/// Tests for the v19 `user_entitlements` cache table (Pro subscription,
/// docs/implement_mealplanning/04-entitlement.md).
///
/// Covers, in the repo's migration-test shape (see
/// rerun_migration_idempotency_test.dart):
///  - onCreate produces the table with the (user_id, entitlement) key
///  - a v18 install gets the table from the `from < 19` step
///  - replaying that step when the table already exists is a no-op (web
///    `user_version` re-run safety)
///  - the row round-trips through the Drift companion
library;

import 'package:drift/drift.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:test/test.dart';

Future<Set<String>> _tables(AppDatabase db) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  group('user_entitlements (v19)', () {
    test('onCreate produces the table with a composite primary key', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      expect(await _tables(db), contains('user_entitlements'));

      final columns = await db
          .customSelect('PRAGMA table_info(user_entitlements)')
          .get();
      final byName = {
        for (final c in columns) c.read<String>('name'): c,
      };
      expect(
        byName.keys,
        containsAll([
          'user_id',
          'entitlement',
          'active',
          'product_id',
          'store',
          'period_type',
          'expires_at',
          'source',
          'updated_at',
          'fetched_at',
        ]),
      );
      // pk column carries the 1-based position within the primary key.
      expect(byName['user_id']!.read<int>('pk'), 1);
      expect(byName['entitlement']!.read<int>('pk'), 2);
      expect(byName['active']!.read<int>('notnull'), 1);
    });

    test('a v18 install gets the table from the from < 19 step', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      // Simulate the pre-v19 state, then run the ladder from 18.
      await db.customStatement('DROP TABLE user_entitlements');
      expect(await _tables(db), isNot(contains('user_entitlements')));

      await db.migration.onUpgrade(db.createMigrator(), 18, db.schemaVersion);

      expect(await _tables(db), contains('user_entitlements'));
    });

    test('re-running the v19 step when the table exists is a no-op', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      await expectLater(
        db.migration.onUpgrade(db.createMigrator(), 18, db.schemaVersion),
        completes,
      );
      // And again — the web user_version replay shape.
      await expectLater(
        db.migration.onUpgrade(db.createMigrator(), 18, db.schemaVersion),
        completes,
      );
      expect(await _tables(db), contains('user_entitlements'));
    });

    test('a row round-trips through the companion', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      final now = DateTime.utc(2026, 9, 1, 12);
      await db
          .into(db.userEntitlementsTable)
          .insert(
            UserEntitlementsTableCompanion.insert(
              userId: 'user-1',
              entitlement: 'pro',
              active: const Value(true),
              productId: const Value('mealvana_pro_monthly'),
              store: const Value('APP_STORE'),
              periodType: const Value('TRIAL'),
              expiresAt: Value(now.add(const Duration(days: 30))),
              updatedAt: now,
              fetchedAt: now,
            ),
          );

      final row = await (db.select(
        db.userEntitlementsTable,
      )..where((t) => t.userId.equals('user-1'))).getSingle();

      expect(row.entitlement, 'pro');
      expect(row.active, isTrue);
      expect(row.productId, 'mealvana_pro_monthly');
      expect(row.periodType, 'TRIAL');
      expect(row.source, 'revenuecat');
      // Drift reads DateTimes back in local time; compare instants.
      expect(row.expiresAt!.toUtc(), now.add(const Duration(days: 30)));

      // Same (user, entitlement) again replaces rather than duplicates.
      await db
          .into(db.userEntitlementsTable)
          .insert(
            UserEntitlementsTableCompanion.insert(
              userId: 'user-1',
              entitlement: 'pro',
              active: const Value(false),
              updatedAt: now,
              fetchedAt: now,
            ),
            mode: InsertMode.insertOrReplace,
          );
      final rows = await db.select(db.userEntitlementsTable).get();
      expect(rows, hasLength(1));
      expect(rows.single.active, isFalse);
    });
  });
}
