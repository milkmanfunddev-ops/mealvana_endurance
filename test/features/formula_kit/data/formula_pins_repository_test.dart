import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/data/formula_pins_repository.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_pin.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// PR 2 substep 3 verification — lock in the sync invariants that fall out
// of substep 2's repository implementation before substep 4 (the algorithm
// hook) starts reading pins. Targets the offline-first guarantees:
//
//   - dirty-preserve: an active sync from Supabase must not clobber a row
//     the user just touched locally (pin/unpin still pending upload).
//   - tombstone-propagation: unpinning sets is_deleted=true (not DELETE) so
//     the unpin event reaches other devices via the standard upsert sync.
//   - soft-delete on unpin: physical row stays put, only the flag flips.
//   - pin idempotency: tapping a pin that's already active is a no-op.
//
// Full syncFromRemote / uploadDirtyRecords tests are intentionally omitted
// for the same reason the rest of `test/new_sync/` does — mocking the
// SupabaseQueryBuilder chain isn't worth the brittleness. The upsert
// merge path is exposed via @visibleForTesting on
// `upsertRemotePinsPreservingDirty` so we can drive it directly.

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockAppLogger extends Mock implements AppLogger {}

class MockSentryReporter extends Mock implements SentryReporter {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late MockSupabaseClient mockSupabase;
  late MockAppLogger mockLogger;
  late MockSentryReporter mockSentry;
  late FormulaPinsRepository repository;

  const testUserId = 'user-abc';
  const otherUserId = 'user-xyz';
  const testTemplateId = 'tpl-oatmeal';
  const otherTemplateId = 'tpl-banana';

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    mockSupabase = MockSupabaseClient();
    mockLogger = MockAppLogger();
    mockSentry = MockSentryReporter();

