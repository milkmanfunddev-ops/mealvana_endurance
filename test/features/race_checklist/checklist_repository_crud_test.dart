/// Unit tests for ChecklistRepository and GearTemplateService.
///
/// Uses AppDatabase.memory() for real Drift round-trips.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mealvana_endurance/features/race_checklist/application/gear_template_service.dart';
import 'package:mealvana_endurance/features/race_checklist/data/checklist_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAppLogger extends Mock implements AppLogger {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

MockAppLogger _silentLogger() {
  final m = MockAppLogger();
  when(
    () => m.info(
      any(),
      context: any(named: 'context'),
      data: any(named: 'data'),
    ),
  ).thenReturn(null);
  when(
    () => m.debug(
      any(),
      context: any(named: 'context'),
      data: any(named: 'data'),
    ),
  ).thenReturn(null);
  when(
    () => m.error(
      any(),
      context: any(named: 'context'),
      error: any(named: 'error'),
      stackTrace: any(named: 'stackTrace'),
      data: any(named: 'data'),
    ),
  ).thenReturn(null);
  when(
    () => m.warning(
      any(),
      context: any(named: 'context'),
      error: any(named: 'error'),
      data: any(named: 'data'),
    ),
  ).thenReturn(null);
  // Overloads without positional args
  when(() => m.error(any(), error: any(named: 'error'))).thenReturn(null);
  return m;
}

