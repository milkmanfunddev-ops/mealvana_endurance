/// "New meal plan" from the Plan tab (testing-wave 14-001 / 14-002, ticket
/// 70; mp-234, and Lee's 2026-09-25 ruling on mp-668):
///
/// - the new conversation shows its plan bar from the start, at
///   "Your plan · 0 meals", before any pick;
/// - nothing happens to this week's plan until the new one is confirmed: the
///   confirmed plan stays confirmed (and stays what the Plan tab reads) while
///   the athlete picks into the new conversation's own draft.
///
/// Driven from the chat screen through the REAL VanaChatController and the
/// REAL MealPlanController over an in-memory Drift DB; only the transports
/// (chat stream, `vana-action`, the plan table's remote) are fakes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/ai_credits/application/credits_controller.dart';
import 'package:mealvana_endurance/features/ai_credits/application/purchase_controller.dart';
import 'package:mealvana_endurance/features/ai_credits/data/credits_repository.dart';
import 'package:mealvana_endurance/features/ai_credits/domain/credit_wallet.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/feedback/data/wiredash_feedback_filer.dart';
import 'package:mealvana_endurance/features/feedback/domain/typed_feedback.dart';
import 'package:mealvana_endurance/features/meal_logging/application/meal_ai_service.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_plan_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_plan_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/user_memory_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_action_client.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_chat_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan_status.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/user_memory.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_conversation_kind.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_input_mode.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_moment.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_part.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_situation.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_stream_event.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/week_start.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/vana_chat_screen.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../ai_credits/helpers/counting_credits_repository.dart';
import '../../domain/fixture_helpers.dart';
import '../../helpers/container.dart';
import '../../helpers/fakes.dart';
import '../helpers/test_content.dart';

const _user = 'user-1';
const _newConversation = 'conv-new';
const _oldPlan = 'plan-old';

/// The chat transport: the new-plan opener streams Vana's first dinner
/// picker and names the new conversation.
class _OpenerRepo extends Fake implements VanaChatRepository {
  _OpenerRepo(this.picker);

  final VanaPart picker;
  final List<bool> openers = [];

  @override
  Future<VanaChatResponse> streamChat({
    String? message,
    String? conversationId,
    required VanaConversationKind kind,
    bool opener = false,
    String? anchorDate,
    String? timezone,
    VanaSituation? situation,
    VanaMoment? moment,
    bool newPlan = false,
    VanaInputMode? inputMode,
  }) async {
    if (opener) openers.add(newPlan);
    // An `async*` generator, not Stream.value (see the picker-chips test).
    Stream<VanaStreamEvent> events() async* {
      yield const VanaTextEvent('Three dinners to start.');
      yield VanaUiEvent(picker);
      yield const VanaDoneEvent();
    }

    return VanaChatResponse(
      conversationId: _newConversation,
      kind: kind,
      events: events(),
    );
  }

  @override
  Future<String> createConversation(VanaConversationKind kind) async =>
      _newConversation;
}

/// `vana-action` as the server answers a new conversation: `get_plan` has no
/// draft yet, and `pick_meals` scoped to the conversation starts its draft.
class _Actions extends Fake implements VanaActionClient {
  _Actions(this.draft);

  final MealPlan draft;
  final List<UiAction> ran = [];

  @override
  Future<VanaActionResult> run(UiAction action) async {
    ran.add(action);
    if (action is PickMealsAction) {
      return VanaActionResult(
        parts: [VanaBatchPart(plan: draft)],
        extras: const {},
      );
    }
    return const VanaActionResult(parts: [], extras: {});
  }
}

class _FakeMemoryRepo extends Fake implements UserMemoryRepository {
  @override
  Future<void> applyServerMemory(
    UserMemory memory, {
    required String userId,
  }) async {}
}

class _FakeMealAi extends Fake implements MealAiService {}

class _FakeFiler extends Fake implements WiredashFeedbackFiler {
  @override
  Future<void> file(TypedFeedback feedback) async {}
}

class _OpenWallet extends CreditsController {
  @override
  Future<CreditWallet> build() async => CreditWallet.fromMap(const {
    'balance': 3000000,
    'allowance': 3000000,
    'allowance_monthly': 4000000,
    'allowance_expires_at': '2026-10-15T12:00:00+00:00',
  });
}

Map<String, dynamic> _planRow(String weekStart) => {
  'id': _oldPlan,
  'user_id': _user,
  'week_start': weekStart,
  'status': 'confirmed',
  'batch_cooking': true,
  'rules': const [],
  'shopping': const [],
  'days': const {},
  'day_notes': const {},
  'day_notes_stale': false,
  'created_at': '2026-09-20T12:00:00Z',
  'updated_at': '2026-09-24T01:10:06Z',
  'is_deleted': false,
};

