/// Unit tests for the redesigned OnboardingController: draft mutators, the
/// incomplete-draft guard, the pure plan-edit → NutritionTargetOverrides
/// merge, and the account-first save seam (mp-459): the draft waits on the
/// phone until an account exists and is written to that account's uid.
///
/// The save seam runs the REAL pipeline (profile create → temp-id re-key →
/// defaults → survey → snapshot) over in-memory Drift with the one boundary
/// we do not own — GoTrue's current user — faked in the shape it arrives.
/// Only the network refuses, so every remote write falls back to its
/// "dirty, retry later" path — except in the 03-009 test, whose loss needs
/// a network that accepts writes (a fake PostgREST over `MockClient`).
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_target_overrides.dart';
import 'package:mealvana_endurance/features/onboarding/data/onboarding_survey_repository.dart';
import 'package:mealvana_endurance/features/onboarding/domain/onboarding_draft.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_controller.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mealvana_endurance/shared/services/sync/entity_sync/user_sync_handler.dart';

import '../../helpers/widget_test_harness.dart';

class _MockUser extends Mock implements User {}

/// The uid GoTrue hands back once the athlete has signed up.
const _accountUid = '00000000-0000-0000-0000-0000000000ac';

/// The sessionless id the connect step writes under before sign-up.
const _tempOnboardingId = 'temp-onboarding-0001';

/// A signed-in, non-anonymous GoTrue user, in the shape GoTrue returns it.
User _signedUp({String id = _accountUid, String? email = 'ava@example.com'}) {
  final u = _MockUser();
  when(() => u.id).thenReturn(id);
  when(() => u.email).thenReturn(email);
  when(() => u.isAnonymous).thenReturn(false);
  return u;
}

/// A PostgREST that accepts every write. `users` rows are kept (an upsert
/// merges onto the stored row, as `Prefer: resolution=merge-duplicates`
/// does) and every `users` payload is recorded in arrival order; other
/// tables answer an empty success.
class _FakePostgrest {
  final Map<String, Map<String, dynamic>> rows = {};
  final List<Map<String, dynamic>> users = [];