ChecklistRepository _makeRepo(AppDatabase db) {
  return ChecklistRepository(db, _silentLogger());
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  // =========================================================================
  // checklistExists
  // =========================================================================

  group('checklistExists', () {
    test('returns false when event has no checklist items', () async {
      final repo = _makeRepo(db);
      expect(await repo.checklistExists('event-1'), isFalse);
    });

    test('returns true after createChecklistItems', () async {
      final repo = _makeRepo(db);
      await repo.createChecklistItems(
        eventId: 'event-1',
        userId: 'user-1',
        gearItems: ['Running shoes', 'Socks'],
      );
      expect(await repo.checklistExists('event-1'), isTrue);
    });

    test('is scoped to eventId — different event returns false', () async {
      final repo = _makeRepo(db);
      await repo.createChecklistItems(
        eventId: 'event-1',
        userId: 'user-1',
        gearItems: ['Running shoes'],
      );
      expect(await repo.checklistExists('event-2'), isFalse);
    });
  });

  // =========================================================================
  // createChecklistItems
  // =========================================================================

  group('createChecklistItems', () {
    test('all items are persisted with correct eventId and userId', () async {
      final repo = _makeRepo(db);
      const gearItems = ['Helmet', 'Goggles', 'Wetsuit'];
      await repo.createChecklistItems(
        eventId: 'event-tri',
        userId: 'user-1',
        gearItems: gearItems,
      );

      final items = await repo.getChecklistForEvent('event-tri');
      expect(items.length, equals(3));
      expect(items.map((i) => i.itemName), containsAll(gearItems));
      for (final item in items) {
        expect(item.eventId, equals('event-tri'));
        expect(item.userId, equals('user-1'));
      }
    });

    test('items are created with isChecked=false by default', () async {
      final repo = _makeRepo(db);
      await repo.createChecklistItems(
        eventId: 'event-1',
        userId: 'user-1',
        gearItems: ['Running shoes', 'Hat'],
      );
      final items = await repo.getChecklistForEvent('event-1');
      for (final item in items) {
        expect(item.isChecked, isFalse);
      }
    });

    test('sort order is assigned in list order (0-indexed)', () async {
      final repo = _makeRepo(db);
      await repo.createChecklistItems(
        eventId: 'event-1',
        userId: 'user-1',
        gearItems: ['First', 'Second', 'Third'],
      );
      final items = await repo.getChecklistForEvent('event-1');
      expect(items[0].itemName, equals('First'));
      expect(items[0].sortOrder, equals(0));
      expect(items[1].sortOrder, equals(1));
      expect(items[2].sortOrder, equals(2));
    });

    test('category defaults to "gear"', () async {
      final repo = _makeRepo(db);
      await repo.createChecklistItems(
        eventId: 'event-1',
        userId: 'user-1',
        gearItems: ['Shoes'],
      );
      final items = await repo.getChecklistForEvent('event-1');
      expect(items.first.category, equals('gear'));
    });

    test('accepts "nutrition" category', () async {
      final repo = _makeRepo(db);
      await repo.createChecklistItems(
        eventId: 'event-1',
        userId: 'user-1',
        gearItems: ['GU Gel - 3 packets'],
        category: 'nutrition',
      );
      final items = await repo.getChecklistForEvent('event-1');
      expect(items.first.category, equals('nutrition'));
    });

    test('isTemplateItem=true for batch-created items', () async {
      final repo = _makeRepo(db);
      await repo.createChecklistItems(
        eventId: 'event-1',
        userId: 'user-1',
        gearItems: ['Shoes'],
      );
      final items = await repo.getChecklistForEvent('event-1');
      expect(items.first.isTemplateItem, isTrue);
    });

    test('items for different events are independent', () async {
      final repo = _makeRepo(db);
      await repo.createChecklistItems(
        eventId: 'event-A',
        userId: 'user-1',
        gearItems: ['Item A1', 'Item A2'],
      );
      await repo.createChecklistItems(
        eventId: 'event-B',
        userId: 'user-1',
        gearItems: ['Item B1'],
      );

      final aItems = await repo.getChecklistForEvent('event-A');
      final bItems = await repo.getChecklistForEvent('event-B');
      expect(aItems.length, equals(2));
      expect(bItems.length, equals(1));
    });
  });

  // =========================================================================
  // getChecklistForEvent
  // =========================================================================

  group('getChecklistForEvent', () {
    test('returns empty list for unknown event', () async {
      final repo = _makeRepo(db);
      final items = await repo.getChecklistForEvent('unknown-event');
      expect(items, isEmpty);
    });

    test('items are returned sorted by sortOrder ascending', () async {
      final repo = _makeRepo(db);
      await repo.createChecklistItems(
        eventId: 'event-1',
        userId: 'user-1',
        gearItems: ['Alpha', 'Beta', 'Gamma'],
      );
      final items = await repo.getChecklistForEvent('event-1');
      expect(items[0].itemName, equals('Alpha'));
      expect(items[1].itemName, equals('Beta'));
      expect(items[2].itemName, equals('Gamma'));
    });
  });

  // =========================================================================
  // toggleItemChecked
  // =========================================================================

  group('toggleItemChecked', () {
    test('marks item as checked and sets checkedAt', () async {
      final repo = _makeRepo(db);
      await repo.createChecklistItems(
        eventId: 'event-1',
        userId: 'user-1',
        gearItems: ['Running shoes'],
      );
      final items = await repo.getChecklistForEvent('event-1');
      final itemId = items.first.id;

      await repo.toggleItemChecked(itemId, true);

      final updated = await repo.getChecklistForEvent('event-1');
      expect(updated.first.isChecked, isTrue);
      expect(updated.first.checkedAt, isNotNull);
    });

    test('unchecking clears checkedAt', () async {
      final repo = _makeRepo(db);
      await repo.createChecklistItems(
        eventId: 'event-1',
        userId: 'user-1',
        gearItems: ['Running shoes'],
      );
      final items = await repo.getChecklistForEvent('event-1');
      final itemId = items.first.id;

      // Check, then uncheck.
      await repo.toggleItemChecked(itemId, true);
      await repo.toggleItemChecked(itemId, false);

      final result = await repo.getChecklistForEvent('event-1');
      expect(result.first.isChecked, isFalse);
      expect(result.first.checkedAt, isNull);
    });

    test('toggling one item does not affect other items', () async {
      final repo = _makeRepo(db);
      await repo.createChecklistItems(
        eventId: 'event-1',
        userId: 'user-1',
        gearItems: ['Shoes', 'Hat', 'Glasses'],
      );
      final items = await repo.getChecklistForEvent('event-1');

      await repo.toggleItemChecked(items[0].id, true);

      final result = await repo.getChecklistForEvent('event-1');
      expect(result[0].isChecked, isTrue);
      expect(result[1].isChecked, isFalse);
      expect(result[2].isChecked, isFalse);
    });

    test('toggle persists across separate getChecklistForEvent calls', () async {
      final repo = _makeRepo(db);
      await repo.createChecklistItems(
        eventId: 'event-1',
        userId: 'user-1',
        gearItems: ['Shoes'],
      );
      final itemId = (await repo.getChecklistForEvent('event-1')).first.id;

      await repo.toggleItemChecked(itemId, true);

      // Fresh read.
      final freshItems = await repo.getChecklistForEvent('event-1');
      expect(freshItems.first.isChecked, isTrue,
          reason: 'toggle must persist to database');
    });

    test('multiple toggles are idempotent — end state matches last call', () async {
      final repo = _makeRepo(db);
      await repo.createChecklistItems(
        eventId: 'event-1',
        userId: 'user-1',
        gearItems: ['Shoes'],
      );
      final itemId = (await repo.getChecklistForEvent('event-1')).first.id;

      await repo.toggleItemChecked(itemId, true);
      await repo.toggleItemChecked(itemId, true); // idempotent
      await repo.toggleItemChecked(itemId, false);
      await repo.toggleItemChecked(itemId, false); // idempotent

      final result = await repo.getChecklistForEvent('event-1');
      expect(result.first.isChecked, isFalse);
    });
  });

  // =========================================================================
  // addCustomItem
  // =========================================================================

  group('addCustomItem', () {
    test('custom item appears in checklist with isTemplateItem=false', () async {
      final repo = _makeRepo(db);
      await repo.createChecklistItems(
        eventId: 'event-1',
        userId: 'user-1',
        gearItems: ['Shoes'],
      );

      await repo.addCustomItem(
        eventId: 'event-1',
        userId: 'user-1',
        itemName: 'My Lucky Socks',
      );

      final items = await repo.getChecklistForEvent('event-1');
      final custom = items.firstWhere((i) => i.itemName == 'My Lucky Socks');
      expect(custom.isTemplateItem, isFalse);
      expect(custom.userId, equals('user-1'));
    });

    test('custom item gets sortOrder after last existing item', () async {
      final repo = _makeRepo(db);
      await repo.createChecklistItems(
        eventId: 'event-1',
        userId: 'user-1',
        gearItems: ['A', 'B', 'C'], // sortOrders 0, 1, 2
      );

      await repo.addCustomItem(
        eventId: 'event-1',
        userId: 'user-1',
        itemName: 'Custom',
      );

      final items = await repo.getChecklistForEvent('event-1');
      final custom = items.firstWhere((i) => i.itemName == 'Custom');
      expect(custom.sortOrder, equals(3));
    });

    test('adding to empty event assigns sortOrder 0', () async {
      final repo = _makeRepo(db);

      await repo.addCustomItem(
        eventId: 'empty-event',
        userId: 'user-1',
        itemName: 'First Item',
      );

      final items = await repo.getChecklistForEvent('empty-event');
      expect(items.length, equals(1));
      expect(items.first.sortOrder, equals(0));
    });

    test('multiple custom items get sequential sortOrders', () async {
      final repo = _makeRepo(db);

      await repo.addCustomItem(
        eventId: 'event-1',
        userId: 'user-1',
        itemName: 'Item 1',
      );
      await repo.addCustomItem(
        eventId: 'event-1',
        userId: 'user-1',
        itemName: 'Item 2',
      );

      final items = await repo.getChecklistForEvent('event-1');
      expect(items[0].sortOrder, equals(0));
      expect(items[1].sortOrder, equals(1));
    });

    test('custom item category defaults to "gear"', () async {
      final repo = _makeRepo(db);
      await repo.addCustomItem(
        eventId: 'event-1',
        userId: 'user-1',
        itemName: 'My Item',
      );
      final items = await repo.getChecklistForEvent('event-1');
      expect(items.first.category, equals('gear'));
    });
  });

  // =========================================================================
  // deleteItem
  // =========================================================================

  group('deleteItem', () {
    test('removes item from database', () async {
      final repo = _makeRepo(db);
      await repo.createChecklistItems(
        eventId: 'event-1',
        userId: 'user-1',
        gearItems: ['Shoes', 'Hat'],
      );
      final items = await repo.getChecklistForEvent('event-1');
      final idToDelete = items.first.id;

      await repo.deleteItem(idToDelete);

      final remaining = await repo.getChecklistForEvent('event-1');
      expect(remaining.length, equals(1));
      expect(remaining.any((i) => i.id == idToDelete), isFalse);
    });

    test('deleting unknown id is a no-op (does not throw)', () async {
      final repo = _makeRepo(db);
      await expectLater(repo.deleteItem('ghost-id'), completes);
    });
  });

  // =========================================================================
  // deleteChecklistForEvent
  // =========================================================================

  group('deleteChecklistForEvent', () {
    test('removes all items for event', () async {
      final repo = _makeRepo(db);
      await repo.createChecklistItems(
        eventId: 'event-1',
        userId: 'user-1',
        gearItems: ['A', 'B', 'C'],
      );

      await repo.deleteChecklistForEvent('event-1');

      final items = await repo.getChecklistForEvent('event-1');
      expect(items, isEmpty);
      expect(await repo.checklistExists('event-1'), isFalse);
    });

    test('only deletes items for specified event', () async {
      final repo = _makeRepo(db);
      await repo.createChecklistItems(
        eventId: 'event-1',
        userId: 'user-1',
        gearItems: ['A', 'B'],
      );
      await repo.createChecklistItems(
        eventId: 'event-2',
        userId: 'user-1',
        gearItems: ['C', 'D'],
      );

      await repo.deleteChecklistForEvent('event-1');

      expect(await repo.getChecklistForEvent('event-1'), isEmpty);
      expect(await repo.getChecklistForEvent('event-2'), hasLength(2));
    });
  });

  // =========================================================================
  // deleteNutritionItemsForEvent
  // =========================================================================

  group('deleteNutritionItemsForEvent', () {
    test('removes only nutrition items, preserving gear items', () async {
      final repo = _makeRepo(db);
      await repo.createChecklistItems(
        eventId: 'event-1',
        userId: 'user-1',
        gearItems: ['Shoes', 'Hat'],
        category: 'gear',
      );
      await repo.createChecklistItems(
        eventId: 'event-1',
        userId: 'user-1',
        gearItems: ['GU Gel', 'Sports Drink'],
        category: 'nutrition',
      );

      await repo.deleteNutritionItemsForEvent('event-1');

      final remaining = await repo.getChecklistForEvent('event-1');
      expect(remaining.length, equals(2));
      for (final item in remaining) {
        expect(item.category, equals('gear'));
      }
    });

    test('is a no-op when no nutrition items exist', () async {
      final repo = _makeRepo(db);
      await repo.createChecklistItems(
        eventId: 'event-1',
        userId: 'user-1',
        gearItems: ['Shoes'],
        category: 'gear',
      );

      await repo.deleteNutritionItemsForEvent('event-1');

      final items = await repo.getChecklistForEvent('event-1');
      expect(items.length, equals(1));
    });
  });

  // =========================================================================
  // Per-event isolation
  // =========================================================================

  group('per-event checklist isolation', () {
    test('checked state is isolated per event', () async {
      final repo = _makeRepo(db);
      await repo.createChecklistItems(
        eventId: 'event-A',
        userId: 'user-1',
        gearItems: ['Shoes'],
      );
      await repo.createChecklistItems(
        eventId: 'event-B',
        userId: 'user-1',
        gearItems: ['Shoes'],
      );

      final aItems = await repo.getChecklistForEvent('event-A');
      await repo.toggleItemChecked(aItems.first.id, true);

      final bItems = await repo.getChecklistForEvent('event-B');
      expect(bItems.first.isChecked, isFalse,
          reason: "Checking event-A's item must not affect event-B's item");
    });
  });

  // =========================================================================
  // GearTemplateService
  // =========================================================================

  group('GearTemplateService', () {
    final service = GearTemplateService();

    test('generateGearList for running returns non-empty list', () {
      final gear = service.generateGearList(
        eventType: ActivityType.running,
        userGender: 'male',
      );
      expect(gear, isNotEmpty);
      expect(gear, contains('Running shoes'));
    });

    test('female runner gets Sports bra in gear list', () {
      final gear = service.generateGearList(
        eventType: ActivityType.running,
        userGender: 'female',
      );
      expect(gear, contains('Sports bra'));
    });

    test('male runner does not get Sports bra', () {
      final gear = service.generateGearList(
        eventType: ActivityType.running,
        userGender: 'male',
      );
      expect(gear, isNot(contains('Sports bra')));
    });

    test('ultra run subtype includes Headlamp', () {
      final gear = service.generateGearList(
        eventType: ActivityType.running,
        userGender: 'male',
        eventSubtype: 'ultra_50k',
      );
      expect(gear, contains('Headlamp + extra batteries'));
    });

    test('5K run subtype does not include ultra items', () {
      final gear = service.generateGearList(
        eventType: ActivityType.running,
        userGender: 'male',
        eventSubtype: '5k',
      );
      expect(gear, isNot(contains('Headlamp + extra batteries')));
    });

    test('cycling returns bike-specific gear', () {
      final gear = service.generateGearList(
        eventType: ActivityType.cycling,
        userGender: 'male',
      );
      expect(gear, contains('Bike (race-ready)'));
      expect(gear, contains('Helmet'));
    });

    test('swimming returns swim-specific gear', () {
      final gear = service.generateGearList(
        eventType: ActivityType.swimming,
        userGender: 'male',
      );
      expect(gear, contains('Goggles (primary)'));
      expect(gear, contains('Swim cap'));
    });

    test('triathlon returns combined gear (swim + bike + run)', () {
      final gear = service.generateGearList(
        eventType: ActivityType.triathlon,
        userGender: 'male',
      );
      expect(gear, contains('Wetsuit (if applicable)'));
      expect(gear, contains('Helmet'));
      expect(gear, contains('Running shoes (with elastic laces)'));
    });

    test('ironman subtype adds special needs bags', () {
      final gear = service.generateGearList(
        eventType: ActivityType.triathlon,
        userGender: 'male',
        eventSubtype: 'ironman',
      );
      expect(gear, contains('Special needs bags (bike/run)'));
    });

    test('duathlon uses same gear list as triathlon', () {
      final duathlonGear = service.generateGearList(
        eventType: ActivityType.duathlon,
        userGender: 'male',
      );
      final triathlonGear = service.generateGearList(
        eventType: ActivityType.triathlon,
        userGender: 'male',
      );
      // Duathlon inherits triathlon gear template (transition-focused).
      expect(duathlonGear, equals(triathlonGear));
    });

    test('brick uses same gear list as triathlon', () {
      final brickGear = service.generateGearList(
        eventType: ActivityType.brick,
        userGender: 'male',
      );
      final triathlonGear = service.generateGearList(
        eventType: ActivityType.triathlon,
        userGender: 'male',
      );
      expect(brickGear, equals(triathlonGear));
    });

    test('null userGender returns list without gender-specific items', () {
      final gear = service.generateGearList(
        eventType: ActivityType.running,
        userGender: null,
      );
      expect(gear, isNot(contains('Sports bra')));
    });

    test('half_marathon includes band-aids but not ultra headlamp', () {
      final gear = service.generateGearList(
        eventType: ActivityType.running,
        userGender: 'male',
        eventSubtype: 'half_marathon',
      );
      expect(gear, contains('Band-aids/blister protection'));
      expect(gear, isNot(contains('Headlamp + extra batteries')));
    });
  });

  // =========================================================================
  // ChecklistProgress helper (pure logic, no DB)
  // =========================================================================

  group('ChecklistProgress computation', () {
    test('0/0 → progress=0.0, isComplete=false', () {
      const progress = ChecklistProgressHelper(total: 0, checked: 0);
      expect(progress.ratio, equals(0.0));
      expect(progress.isComplete, isFalse);
    });

    test('2/4 → progress=0.5', () {
      const progress = ChecklistProgressHelper(total: 4, checked: 2);
      expect(progress.ratio, equals(0.5));
      expect(progress.isComplete, isFalse);
    });

    test('4/4 → progress=1.0, isComplete=true', () {
      const progress = ChecklistProgressHelper(total: 4, checked: 4);
      expect(progress.ratio, equals(1.0));
      expect(progress.isComplete, isTrue);
    });
  });
}

// ---------------------------------------------------------------------------
// Inline pure helper for progress math (mirrors controller logic in isolation)
// ---------------------------------------------------------------------------

class ChecklistProgressHelper {
  const ChecklistProgressHelper({required this.total, required this.checked});
  final int total;
  final int checked;

  double get ratio => total > 0 ? checked / total : 0.0;
  bool get isComplete => total > 0 && checked == total;
}