Map<String, dynamic> _mealRow(String id, int position) => {
  'id': id,
  'plan_id': _oldPlan,
  'user_id': _user,
  'source': 'library',
  'library_meal_id': 'D-04$position',
  'name': 'This week meal $position',
  'meal_type': 'dinner',
  'session': null,
  'servings': 4,
  'servings_left': 4,
  'kcal': 500,
  'carbs_g': 60,
  'protein_g': 30,
  'fat_g': 15,
  'swaps_applied': const [],
  'comments': const [],
  'position': position,
  'created_at': '2026-09-20T12:00:00Z',
  'updated_at': '2026-09-20T12:00:00Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final picker = VanaPart.fromJson(loadFixture('meal_picker'))!;
  final firstPick = (picker as VanaMealPickerPart).meals.first;

  late AppDatabase db;
  late MealPlanRepository repo;
  late _OpenerRepo chat;
  late _Actions actions;
  late MealPlan draft;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.memory();
    final remote = RecordingMealPlanRemote()
      ..plans = [_planRow(weekStartFor())]
      ..meals = [
        _mealRow('pm-old-1', 0),
        _mealRow('pm-old-2', 1),
        _mealRow('pm-old-3', 2),
        _mealRow('pm-old-4', 3),
      ];
    repo = MealPlanRepository(
      database: db,
      logger: FakeLogger(),
      remote: remote,
    );
    final synced = await repo.syncFromRemote(_user);
    expect(synced.success, isTrue, reason: synced.error);

    // The new conversation's own draft, for this same week, after one pick.
    final fixture = VanaActionResult.fromJson(loadFixture('batch')).plan!;
    draft = fixture.copyWith(
      weekStart: weekStartFor(),
      status: MealPlanStatus.draft,
      conversationId: _newConversation,
      meals: [fixture.meals.first],
    );

    chat = _OpenerRepo(picker);
    actions = _Actions(draft);
  });

  tearDown(() => db.close());

  Future<void> pumpNewPlan(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The Plan tab's "New meal plan": `/vana?c=new&mode=meal_planning&intent=new_plan`.
    final router = GoRouter(
      initialLocation: '/vana',
      routes: [
        GoRoute(
          path: '/vana',
          builder: (_, __) => const VanaChatScreen(
            kind: VanaConversationKind.mealPlanning,
            startOpener: true,
            newPlan: true,
          ),
        ),
      ],
    );
    container = ProviderContainer(
      overrides: [
        ...baseOverrides(userId: _user),
        appDatabaseProvider.overrideWithValue(db),
        mealPlanRepositoryProvider.overrideWithValue(repo),
        contentServiceProvider.overrideWith(testContentService),
        vanaChatRepositoryProvider.overrideWithValue(chat),
        userMemoryRepositoryProvider.overrideWithValue(_FakeMemoryRepo()),
        vanaActionClientProvider.overrideWithValue(actions),
        mealAiServiceProvider.overrideWithValue(_FakeMealAi()),
        wiredashFeedbackFilerProvider.overrideWithValue(_FakeFiler()),
        creditsControllerProvider.overrideWith(() => _OpenWallet()),
        creditsRepositoryProvider.overrideWithValue(
          CountingCreditsRepository(),
        ),
        visibleCreditPackagesProvider.overrideWith((ref) async => const []),
      ],
    );
    // The Plan tab is underneath: the week's plan is being watched.
    container.listen(mealPlanControllerProvider, (_, __) {});
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
  }

  /// Let the opener (and any write) land. The typing indicator animates while
  /// a turn is in flight, so never pumpAndSettle with one open.
  Future<void> settleTurn(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Unmount and drop the container before the DB closes, so no Drift
  /// watch outlives the test.
  Future<void> teardownScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder barReads(String count) => find.byWidgetPredicate(
    (w) =>
        w is RichText &&
        w.text.toPlainText().contains('Your plan') &&
        w.text.toPlainText().contains(count),
  );

  /// The week's active plan as the Plan tab reads it, straight from Drift.
  Future<MealPlan?> weeksPlan(WidgetTester tester) async {
    final read = repo.getActivePlan(_user, weekStartFor());
    await tester.pump(const Duration(milliseconds: 50));
    return read;
  }

  testWidgets('a new meal-plan conversation shows "Your plan · 0 meals" '
      'before any pick', (tester) async {
    await pumpNewPlan(tester);
    await settleTurn(tester);

    expect(chat.openers, [true], reason: 'the opener carries new_plan');
    expect(barReads('0 meals'), findsOneWidget);
    // It is this conversation's (empty) draft, never this week's plan.
    expect(barReads('4 meals'), findsNothing);

    await teardownScreen(tester);
  });

  testWidgets('New meal plan leaves this week\'s confirmed plan confirmed '
      'while the athlete picks into the new draft', (tester) async {
    await pumpNewPlan(tester);
    await settleTurn(tester);

    // The tap and the opener changed nothing.
    var week = await weeksPlan(tester);
    expect(week?.id, _oldPlan);
    expect(week?.status, MealPlanStatus.confirmed);
    expect(container.read(mealPlanControllerProvider).value?.id, _oldPlan);
    expect(actions.ran.whereType<NewPlanAction>(), isEmpty);

    // The first pick lands on the new conversation's own draft.
    final tick = find.byKey(
      ValueKey('meal_planning.picker_tick_${firstPick.id}'),
    );
    await tester.ensureVisible(tick);
    await tester.tap(tick);
    await settleTurn(tester);

    final pick = actions.ran.whereType<PickMealsAction>().single;
    expect(pick.conversationId, _newConversation);
    expect(barReads('1 meal'), findsOneWidget);

    // This week's plan is still the confirmed one, with its four meals,
    // through the real MealPlanController the Plan tab reads.
    week = await weeksPlan(tester);
    expect(week?.id, _oldPlan);
    expect(week?.status, MealPlanStatus.confirmed);
    expect(week?.meals, hasLength(4));
    final shown = container.read(mealPlanControllerProvider).value;
    expect(shown?.id, _oldPlan);
    expect(shown?.status, MealPlanStatus.confirmed);
    // The draft sits beside it, not in its place.
    final draftRead = repo.watchConversationPlan(_user, _newConversation).first;
    await tester.pump(const Duration(milliseconds: 50));
    final drafted = await draftRead;
    expect(drafted?.status, MealPlanStatus.draft);
    expect(actions.ran.whereType<NewPlanAction>(), isEmpty);

    await teardownScreen(tester);
  });
}
