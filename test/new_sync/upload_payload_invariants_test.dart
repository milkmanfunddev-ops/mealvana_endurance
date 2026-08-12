// Upload-payload invariants for the repositories that sync onboarding data:
// users, onboarding_surveys, and integrations.
//
// WHY THIS FILE EXISTS. `uploadDirtyRecords()` is the one place where local
// truth becomes remote truth, and until now nothing executed it in a test —
// `user_repository_sync_test.dart` stubs it with `throw UnimplementedError()`.
// That blind spot shipped two real bugs in the 2026-08 onboarding cycle:
//
//  1. A hand-duplicated row→domain conversion inside UserRepository silently
//     dropped `sweat_rate` and `nutrition_target_overrides` from every
//     background upload. A payload assertion elsewhere kept passing because
//     it went through UserDao's (correct) conversion — coverage of the idea,
//     not of the line.
//  2. Timestamps are serialized with `toIso8601String()` on LOCAL DateTimes,
//     producing naive strings that Postgres `timestamptz` reads as UTC.
//     `users.created_at` landed hours off, skewing signup-date cohorts.
//
// The tests here drive the REAL path — Drift write → dirty query → row→domain
// conversion → toJson → PostgREST upsert — and fake only the network: a
// capturing SupabaseClient records exactly what would have gone over the
// wire. If a field is dropped anywhere along that path, or a timestamp is
// emitted as local wall-clock, this file fails.

import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/enums.dart';
import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_target_overrides.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';
import 'package:mealvana_endurance/features/onboarding/data/onboarding_survey_repository.dart';
import 'package:mealvana_endurance/features/onboarding/domain/allergy.dart';
import 'package:mealvana_endurance/features/onboarding/domain/dietary_preference.dart';
import 'package:mealvana_endurance/features/onboarding/domain/onboarding_draft.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';

// ---------------------------------------------------------------------------
// Network fakes — the ONLY faked layer.
//
// PostgREST builders implement Future<T>, so `await ...upsert(...)` resolves
// through `then()`. These fakes override just enough of the chain for the
// repositories' calls (`upsert`, `select().eq().maybeSingle()`) and record
// every payload handed to `upsert` — the object under test.
// ---------------------------------------------------------------------------

class _FakeResolved<T> extends Fake implements PostgrestTransformBuilder<T> {
  _FakeResolved(this._value);
  final T _value;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) async => onValue(_value);
}

class _FakeFilterResolved<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  _FakeFilterResolved(this._value);
  final T _value;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) async => onValue(_value);
}

class _FakeSelectChain extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  _FakeSelectChain(this._maybeSingleValue);
  final PostgrestMap? _maybeSingleValue;

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object value) => this;

  @override
  PostgrestTransformBuilder<PostgrestMap?> maybeSingle() =>
      _FakeResolved<PostgrestMap?>(_maybeSingleValue);
}

/// Records every `upsert` payload; answers `select().eq().maybeSingle()` with
/// [maybeSingleValue] (the integrations repo's remote-user FK guard).
class _CapturingQueryBuilder extends Fake implements SupabaseQueryBuilder {
  _CapturingQueryBuilder({this.maybeSingleValue});
  final PostgrestMap? maybeSingleValue;

  final List<Object> upsertPayloads = [];
  String? lastOnConflict;