  Future<http.Response> handle(http.Request request) async {
    final isUsers = request.url.path.endsWith('/rest/v1/users');
    if (request.method == 'POST') {
      if (isUsers) {
        final body = jsonDecode(request.body);
        for (final row in (body is List ? body : [body])) {
          final map = Map<String, dynamic>.from(row as Map);
          users.add(map);
          final id = map['id'] as String;
          rows[id] = {...?rows[id], ...map};
        }
      }
      return http.Response('', 201, request: request);
    }
    if (request.method == 'GET') {
      if (isUsers) {
        final id = request.url.queryParameters['id']?.replaceFirst('eq.', '');
        final row = rows[id];
        return http.Response(
          jsonEncode(row == null ? [] : [row]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      return http.Response(
        '[]',
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }
    return http.Response('', 204, request: request);
  }
}

void main() {
  late ProviderContainer container;
  late OnboardingController controller;

  setUp(() {
    container = ProviderContainer();
    controller = container.read(onboardingControllerProvider.notifier);
  });

  tearDown(() => container.dispose());

  group('account-first save (mp-459)', () {
    late AppDatabase db;
    late MockGoTrueClient goTrue;
    late MockSharedPreferences prefs;
    late SupabaseClient supabase;
    late ProviderContainer seamContainer;
    late OnboardingController seamController;
    late ProviderContainer Function(SupabaseClient client) buildSeam;

    setUp(() {
      // The snapshot service reads SharedPreferences.getInstance() directly.
      SharedPreferences.setMockInitialValues({});

      db = AppDatabase.memory();
      addTearDown(db.close);

      goTrue = fakeGoTrueClient() as MockGoTrueClient;
      supabase = fakeSupabaseClient(auth: goTrue);

      prefs = MockSharedPreferences();
      when(() => prefs.getBool(any())).thenReturn(null);
      when(() => prefs.getString(any())).thenReturn(null);
      when(() => prefs.getInt(any())).thenReturn(null);
      when(() => prefs.getStringList(any())).thenReturn(null);
      when(() => prefs.remove(any())).thenAnswer((_) async => true);

      final analytics = MockAnalyticsTracker();
      when(
        () => analytics.track(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      when(
        () => analytics.identifyUser(
          any(),
          properties: any(named: 'properties'),
          gender: any(named: 'gender'),
          age: any(named: 'age'),
          weightPounds: any(named: 'weightPounds'),
          runsWithWaterBottle: any(named: 'runsWithWaterBottle'),
          gutTrainingLevel: any(named: 'gutTrainingLevel'),
        ),
      ).thenAnswer((_) async {});

      final sentry = mockSentryReporter();
      when(
        () => sentry.captureMessage(
          any(),
          tags: any(named: 'tags'),
          extra: any(named: 'extra'),
        ),
      ).thenAnswer((_) async {});

      /// The real save pipeline over [client]; the refusing client by
      /// default, a test's own when it needs the network to answer.
      buildSeam = (SupabaseClient client) => ProviderContainer(
        overrides: [
          appExternalDepsProvider.overrideWithValue(
            AppExternalDeps(
              analytics: analytics,
              supabaseClient: client,
              sentry: sentry,
              logger: MockAppLogger(),
              sharedPreferences: prefs,
            ),
          ),
          sentryReporterProvider.overrideWithValue(sentry),
          sharedPreferencesProvider.overrideWithValue(prefs),
          inMemoryDatabaseOverride(db),
          // These two providers build from Supabase.instance, which does not
          // exist in a test VM; same repositories, explicit construction.
          onboardingSurveyRepositoryProvider.overrideWithValue(
            OnboardingSurveyRepository(
              supabase: client,
              database: db,
              logger: MockAppLogger(),
              sentry: sentry,
            ),
          ),
          userSyncHandlerProvider.overrideWithValue(
            UserSyncHandler(
              database: db,
              logger: MockAppLogger(),
              supabase: client,
            ),
          ),
        ],
      );
      seamContainer = buildSeam(supabase);
      addTearDown(seamContainer.dispose);
      seamController = seamContainer.read(
        onboardingControllerProvider.notifier,
      );
    });

    /// The answers an athlete gives before any account exists.
    void fillDraft([OnboardingController? into]) {
      final c = into ?? seamController;
      c.updateSports({OnboardingSport.running});
      c.updateGoals({OnboardingGoal.performance});
      c.updatePitfalls({OnboardingPitfall.gutIssues});
      c.updatePersonalInfo(
        firstName: 'Ava',
        lastName: 'Ng',
        gender: Gender.female,
        birthYear: 1992,
      );
      c.updateBodyComposition(
        heightFeet: 5,
        heightInches: 6,
        weightPounds: 134,
      );
      c.updateNutritionSettings(
        gutTraining: GutTraining.high,
        sweatRate: SweatRateCat.heavy,
      );
    }

    test('a fresh install never starts an anonymous session: saving with no '
        'account fails cleanly and writes no profile', () async {
      fillDraft();
      // Signed out throughout: GoTrue has no current user.

      final ok = await seamController.saveAllOnboardingData(
        authProvider: 'email',
      );

      expect(ok, isFalse);
      verifyNever(() => goTrue.signInAnonymously());
      expect(await db.select(db.userProfilesTable).get(), isEmpty);
      // The answers are still waiting on the phone for the sign-up.
      expect(seamController.hasCompletedProfileDraft, isTrue);
    });

    test('answers given before sign-up are on the account after it', () async {
      fillDraft();
      // The athlete signs up: GoTrue now holds the new account.
      final account = _signedUp();
      when(() => goTrue.currentUser).thenReturn(account);

      final ok = await seamController.saveAllOnboardingData(
        authProvider: 'email',
      );

      expect(ok, isTrue);
      verifyNever(() => goTrue.signInAnonymously());

      final profile = await db.userDao.getUserProfileById(_accountUid);
      expect(
        profile,
        isNotNull,
        reason: 'the profile lives under the account uid',
      );
      expect(profile!.authUserId, _accountUid);
      expect(profile.isAnonymous, isFalse);
      expect(profile.authProvider, 'email');
      expect(profile.onboardingCompleted, isTrue);
      expect(profile.firstName, 'Ava');
      expect(profile.lastName, 'Ng');
      expect(profile.email, 'ava@example.com');
      expect(profile.gender, Gender.female);
      expect(profile.birthday.year, 1992);
      expect(profile.heightFeet, 5);
      expect(profile.heightInches, 6);
      expect(profile.weightPounds, 134);
      expect(profile.gutTraining, GutTraining.high);
      expect(profile.sweatRate, SweatRateCat.heavy);

      final survey = await (db.select(
        db.onboardingSurveysTable,
      )..where((t) => t.userId.equals(_accountUid))).getSingleOrNull();
      expect(survey, isNotNull, reason: 'the survey row keys off the account');
      expect(survey!.sports, contains('running'));

      // Nothing was written under any other id.
      expect(await db.select(db.userProfilesTable).get(), hasLength(1));
      expect(seamController.draft, const OnboardingDraft());
    });

    test('a carb target edited on the plan reveal is in the uploaded profile '
        '(Finding 03-009)', () async {
      // The network answers here: the finding's loss needs the write-through
      // to succeed, which the refusing client never lets happen.
      final server = _FakePostgrest();
      final remote = SupabaseClient(
        'https://example.supabase.co',
        'test',
        httpClient: MockClient(server.handle),
      );
      final client = MockSupabaseClient();
      when(() => client.auth).thenReturn(goTrue);
      when(
        () => client.from(any()),
      ).thenAnswer((i) => remote.from(i.positionalArguments.first as String));
      final c = buildSeam(client);
      addTearDown(c.dispose);
      final ctl = c.read(onboardingControllerProvider.notifier);

      fillDraft(ctl);
      // The reveal's slider commit: 70 -> 95 g/h on the long run.
      ctl.applyPlanEdits(const OnboardingPlanEdits(longRunCarbGph: 95));
      final account = _signedUp();
      when(() => goTrue.currentUser).thenReturn(account);

      final ok = await ctl.saveAllOnboardingData(authProvider: 'email');
      expect(ok, isTrue);

      // A sync that read the profile before the edit landed writes that copy
      // back to the server (on device: the dirty-row upload racing the save),
      // and the next download brings it home. The profile's first upload is
      // exactly such a copy.
      final firstUpload = server.users.first;
      expect(firstUpload['id'], _accountUid);
      expect(firstUpload['nutrition_target_overrides'], isNull);
      server.rows[_accountUid] = Map.of(firstUpload);
      final repo = await c.read(userRepositoryProvider.future);
      await repo.syncFromRemote(_accountUid);

      // The edit is still the phone's to upload, and the upload carries it.
      final upload = await repo.uploadDirtyRecords(_accountUid);
      expect(upload.success, isTrue, reason: upload.error);
      final uploaded = server.rows[_accountUid]!;
      expect(
        uploaded['nutrition_target_overrides'],
        isNotNull,
        reason: 'the plan-reveal edit must survive a stale server copy',
      );
      final overrides = NutritionTargetOverrides.fromJson(
        uploaded['nutrition_target_overrides'] as Map<String, dynamic>,
      );
      expect(overrides.duringRun?.carbRateGPerH, 95);
      // Untouched fields stay null (null = algorithm default).
      expect(overrides.duringRun?.fluidRateMlPerH, isNull);
      expect(overrides.duringCycling?.carbRateGPerH, isNull);
      // And the rest of the onboarding profile rides along with it.
      expect(uploaded['gut_training_level'], 'high');
      expect(uploaded['sweat_rate'], 'heavy');
      expect(uploaded['dietary_preference'], 'omnivore');
    });

    test(
      'a training app connected before sign-up is re-keyed onto the account',
      () async {
        // The connect step, with no session, writes under the temp id it
        // keeps in prefs (ConnectTrainingController._getOrCreateTempUserId).
        when(
          () => prefs.getString('onboarding_temp_user_id'),
        ).thenReturn(_tempOnboardingId);
        final integrations = IntegrationsRepository(
          database: db,
          supabase: supabase,
          logger: MockAppLogger(),
          sentry: mockSentryReporter(),
        );
        await integrations.upsertIntegration(
          const IntegrationModel(
            userId: _tempOnboardingId,
            provider: 'final_surge',
            accessToken: 'seam-test-token',
            providerAthleteId: 'fs-athlete-42',
            isActive: true,
          ),
        );
        fillDraft();
        final account = _signedUp();
        when(() => goTrue.currentUser).thenReturn(account);

        final ok = await seamController.saveAllOnboardingData(
          authProvider: 'email',
        );

        expect(ok, isTrue);
        expect(
          await integrations.getIntegration(_accountUid, 'final_surge'),
          isNotNull,
          reason: 'the connection follows the answers onto the account',
        );
        expect(
          await integrations.getIntegration(_tempOnboardingId, 'final_surge'),
          isNull,
        );
        verify(() => prefs.remove('onboarding_temp_user_id')).called(1);
      },
    );
  });

  group('draft mutators', () {
    test('updates accumulate into one draft', () {
      controller.updateSports({OnboardingSport.triathlon});
      controller.updateGoals({OnboardingGoal.performance});
      controller.updatePitfalls({
        OnboardingPitfall.gutIssues,
        OnboardingPitfall.energyCrash,
      });
      controller.updatePersonalInfo(
        firstName: 'Avery',
        gender: Gender.other,
        birthYear: 1994,
      );
      controller.updateBodyComposition(
        heightFeet: 5,
        heightInches: 9,
        weightPounds: 140,
      );
      controller.updateNutritionSettings(
        gutTraining: GutTraining.high,
        sweatRate: SweatRateCat.heavy,
      );

      final draft = controller.draft;
      expect(draft.sports, {OnboardingSport.triathlon});
      expect(draft.goals, {OnboardingGoal.performance});
      expect(draft.pitfalls, hasLength(2));
      expect(draft.firstName, 'Avery');
      expect(draft.gender, Gender.other);
      expect(draft.birthYear, 1994);
      expect(draft.weightPounds, 140);
      expect(draft.gutTraining, GutTraining.high);
      expect(draft.sweatRate, SweatRateCat.heavy);
    });

    test('blank strings CLEAR a field; omitted arguments retain it', () {
      // The screens call updatePersonalInfo per keystroke, so backspacing a
      // field to empty must clear the draft value — retaining the last
      // non-blank fragment would let a half-typed email ("x@") outrank the
      // real auth email in saveAllOnboardingData. Omitting the argument
      // (null) is what means "no change".
      controller.updatePersonalInfo(firstName: 'Avery', email: 'a@b.c');
      controller.updatePersonalInfo(email: '');
      expect(controller.draft.firstName, 'Avery'); // omitted → retained
      expect(controller.draft.email, isNull); // blank → cleared
      controller.updatePersonalInfo(firstName: '  ');
      expect(controller.draft.firstName, isNull); // whitespace → cleared
    });

    test('hasCompletedProfileDraft requires gender, birth year and weight', () {
      expect(controller.hasCompletedProfileDraft, isFalse);
      controller.updatePersonalInfo(gender: Gender.female, birthYear: 1990);
      expect(controller.hasCompletedProfileDraft, isFalse);
      controller.updateBodyComposition(weightPounds: 150);
      expect(controller.hasCompletedProfileDraft, isTrue);
    });

    test('connect-step flags land in the draft', () {
      controller.recordConnectedProvider('garmin');
      controller.recordTridotNotifyRequested();
      controller.recordSweatTestInterest();
      expect(controller.draft.connectedProvider, 'garmin');
      expect(controller.draft.tridotNotifyRequested, isTrue);
      expect(controller.draft.sweatTestInterest, isTrue);
    });
  });

  group('incomplete-draft guard', () {
    test('saveAllOnboardingData returns false cleanly with no draft', () async {
      final ok = await controller.saveAllOnboardingData(authProvider: 'email');
      expect(ok, isFalse);
      // MEALVANA-ENDURANCE-DEV-4M regression: must not surface an AsyncError.
      expect(container.read(onboardingControllerProvider).hasError, isFalse);
    });
  });

  group('mergedOverridesForEdits (pure)', () {
    test('writes only edited fields; untouched stay null', () {
      final merged = OnboardingController.mergedOverridesForEdits(
        null,
        const OnboardingPlanEdits(longRunCarbGph: 65),
      );
      expect(merged.duringRun?.carbRateGPerH, 65);
      expect(merged.duringRun?.fluidRateMlPerH, isNull);
      expect(merged.duringCycling?.carbRateGPerH, isNull);
    });

    test('fluid/sodium edits apply to both run and ride', () {
      final merged = OnboardingController.mergedOverridesForEdits(
        null,
        const OnboardingPlanEdits(fluidMlPerHr: 600, sodiumMgPerHr: 800),
      );
      expect(merged.duringRun?.fluidRateMlPerH, 600);
      expect(merged.duringCycling?.fluidRateMlPerH, 600);
      expect(merged.duringRun?.sodiumRateMgPerH, 800);
      expect(merged.duringCycling?.sodiumRateMgPerH, 800);
    });

    test('existing overrides survive a partial edit', () {
      const existing = NutritionTargetOverrides(
        duringRun: DuringActivityOverrides(fluidRateMlPerH: 500),
      );
      final merged = OnboardingController.mergedOverridesForEdits(
        existing,
        const OnboardingPlanEdits(longRunCarbGph: 60),
      );
      expect(merged.duringRun?.carbRateGPerH, 60);
      expect(merged.duringRun?.fluidRateMlPerH, 500);
    });

    test('guardrails clamp out-of-range edits', () {
      final merged = OnboardingController.mergedOverridesForEdits(
        null,
        const OnboardingPlanEdits(
          longRunCarbGph: 500, // way past the 120 g/hr ceiling
          fluidMlPerHr: 50, // below the 200 mL/hr floor
        ),
      );
      expect(
        merged.duringRun!.carbRateGPerH,
        lessThanOrEqualTo(NutritionTargetGuardrails.duringMaxCarbRateGPerH),
      );
      expect(
        merged.duringRun!.fluidRateMlPerH,
        greaterThanOrEqualTo(
          NutritionTargetGuardrails.duringMinFluidRateMlPerH,
        ),
      );
    });
  });
}
