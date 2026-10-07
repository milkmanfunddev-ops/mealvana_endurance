/// Unit tests for the redesigned OnboardingController: draft mutators, the
/// incomplete-draft guard, the legacy-cache bridge (transition safety), and
/// the pure plan-edit → NutritionTargetOverrides merge.
///
/// The full saveAllOnboardingData pipeline (profile create → migrate →
/// upload → defaults → survey → overrides) is covered by the Patrol e2e
/// flows, except Finding 03-009 (mealplanning t40): that seam runs the real
/// pipeline over in-memory Drift and a fake PostgREST (`MockClient`) that
/// accepts writes, with GoTrue's current user faked in the shape it arrives.
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
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_target_overrides.dart';
import 'package:mealvana_endurance/features/onboarding/domain/onboarding_draft.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_controller.dart';
import 'package:mealvana_endurance/features/onboarding/data/onboarding_survey_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/app_version_service.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mealvana_endurance/shared/services/sync/entity_sync/user_sync_handler.dart';

import '../../helpers/fakes/recording_report.dart';
import '../../helpers/widget_test_harness.dart';

class _MockUser extends Mock implements User {}

/// The uid GoTrue hands back once the athlete has signed up.
const _accountUid = '00000000-0000-0000-0000-0000000000ac';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late OnboardingController controller;

  setUp(() {
    container = ProviderContainer();
    controller = container.read(onboardingControllerProvider.notifier);
  });

  tearDown(() => container.dispose());

  group('onboarding save seam (Finding 03-009)', () {
    test('a carb target edited on the plan reveal is in the uploaded profile '
        '(Finding 03-009)', () async {
      // The snapshot service reads SharedPreferences.getInstance() directly.
      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final goTrue = fakeGoTrueClient() as MockGoTrueClient;

      final prefs = MockSharedPreferences();
      when(() => prefs.getBool(any())).thenReturn(null);
      when(() => prefs.getString(any())).thenReturn(null);
      when(() => prefs.getInt(any())).thenReturn(null);
      when(() => prefs.getStringList(any())).thenReturn(null);
      when(() => prefs.remove(any())).thenAnswer((_) async => true);
      when(() => prefs.setString(any(), any())).thenAnswer((_) async => true);
      when(() => prefs.setBool(any(), any())).thenAnswer((_) async => true);

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

      // The network answers here: the finding's loss needs the write-through
      // to succeed.
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

      final report = RecordingReport();
      final c = ProviderContainer(
        overrides: [
          appExternalDepsProvider.overrideWithValue(
            AppExternalDeps(
              analytics: analytics,
              supabaseClient: client,
              sharedPreferences: prefs,
            ),
          ),
          reportProvider.overrideWithValue(report),
          sharedPreferencesProvider.overrideWithValue(prefs),
          inMemoryDatabaseOverride(db),
          // package_info has no platform in a test VM.
          runningAppVersionProvider.overrideWith((ref) async => '1.0.0'),
          // These two providers build from Supabase.instance, which does not
          // exist in a test VM; same repositories, explicit construction.
          onboardingSurveyRepositoryProvider.overrideWithValue(
            OnboardingSurveyRepository(
              supabase: client,
              database: db,
              report: report,
            ),
          ),
          userSyncHandlerProvider.overrideWithValue(
            UserSyncHandler(database: db, supabase: client),
          ),
        ],
      );
      addTearDown(c.dispose);
      final ctl = c.read(onboardingControllerProvider.notifier);

      ctl.updateSports({OnboardingSport.running});
      ctl.updateGoals({OnboardingGoal.performance});
      ctl.updatePitfalls({OnboardingPitfall.gutIssues});
      ctl.updatePersonalInfo(
        firstName: 'Ava',
        lastName: 'Ng',
        gender: Gender.female,
        birthYear: 1992,
      );
      ctl.updateBodyComposition(
        heightFeet: 5,
        heightInches: 6,
        weightPounds: 134,
      );
      ctl.updateNutritionSettings(
        gutTraining: GutTraining.high,
        sweatRate: SweatRateCat.heavy,
      );
      // The reveal's slider commit: 70 -> 95 g/h on the long run.
      ctl.applyPlanEdits(const OnboardingPlanEdits(longRunCarbGph: 95));
      final account = _signedUp();
      when(() => goTrue.currentUser).thenReturn(account);

      final ok = await ctl.saveAllOnboardingData(
        authProvider: 'email',
        isAnonymous: false,
      );
      expect(ok, isTrue, reason: '${report.faults}');

      // A sync that read the profile before the edit landed writes that copy
      // back to the server (on device: the dirty-row upload racing the save),
      // and the next download brings it home. The profile's first upload is
      // exactly such a copy.
      final firstUpload = server.users.first;
      final userId = firstUpload['id'] as String;
      expect(firstUpload['nutrition_target_overrides'], isNull);
      server.rows[userId] = Map.of(firstUpload);
      final repo = await c.read(userRepositoryProvider.future);
      await repo.syncFromRemote(userId);

      // The edit is still the phone's to upload, and the upload carries it.
      final upload = await repo.uploadDirtyRecords(userId);
      expect(upload.success, isTrue, reason: upload.error);
      final uploaded = server.rows[userId]!;
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
    });
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
      final ok = await controller.saveAllOnboardingData();
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