  @override
  PostgrestFilterBuilder<dynamic> upsert(
    Object values, {
    String? onConflict,
    bool ignoreDuplicates = false,
    bool defaultToNull = true,
  }) {
    upsertPayloads.add(values);
    lastOnConflict = onConflict;
    return _FakeFilterResolved<dynamic>(null);
  }

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) =>
      _FakeSelectChain(maybeSingleValue);
}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockSentryReporter extends Mock implements SentryReporter {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _userId = 'user-upload-001';
const _authUserId = '00000000-0000-0000-0000-0000000000aa';

// Seeded as explicit LOCAL wall-clock instants (what production code has in
// hand after a Drift read). Whole seconds: Drift's dateTime column stores
// second precision.
final _createdAt = DateTime(2026, 8, 10, 22, 24, 4);
final _updatedAt = DateTime(2026, 8, 11, 7, 5, 6);
final _sweatTestDate = DateTime(2026, 7, 15, 8, 30);

/// Every synced column populated with a distinctive value, so a dropped
/// field can never hide behind a default.
UserProfile _fullProfile() => UserProfile(
  id: _userId,
  deviceId: 'device-upload-001',
  authUserId: _authUserId,
  authProvider: 'anonymous',
  isAnonymous: true,
  gender: Gender.female,
  birthday: DateTime(1994, 7, 1),
  heightFeet: 5,
  heightInches: 8,
  weightPounds: 143.3,
  runsWithWaterBottle: true,
  gutTraining: GutTraining.high,
  sweatRate: SweatRateCat.heavy,
  onboardingCompleted: true,
  appVersion: '9.9.9',
  createdAt: _createdAt,
  updatedAt: _updatedAt,
  unitSystem: UnitSystem.metric,
  ftpWatts: 222,
  cssPacePer100mSeconds: 95,
  dietaryPreference: DietaryPreference.vegetarian,
  allergies: const [Allergy.dairy],
  senderName: 'Coach X',
  firstName: 'Xuan',
  lastName: 'Huang',
  email: 'xuan@example.com',
  nutritionTargetOverrides: const NutritionTargetOverrides(
    duringRun: DuringActivityOverrides(carbRateGPerH: 90),
  ),
  bodyFatPct: 18.5,
  lifestyle: Lifestyle.active,
  typicalWeeklyHours: 9.5,
  carbCycleOptIn: true,
  trainingPhase: TrainingPhase.build,
  sweatSodium: SweatSodiumCat.high,
  knownSweatRateMlPerHour: 1200,
  knownSodiumConcentrationMgPerLiter: 950,
  sweatTestDate: _sweatTestDate,
  sweatTestSource: 'commercial_test',
  weightPoundsUpdatedAt: DateTime(2026, 8, 9, 6, 0, 0),
  bodyFatPctUpdatedAt: DateTime(2026, 8, 9, 6, 0, 1),
);

/// Asserts [raw] is an explicit UTC instant equal to [localSeeded].
///
/// The two failure modes this pins:
///  - a naive local string ('2026-08-10T22:24:04.000', no Z): Postgres
///    timestamptz reads it as UTC and the instant lands hours off;
///  - a correct-looking string for the wrong instant.
void _expectUtcInstant(Object? raw, DateTime localSeeded, String column) {
  expect(raw, isA<String>(), reason: '$column missing from payload');
  final s = raw! as String;
  expect(
    s.endsWith('Z'),
    isTrue,
    reason:
        '$column must be an explicit UTC instant ("...Z"). Got "$s" — a '
        'naive local timestamp, which Postgres timestamptz silently '
        'reinterprets as UTC (the users.created_at cohort-skew bug).',
  );
  expect(
    DateTime.parse(s).isAtSameMomentAs(localSeeded.toUtc()),
    isTrue,
    reason: '$column: expected ${localSeeded.toUtc()}, got $s',
  );
}

void _stubSentry(_MockSentryReporter sentry) {
  when(
    () => sentry.addBreadcrumb(
      message: any(named: 'message'),
      category: any(named: 'category'),
      data: any(named: 'data'),
    ),
  ).thenReturn(null);
  when(
    () => sentry.reportNetworkError(
      any(),
      url: any(named: 'url'),
      method: any(named: 'method'),
      statusCode: any(named: 'statusCode'),
      timeout: any(named: 'timeout'),
      stackTrace: any(named: 'stackTrace'),
    ),
  ).thenAnswer((_) async {});
  when(
    () => sentry.reportDatabaseError(
      any(),
      operation: any(named: 'operation'),
      table: any(named: 'table'),
      stackTrace: any(named: 'stackTrace'),
    ),
  ).thenAnswer((_) async {});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late _MockSupabaseClient supabase;
  late _MockGoTrueClient goTrue;
  late _MockSentryReporter sentry;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    supabase = _MockSupabaseClient();
    goTrue = _MockGoTrueClient();
    sentry = _MockSentryReporter();
    when(() => supabase.auth).thenReturn(goTrue);
    when(() => goTrue.currentUser).thenReturn(null);
    _stubSentry(sentry);
  });

  tearDown(() async {
    await database.close();
  });

  group('users upload payload', () {
    late _CapturingQueryBuilder usersTable;
    late UserRepository repository;

    setUp(() {
      usersTable = _CapturingQueryBuilder();
      when(() => supabase.from('users')).thenAnswer((_) => usersTable);
      repository = UserRepository(
        database: database,
        supabase: supabase,
        sentry: sentry,
      );
    });

    Future<Map<String, dynamic>> uploadAndCapture() async {
      await repository.saveUserProfile(_fullProfile(), needsUpload: true);
      final result = await repository.uploadDirtyRecords(_userId);
      expect(result.success, isTrue, reason: result.error ?? '');
      expect(usersTable.upsertPayloads, hasLength(1));
      expect(usersTable.lastOnConflict, 'id');
      return (usersTable.upsertPayloads.single as Map).cast<String, dynamic>();
    }

    test('sends every synced column with the athlete\'s values', () async {
      final payload = await uploadAndCapture();

      // The 2026-08 regression: these two were silently dropped by a
      // duplicated conversion, erasing them server-side on every upload.
      expect(payload['sweat_rate'], 'heavy');
      final overrides =
          (payload['nutrition_target_overrides'] as Map?)
              ?.cast<String, dynamic>();
      expect(
        overrides,
        isNotNull,
        reason: 'nutrition_target_overrides dropped from the upload payload',
      );
      expect(
        ((overrides!['duringRun'] as Map?) ?? const {})['carbRateGPerH'],
        90,
        reason: 'the athlete\'s edited long-run carb target must survive',
      );

      // Full census of the remaining synced columns.
      expect(payload['id'], _userId);
      expect(payload['device_id'], 'device-upload-001');
      expect(payload['auth_user_id'], _authUserId);
      expect(payload['auth_provider'], 'anonymous');
      expect(payload['is_anonymous'], true);
      expect(payload['gender'], 'female');
      expect(payload['birthday'], '1994-07-01');
      expect(payload['height_feet'], 5);
      expect(payload['height_inches'], 8);
      expect(payload['weight_pounds'], 143.3);
      expect(payload['runs_with_water_bottle'], true);
      expect(payload['gut_training_level'], 'high');
      expect(payload['onboarding_completed'], true);
      expect(payload['unit_system'], 'metric');
      // KNOWN GAP, pinned deliberately: the local user_profiles table has no
      // FTP/CSS columns, so the row→domain→toJson upload path always emits
      // null here — even though Settings lets athletes set FTP and toJson
      // always includes the key. A background upload after app restart will
      // therefore overwrite a remote cycling_ftp_watts with null. If these
      // assertions start seeing values, the gap was fixed — update this test
      // to expect the fixture's 222/95 and delete this comment.
      expect(payload['cycling_ftp_watts'], isNull);
      expect(payload['swimming_css_seconds_per_100m'], isNull);
      expect(payload['dietary_preference'], 'vegetarian');
      expect(payload['allergies'], ['dairy']);
      expect(payload['sender_name'], 'Coach X');
      expect(payload['first_name'], 'Xuan');
      expect(payload['last_name'], 'Huang');
      expect(payload['email'], 'xuan@example.com');
      expect(payload['body_fat_pct'], 18.5);
      expect(payload['lifestyle'], Lifestyle.active.dbValue);
      expect(payload['typical_weekly_hours'], 9.5);
      expect(payload['carb_cycle_opt_in'], true);
      expect(payload['training_phase'], TrainingPhase.build.dbValue);
      expect(payload['sweat_sodium'], 'high');
      expect(payload['known_sweat_rate_ml_per_hour'], 1200);
      expect(payload['known_sodium_concentration_mg_per_liter'], 950);
      expect(payload['sweat_test_source'], 'commercial_test');
    });

    test('timestamps are UTC instants, not local wall-clock', () async {
      final payload = await uploadAndCapture();

      _expectUtcInstant(payload['created_at'], _createdAt, 'created_at');
      _expectUtcInstant(payload['updated_at'], _updatedAt, 'updated_at');
      _expectUtcInstant(
        payload['sweat_test_date'],
        _sweatTestDate,
        'sweat_test_date',
      );
    });

    test('a successful upload clears the dirty flag', () async {
      await uploadAndCapture();
      final again = await repository.uploadDirtyRecords(_userId);
      expect(again.success, isTrue);
      expect(
        usersTable.upsertPayloads,
        hasLength(1),
        reason: 'a clean row must not re-upload',
      );
    });
  });

  group('users domain round-trip', () {
    test('toJson → fromJson preserves every synced field', () {
      final original = _fullProfile();
      final restored = UserProfile.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.deviceId, original.deviceId);
      expect(restored.authUserId, original.authUserId);
      expect(restored.authProvider, original.authProvider);
      expect(restored.isAnonymous, original.isAnonymous);
      expect(restored.gender, original.gender);
      expect(restored.birthday, original.birthday);
      expect(restored.heightFeet, original.heightFeet);
      expect(restored.heightInches, original.heightInches);
      expect(restored.weightPounds, original.weightPounds);
      expect(restored.gutTraining, original.gutTraining);
      expect(restored.sweatRate, original.sweatRate);
      expect(restored.onboardingCompleted, original.onboardingCompleted);
      expect(restored.unitSystem, original.unitSystem);
      expect(restored.ftpWatts, original.ftpWatts);
      expect(
        restored.cssPacePer100mSeconds,
        original.cssPacePer100mSeconds,
      );
      expect(restored.dietaryPreference, original.dietaryPreference);
      expect(restored.allergies, original.allergies);
      expect(restored.senderName, original.senderName);
      expect(restored.firstName, original.firstName);
      expect(restored.lastName, original.lastName);
      expect(restored.email, original.email);
      expect(
        restored.nutritionTargetOverrides?.duringRun?.carbRateGPerH,
        90,
      );
      expect(restored.bodyFatPct, original.bodyFatPct);
      expect(restored.lifestyle, original.lifestyle);
      expect(restored.typicalWeeklyHours, original.typicalWeeklyHours);
      expect(restored.carbCycleOptIn, original.carbCycleOptIn);
      expect(restored.trainingPhase, original.trainingPhase);
      expect(restored.sweatSodium, original.sweatSodium);
      expect(
        restored.knownSweatRateMlPerHour,
        original.knownSweatRateMlPerHour,
      );
      expect(
        restored.knownSodiumConcentrationMgPerLiter,
        original.knownSodiumConcentrationMgPerLiter,
      );
      expect(restored.sweatTestSource, original.sweatTestSource);

      // Instants survive (flag may lawfully change to UTC — compare moments).
      expect(
        restored.createdAt.isAtSameMomentAs(original.createdAt),
        isTrue,
      );
      expect(
        restored.updatedAt.isAtSameMomentAs(original.updatedAt),
        isTrue,
      );
      expect(
        restored.sweatTestDate!.isAtSameMomentAs(original.sweatTestDate!),
        isTrue,
      );
    });
  });

  group('onboarding_surveys upload payload', () {
    test('sends the answers, the payload flags, and UTC timestamps',
        () async {
      // Survey rows FK onto user_profiles — seed the parent first.
      await database.userDao.saveUserProfile(
        _fullProfile(),
        needsUpload: false,
      );

      final surveysTable = _CapturingQueryBuilder();
      when(
        () => supabase.from('onboarding_surveys'),
      ).thenAnswer((_) => surveysTable);
      final repository = OnboardingSurveyRepository(
        supabase: supabase,
        database: database,
        logger: const NoopAppLogger(),
        sentry: sentry,
      );

      await repository.saveSurveyFromDraft(
        userId: _userId,
        draft: const OnboardingDraft(
          sports: {OnboardingSport.running, OnboardingSport.cycling},
          goals: {OnboardingGoal.performance, OnboardingGoal.eatHealthier},
          pitfalls: {
            OnboardingPitfall.energyCrash,
            OnboardingPitfall.gutIssues,
          },
          sweatTestInterest: true,
          tridotNotifyRequested: true,
        ),
      );
      final result = await repository.uploadDirtyRecords(_userId);
      expect(result.success, isTrue, reason: result.error ?? '');

      // saveSurveyFromDraft fires its own unawaited immediate push, so the
      // explicit uploadDirtyRecords above may be the first or second upsert —
      // assert on the most recent batch rather than pinning a count.
      expect(surveysTable.upsertPayloads, isNotEmpty);
      expect(surveysTable.lastOnConflict, 'user_id');
      final rows = (surveysTable.upsertPayloads.last as List)
          .cast<Map<String, dynamic>>();
      final payload = rows.single;

      expect(payload['user_id'], _userId);
      expect(payload['sports'], ['running', 'cycling']);
      expect(payload['goals'], ['performance', 'eat_healthier']);
      expect(payload['pitfalls'], ['energy_crash', 'gut_issues']);
      final flags =
          (payload['survey_payload'] as Map).cast<String, dynamic>();
      expect(flags['sweat_test_interest'], true);
      expect(flags['tridot_notify'], true);

      // This repo already serializes UTC correctly — pin it so it stays so.
      for (final column in ['completed_at', 'created_at', 'updated_at']) {
        final s = payload[column] as String;
        expect(
          s.endsWith('Z'),
          isTrue,
          reason: '$column regressed to a naive local timestamp',
        );
      }
    });
  });

  group('integrations upload payload', () {
    final tokenExpiresAt = DateTime(2026, 8, 12, 15, 0, 0);
    final lastSyncAt = DateTime(2026, 8, 12, 9, 30, 0);

    test('sends athlete profile fields and UTC timestamps', () async {
      await database.userDao.saveUserProfile(
        _fullProfile(),
        needsUpload: false,
      );
      // Seed a dirty integration row directly — upsertIntegration would also
      // fire its own immediate best-effort push and muddy the capture.
      await database
          .into(database.integrationsTable)
          .insert(
            IntegrationsTableCompanion.insert(
              id: const Value('integ-upload-001'),
              userId: _userId,
              provider: 'final_surge',
              accessToken: 'token-abc',
              refreshToken: const Value('refresh-xyz'),
              tokenExpiresAt: Value(tokenExpiresAt),
              providerAthleteId: 'fs-athlete-9',
              providerAthleteName: const Value('Xuan Huang'),
              providerAthleteEmail: const Value('xuan@example.com'),
              providerAthleteWeightKg: const Value(65.0),
              lastSyncAt: Value(lastSyncAt),
              lastSyncStatus: const Value('success'),
              needsUpload: const Value(true),
              createdAt: _createdAt,
              updatedAt: _updatedAt,
            ),
          );

      final integrationsTable = _CapturingQueryBuilder();
      // The repo's FK guard asks Supabase whether the users row exists
      // before uploading — answer yes.
      final usersTable = _CapturingQueryBuilder(
        maybeSingleValue: {'id': _userId},
      );
      when(() => supabase.from('integrations')).thenAnswer((_) => integrationsTable);
      when(() => supabase.from('users')).thenAnswer((_) => usersTable);

      final repository = IntegrationsRepository(
        database: database,
        supabase: supabase,
        logger: const NoopAppLogger(),
        sentry: sentry,
      );
      final result = await repository.uploadDirtyRecords(_userId);
      expect(result.success, isTrue, reason: result.error ?? '');

      expect(integrationsTable.upsertPayloads, hasLength(1));
      expect(integrationsTable.lastOnConflict, 'id');
      final rows = (integrationsTable.upsertPayloads.single as List)
          .cast<Map<String, dynamic>>();
      final payload = rows.single;

      expect(payload['id'], 'integ-upload-001');
      expect(payload['user_id'], _userId);
      expect(payload['provider'], 'final_surge');
      expect(payload['access_token'], 'token-abc');
      expect(payload['refresh_token'], 'refresh-xyz');
      expect(payload['provider_athlete_id'], 'fs-athlete-9');
      expect(payload['provider_athlete_name'], 'Xuan Huang');
      expect(payload['provider_athlete_email'], 'xuan@example.com');
      expect(payload['provider_athlete_weight_kg'], 65.0);
      expect(payload['is_active'], true);
      expect(payload['last_sync_status'], 'success');

      // A token expiry sent as naive local time is reinterpreted as UTC by
      // Postgres — hours of skew on when the server thinks the token dies.
      _expectUtcInstant(
        payload['token_expires_at'],
        tokenExpiresAt,
        'token_expires_at',
      );
      _expectUtcInstant(payload['last_sync_at'], lastSyncAt, 'last_sync_at');
      _expectUtcInstant(payload['created_at'], _createdAt, 'created_at');
      _expectUtcInstant(payload['updated_at'], _updatedAt, 'updated_at');
    });
  });
}
