/// A lapsed account cannot write a meal plan, a shopping list, a meal's
/// notes or votes, Vana's settings, or call Vana (mp-457 §4, mp-491,
/// ticket 12).
///
/// Through the real meal-planning notifiers: each write path asks the write
/// guard first; refused, it opens the paywall once and never constructs the
/// repository, the vana-action client or the chat repository, so nothing is
/// written locally, sent to the server or queued.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_logging/application/meal_ai_service.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_detail_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_photos_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_plan_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/plan_day_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/shopping_list_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_chat_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_conversations_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_settings_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_library_remote_data_source.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_photo_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_plan_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_review_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/user_memory_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_action_client.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_chat_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/cooking_session.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/day_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_detail.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_photo_history.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_type.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/plan_rule.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/shopping_item.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_conversation.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_conversation_kind.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_part.dart';

import '../../../helpers/write_access.dart';

class _FakePlan extends Fake implements MealPlan {}

class _FakeSlotRef extends Fake implements DaySlotRef {}

class _FakeRule extends Fake implements PlanRule {}

class _FakeDetail extends Fake implements MealDetail {}

class _FakePhotos extends Fake implements MealPhotos {}

class _FakeItem extends Fake implements ShoppingItem {}

const _receipt = VanaReceiptPart(
  action: VanaReceiptAction.deletePlan,
  entity: VanaReceiptEntity.plan,
  summary: 'Plan deleted',
  entityId: 'p1',
);

class _SeededPlan extends MealPlanController {
  @override
  FutureOr<MealPlan?> build() => _FakePlan();
}

class _SeededDay extends PlanDayController {
  @override
  FutureOr<DayPlan> build(String date) => DayPlan.empty;
}

class _SeededDetail extends MealDetailController {
  @override
  FutureOr<MealDetail> build(String id) => _FakeDetail();
}

class _SeededPhotos extends MealPhotosController {
  @override
  FutureOr<MealPhotos> build(String mealId) => _FakePhotos();
}

class _SeededShopping extends ShoppingListController {
  @override
  FutureOr<ShoppingListState> build() => const ShoppingListState();
}

class _SeededChat extends VanaChatController {
  @override
  FutureOr<VanaChatState> build({
    required VanaConversationKind kind,
    String? conversationId,
  }) => VanaChatState(kind: kind);
}

class _SeededConversations extends VanaConversationsController {
  @override
  FutureOr<List<VanaConversationSummary>> build(VanaConversationKind kind) =>
      const [];
}

class _SeededSettings extends VanaSettingsController {
  @override
  FutureOr<VanaSettingsState> build() => const VanaSettingsState();
}