    // Permissive logger stubs — production logs are fire-and-forget noise here.
    when(
      () => mockLogger.info(
        any(),
        context: any(named: 'context'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);
    when(
      () => mockLogger.debug(
        any(),
        context: any(named: 'context'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);
    when(
      () => mockLogger.warning(
        any(),
        context: any(named: 'context'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);
    when(
      () => mockLogger.error(
        any(),
        context: any(named: 'context'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);

    // pin()/unpin() fire-and-forget the upload to Supabase. The mock client
    // throws on any unstubbed method call, which surfaces as a rejected
    // future inside the unawaited lambda — caught by the repo's try/catch.
    // Stub the sentry callback so that catch path doesn't blow up.
    when(
      () => mockSentry.reportNetworkError(
        any(),
        url: any(named: 'url'),
        method: any(named: 'method'),
        stackTrace: any(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async {});

    repository = FormulaPinsRepository(
      supabase: mockSupabase,
      database: database,
      logger: mockLogger,
      sentry: mockSentry,
    );
  });

  tearDown(() async {
    // Drain the fire-and-forget upload futures so they don't leak into the
    // next test's setUp (where `database` has been replaced).
    await Future<void>.delayed(Duration.zero);
    await database.close();
  });

  // Build a raw Supabase-shaped JSON payload (no Drift-only sync columns).
  Map<String, dynamic> remotePayload({
    required String id,
    required String userId,
    required String templateId,
    TemplateKind kind = TemplateKind.preSystem,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool isDeleted = false,
  }) {
    final now = DateTime.now();
    return {
      'id': id,
      'user_id': userId,
      'template_id': templateId,
      'template_kind': kind.wireValue,
      'created_at': (createdAt ?? now).toUtc().toIso8601String(),
      'updated_at': (updatedAt ?? now).toUtc().toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  group('upsertRemotePinsPreservingDirty — dirty-preserve', () {
    test('skips remote overwrite when local row has needs_upload=true '
        '(local-dirty wins until upload)', () async {
      // Seed a locally-dirty row (e.g. user just tapped pin while offline).
      final localCreated = DateTime.utc(2026, 5, 21, 10);
      await database
          .into(database.formulaPinsTable)
          .insert(
            FormulaPinsTableCompanion.insert(
              id: const Value('pin-1'),
              userId: testUserId,
              templateId: testTemplateId,
              templateKind: TemplateKind.preSystem.wireValue,
              createdAt: localCreated,
              updatedAt: localCreated,
              isDeleted: const Value(false),
              needsUpload: const Value(true),
              localUpdatedAt: Value(localCreated),
            ),
          );

      // Server pushes a STALE / CONFLICTING version of the same id —
      // e.g. an old tombstone from a previous unpin that never got cleared.
      final upsertedCount = await repository.upsertRemotePinsPreservingDirty([
        remotePayload(
          id: 'pin-1',
          userId: testUserId,
          templateId: testTemplateId,
          isDeleted: true,
          updatedAt: DateTime.utc(2026, 5, 20),
        ),
      ]);

      expect(
        upsertedCount,
        0,
        reason: 'dirty row should not count as upserted',
      );

      // Local row is untouched — still active, still dirty.
      final localRows = await (database.select(
        database.formulaPinsTable,
      )).get();
      expect(localRows, hasLength(1));
      expect(localRows.single.id, 'pin-1');
      expect(
        localRows.single.isDeleted,
        isFalse,
        reason: 'local-dirty row must survive the conflicting remote tombstone',
      );
      expect(
        localRows.single.needsUpload,
        isTrue,
        reason: 'still dirty — upload pass hasn\'t run yet',
      );
    });

    test('applies remote rows that are NOT locally dirty', () async {
      // Seed a CLEAN local row (already in sync with server).
      await database
          .into(database.formulaPinsTable)
          .insert(
            FormulaPinsTableCompanion.insert(
              id: const Value('pin-clean'),
              userId: testUserId,
              templateId: testTemplateId,
              templateKind: TemplateKind.preSystem.wireValue,
              createdAt: DateTime.utc(2026, 5, 20),
              updatedAt: DateTime.utc(2026, 5, 20),
              isDeleted: const Value(false),
              needsUpload: const Value(false),
            ),
          );

      // Plus a brand-new remote row the local DB has never seen.
      final newRemoteUpdated = DateTime.utc(2026, 5, 21, 12);
      final upsertedCount = await repository.upsertRemotePinsPreservingDirty([
        remotePayload(
          id: 'pin-clean',
          userId: testUserId,
          templateId: testTemplateId,
          updatedAt: newRemoteUpdated,
        ),
        remotePayload(
          id: 'pin-new',
          userId: testUserId,
          templateId: otherTemplateId,
        ),
      ]);

      expect(upsertedCount, 2);

      final localRows = await (database.select(
        database.formulaPinsTable,
      )).get();
      expect(localRows, hasLength(2));
      // Clean row was overwritten with the newer remote updated_at.
      // Drift round-trips DateTime as local — compare instants, not wall times.
      final clean = localRows.firstWhere((r) => r.id == 'pin-clean');
      expect(clean.updatedAt.toUtc(), newRemoteUpdated);
      // New remote row was inserted, with needs_upload=false (already in sync).
      final newRow = localRows.firstWhere((r) => r.id == 'pin-new');
      expect(newRow.needsUpload, isFalse);
    });
  });

  group('upsertRemotePinsPreservingDirty — tombstone propagation', () {
    test('remote tombstone applied to clean local row makes it invisible to '
        'read paths but keeps the row physically present', () async {
      // Device A pinned & synced this row. Device B (us) starts from clean.
      await database
          .into(database.formulaPinsTable)
          .insert(
            FormulaPinsTableCompanion.insert(
              id: const Value('pin-shared'),
              userId: testUserId,
              templateId: testTemplateId,
              templateKind: TemplateKind.preSystem.wireValue,
              createdAt: DateTime.utc(2026, 5, 20),
              updatedAt: DateTime.utc(2026, 5, 20),
              isDeleted: const Value(false),
              needsUpload: const Value(false),
            ),
          );

      // Device A unpinned it; the tombstone flows down to us via sync.
      await repository.upsertRemotePinsPreservingDirty([
        remotePayload(
          id: 'pin-shared',
          userId: testUserId,
          templateId: testTemplateId,
          isDeleted: true,
          updatedAt: DateTime.utc(2026, 5, 21),
        ),
      ]);

      // Physical row still there, but flagged deleted.
      final allRows = await (database.select(database.formulaPinsTable)).get();
      expect(allRows, hasLength(1));
      expect(allRows.single.isDeleted, isTrue);

      // Read paths must hide it.
      final active = await repository.getActivePinsForUser(testUserId);
      expect(active, isEmpty);

      final stillPinned = await repository.isPinned(
        userId: testUserId,
        templateId: testTemplateId,
        kind: TemplateKind.preSystem,
      );
      expect(stillPinned, isFalse);

      final found = await repository.findActivePin(
        userId: testUserId,
        templateId: testTemplateId,
        kind: TemplateKind.preSystem,
      );
      expect(found, isNull);
    });
  });

  group('unpin() — soft delete', () {
    test(
      'flips is_deleted=true and dirties the row instead of DELETE-ing',
      () async {
        final pinned = await repository.pin(
          userId: testUserId,
          templateId: testTemplateId,
          kind: TemplateKind.preSystem,
        );

        await repository.unpin(
          userId: testUserId,
          templateId: testTemplateId,
          kind: TemplateKind.preSystem,
        );

        // Same physical row, now tombstoned.
        final allRows = await (database.select(
          database.formulaPinsTable,
        )).get();
        expect(
          allRows,
          hasLength(1),
          reason: 'unpin must not physically delete — tombstone needs to sync',
        );
        expect(allRows.single.id, pinned.id);
        expect(allRows.single.isDeleted, isTrue);
        expect(
          allRows.single.needsUpload,
          isTrue,
          reason: 'tombstone needs to upload so other devices learn about it',
        );
      },
    );

    test('no-op when no active pin exists', () async {
      // Seed only a tombstone — unpin() should find no active row and exit.
      await database
          .into(database.formulaPinsTable)
          .insert(
            FormulaPinsTableCompanion.insert(
              id: const Value('pin-ghost'),
              userId: testUserId,
              templateId: testTemplateId,
              templateKind: TemplateKind.preSystem.wireValue,
              createdAt: DateTime.utc(2026, 5, 20),
              updatedAt: DateTime.utc(2026, 5, 20),
              isDeleted: const Value(true),
              needsUpload: const Value(false),
            ),
          );

      await repository.unpin(
        userId: testUserId,
        templateId: testTemplateId,
        kind: TemplateKind.preSystem,
      );

      final allRows = await (database.select(database.formulaPinsTable)).get();
      expect(allRows, hasLength(1));
      expect(
        allRows.single.needsUpload,
        isFalse,
        reason: 'no-op unpin must not re-dirty an already-tombstoned row',
      );
    });
  });

  group('pin() — idempotency', () {
    test('second pin() for same (user,template,kind) returns existing row '
        'and does not insert a duplicate', () async {
      final first = await repository.pin(
        userId: testUserId,
        templateId: testTemplateId,
        kind: TemplateKind.preSystem,
      );
      final second = await repository.pin(
        userId: testUserId,
        templateId: testTemplateId,
        kind: TemplateKind.preSystem,
      );

      expect(second.id, first.id);
      final allRows = await (database.select(database.formulaPinsTable)).get();
      expect(allRows, hasLength(1));
    });

    test(
      'different (user,template,kind) tuples produce separate rows',
      () async {
        await repository.pin(
          userId: testUserId,
          templateId: testTemplateId,
          kind: TemplateKind.preSystem,
        );
        await repository.pin(
          userId: testUserId,
          templateId: testTemplateId,
          kind: TemplateKind.duringSystem,
        );
        await repository.pin(
          userId: otherUserId,
          templateId: testTemplateId,
          kind: TemplateKind.preSystem,
        );

        final allRows = await (database.select(
          database.formulaPinsTable,
        )).get();
        expect(allRows, hasLength(3));

        final mineBeforeOnly = await repository.getActivePinsForUser(
          testUserId,
          kind: TemplateKind.preSystem,
        );
        expect(mineBeforeOnly, hasLength(1));
      },
    );
  });
}