void main() {
  late PaywallOpens opens;
  late ProviderContainer container;
  const kind = VanaConversationKind.mealPlanning;

  setUp(() {
    opens = PaywallOpens();
    container = ProviderContainer(
      overrides: [
        writesRefused(),
        opens.override,
        mealPlanRepositoryProvider.overrideWith(
          untouched('mealPlanRepository'),
        ),
        vanaActionClientProvider.overrideWith(untouched('vanaActionClient')),
        vanaChatRepositoryProvider.overrideWith(
          untouched('vanaChatRepository'),
        ),
        mealLibraryRemoteDataSourceProvider.overrideWith(
          untouched('mealLibraryRemoteDataSource'),
        ),
        mealReviewRepositoryProvider.overrideWith(
          untouched('mealReviewRepository'),
        ),
        mealPhotoRepositoryProvider.overrideWith(
          untouched('mealPhotoRepository'),
        ),
        userMemoryRepositoryProvider.overrideWith(
          untouched('userMemoryRepository'),
        ),
        mealAiServiceProvider.overrideWith(untouched('mealAiService')),
        mealPlanControllerProvider.overrideWith(_SeededPlan.new),
        planDayControllerProvider.overrideWith(_SeededDay.new),
        mealDetailControllerProvider.overrideWith(_SeededDetail.new),
        mealPhotosControllerProvider.overrideWith(_SeededPhotos.new),
        shoppingListControllerProvider.overrideWith(_SeededShopping.new),
        vanaChatControllerProvider.overrideWith(_SeededChat.new),
        vanaConversationsControllerProvider.overrideWith(
          _SeededConversations.new,
        ),
        vanaSettingsControllerProvider.overrideWith(_SeededSettings.new),
      ],
    );
    addTearDown(container.dispose);
  });

  void refusedGroup<N>(
    String name,
    N Function() notifier,
    Map<String, Future<Object?> Function(N)> paths, {
    Future<void> Function()? warm,
  }) {
    group('$name, lapsed', () {
      for (final entry in paths.entries) {
        test('${entry.key} opens the paywall and writes nothing', () async {
          if (warm != null) await warm();
          await expectWriteRefused(opens, () => entry.value(notifier()));
        });
      }
    });
  }

  refusedGroup<MealPlanController>(
    'MealPlanController',
    () => container.read(mealPlanControllerProvider.notifier),
    {
      'setServings': (c) => c.setServings('pm1', 2),
      'removeMeal': (c) => c.removeMeal('pm1'),
      'setSession': (c) => c.setSession('pm1', CookingSession.cookSun),
      'addComment': (c) => c.addComment('pm1', 'less salt'),
      'toggleShopping': (c) =>
          c.toggleShopping('rice', ShoppingField.checked, true),
      'setDaySlot': (c) =>
          c.setDaySlot('2026-09-22', MealType.breakfast, _FakeSlotRef()),
      'clearDaySlot': (c) => c.clearDaySlot('2026-09-22', MealType.breakfast),
      'pickMeals': (c) =>
          c.pickMeals([const MealPick(source: MealSource.library, id: 'm1')]),
      'swapMeal': (c) =>
          c.swapMeal('pm1', source: MealSource.library, id: 'm2'),
      'confirmPlan': (c) => c.confirmPlan(),
      'swapIngredient': (c) =>
          c.swapIngredient('pm1', from: 'butter', to: 'oil'),
      'acceptRule': (c) => c.acceptRule(_FakeRule()),
      'newPlan': (c) => c.newPlan(),
      'deletePlan': (c) => c.deletePlan(),
      'undoDeletePlan': (c) => c.undoDeletePlan(_receipt),
      'logFromPlan': (c) => c.logFromPlan('pm1'),
      'planDay': (c) => c.planDay(),
    },
  );

  final dayProvider = planDayControllerProvider('2026-09-22');
  refusedGroup<PlanDayController>(
    'PlanDayController',
    () => container.read(dayProvider.notifier),
    {
      'setSlot': (c) => c.setSlot(MealType.lunch, _FakeSlotRef()),
      'clearSlot': (c) => c.clearSlot(MealType.lunch),
      'planDay': (c) => c.planDay(),
    },
    warm: () => container.read(dayProvider.future),
  );

  final detailProvider = mealDetailControllerProvider('m1');
  refusedGroup<MealDetailController>(
    'MealDetailController',
    () => container.read(detailProvider.notifier),
    {
      'vote': (c) => c.vote(1),
      'setNotes': (c) => c.setNotes('good'),
      'saveToMine': (c) => c.saveToMine(),
      'review': (c) => c.review(isGood: true, why: 'tasty'),
    },
    warm: () => container.read(detailProvider.future),
  );

  final photosProvider = mealPhotosControllerProvider('m1');
  refusedGroup<MealPhotosController>(
    'MealPhotosController',
    () => container.read(photosProvider.notifier),
    {
      'addAddress': (c) => c.addAddress(url: 'https://example.com/a.jpg'),
      'addUpload': (c) => c.addUpload(bytes: Uint8List(0)),
      'remove': (c) => c.remove(),
      'restore': (c) => c.restore('p1'),
      'delete': (c) => c.delete('p1'),
    },
    warm: () => container.read(photosProvider.future),
  );

  refusedGroup<ShoppingListController>(
    'ShoppingListController',
    () => container.read(shoppingListControllerProvider.notifier),
    {
      'setChecked': (c) => c.setChecked('rice', true),
      'setHave': (c) => c.setHave('rice', true),
      'addItem': (c) => c.addItem('rice'),
      'updateItem': (c) => c.updateItem(_FakeItem(), name: 'rice', qty: '1'),
      'deleteItem': (c) => c.deleteItem(_FakeItem()),
      'newList': (c) => c.newList(),
      'renameList': (c) => c.renameList('Weekend'),
      'deleteList': (c) => c.deleteList('l1'),
    },
    warm: () => container.read(shoppingListControllerProvider.future),
  );

  final chatProvider = vanaChatControllerProvider(kind: kind);
  refusedGroup<VanaChatController>(
    'VanaChatController',
    () => container.read(chatProvider.notifier),
    {
      'loadOpener': (c) => c.loadOpener(),
      'send': (c) => c.send('plan my week'),
      'tapChip': (c) => c.tapChip('Plan my week'),
      'rewindAndSend': (c) => c.rewindAndSend('msg1', 'again'),
      'sendPantryPhoto': (c) => c.sendPantryPhoto(Uint8List(0)),
      'usePantry': (c) => c.usePantry(const ['rice'], message: 'use these'),
      'undoReceipt': (c) => c.undoReceipt(_receipt),
    },
    warm: () => container.read(chatProvider.future),
  );

  final conversationsProvider = vanaConversationsControllerProvider(kind);
  refusedGroup<VanaConversationsController>(
    'VanaConversationsController',
    () => container.read(conversationsProvider.notifier),
    {'create': (c) => c.create()},
    warm: () => container.read(conversationsProvider.future),
  );

  refusedGroup<VanaSettingsController>(
    'VanaSettingsController',
    () => container.read(vanaSettingsControllerProvider.notifier),
    {
      'setBatchCooking': (c) => c.setBatchCooking(true),
      'setShowMacros': (c) => c.setShowMacros(true),
      'setWeekStart': (c) => c.setWeekStart(1),
      'setPeriodDays': (c) => c.setPeriodDays(7),
      'setRemindersEnabled': (c) => c.setRemindersEnabled(true),
      'deleteMemory': (c) => c.deleteMemory('mem1'),
    },
    warm: () => container.read(vanaSettingsControllerProvider.future),
  );
}
