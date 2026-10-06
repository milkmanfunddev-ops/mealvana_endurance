import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/report/report.dart';
import '../domain/checklist_item.dart' as domain;

part 'checklist_repository.g.dart';

@riverpod
ChecklistRepository checklistRepository(Ref ref) {
  return ChecklistRepository(
    ref.read(appDatabaseProvider),
    ref.read(reportProvider),
  );
}

/// Repository for race day checklist CRUD operations
class ChecklistRepository {
  final AppDatabase _database;
  final Report _report;

  ChecklistRepository(this._database, this._report);

  /// Get all checklist items for an event
  Future<List<domain.ChecklistItem>> getChecklistForEvent(
    String eventId,
  ) async {
    try {
      final query = _database.select(_database.raceChecklistItemsTable)
        ..where((tbl) => tbl.eventId.equals(eventId))
        ..orderBy([(tbl) => OrderingTerm.asc(tbl.sortOrder)]);

      final items = await query.get();
      return items.map(_mapToDomain).toList();
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'race_checklist',
        message: 'Error getting checklist for event: $eventId',
      );
      rethrow;
    }
  }

  /// Check if a checklist exists for an event
  Future<bool> checklistExists(String eventId) async {
    try {
      final query = _database.select(_database.raceChecklistItemsTable)
        ..where((tbl) => tbl.eventId.equals(eventId))
        ..limit(1);

      final items = await query.get();
      return items.isNotEmpty;
    } catch (e) {
      _report.fault(
        e,
        area: 'race_checklist',
        message: 'Error checking if checklist exists',
      );
      return false;
    }
  }

  /// Create initial checklist items for an event
  Future<void> createChecklistItems({
    required String eventId,
    required String userId,
    required List<String> gearItems,
    String category = 'gear',
  }) async {
    try {
      final entries = gearItems.asMap().entries.map((entry) {
        return RaceChecklistItemsTableCompanion.insert(
          eventId: eventId,
          userId: userId,
          category: category,
          itemName: entry.value,
          sortOrder: Value(entry.key),
          isChecked: const Value(false),
          isTemplateItem: const Value(true),
        );
      }).toList();

      await _database.batch((batch) {
        batch.insertAll(_database.raceChecklistItemsTable, entries);
      });

      _report.info(
        'Created ${entries.length} checklist items for event $eventId',
        area: 'race_checklist',
      );
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'race_checklist',
        message: 'Error creating checklist items',
      );
      rethrow;
    }
  }

  /// Toggle checked state of a checklist item
  Future<void> toggleItemChecked(String itemId, bool isChecked) async {
    try {
      await (_database.update(
        _database.raceChecklistItemsTable,
      )..where((tbl) => tbl.id.equals(itemId))).write(
        RaceChecklistItemsTableCompanion(
          isChecked: Value(isChecked),
          checkedAt: Value(isChecked ? DateTime.now() : null),
          updatedAt: Value(DateTime.now()),
        ),
      );

      _report.debug(
        'Toggled item $itemId to ${isChecked ? "checked" : "unchecked"}',
        area: 'race_checklist',
      );
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'race_checklist',
        message: 'Error toggling checklist item',
      );
      rethrow;
    }
  }

  /// Add a custom checklist item
  Future<void> addCustomItem({
    required String eventId,
    required String userId,
    required String itemName,
    String category = 'gear',
  }) async {
    try {
      // Get the max sort order for the event
      final maxSortQuery = _database.raceChecklistItemsTable.sortOrder.max();
      final query = _database.selectOnly(_database.raceChecklistItemsTable)
        ..addColumns([maxSortQuery])
        ..where(_database.raceChecklistItemsTable.eventId.equals(eventId));

      final result = await query.getSingleOrNull();
      final maxSort = result?.read(maxSortQuery) ?? -1;

      await _database
          .into(_database.raceChecklistItemsTable)
          .insert(
            RaceChecklistItemsTableCompanion.insert(
              eventId: eventId,
              userId: userId,
              category: category,
              itemName: itemName,
              sortOrder: Value(maxSort + 1),
              isTemplateItem: const Value(false),
            ),
          );

      _report.info(
        'Added custom item "$itemName" to event $eventId',
        area: 'race_checklist',
      );
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'race_checklist',
        message: 'Error adding custom checklist item',
      );
      rethrow;
    }
  }

  /// Delete a checklist item
  Future<void> deleteItem(String itemId) async {
    try {
      await (_database.delete(
        _database.raceChecklistItemsTable,
      )..where((tbl) => tbl.id.equals(itemId))).go();

      _report.info('Deleted checklist item $itemId', area: 'race_checklist');
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'race_checklist',
        message: 'Error deleting checklist item',
      );
      rethrow;
    }
  }

  /// Delete all checklist items for an event (useful for regenerating)
  Future<void> deleteChecklistForEvent(String eventId) async {
    try {
      await (_database.delete(
        _database.raceChecklistItemsTable,
      )..where((tbl) => tbl.eventId.equals(eventId))).go();

      _report.info(
        'Deleted all checklist items for event $eventId',
        area: 'race_checklist',
      );
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'race_checklist',
        message: 'Error deleting checklist for event',
      );
      rethrow;
    }
  }

  /// Delete only nutrition items for an event (used when syncing with nutrition plan)
  Future<void> deleteNutritionItemsForEvent(String eventId) async {
    try {
      await (_database.delete(_database.raceChecklistItemsTable)..where(
            (tbl) =>
                tbl.eventId.equals(eventId) & tbl.category.equals('nutrition'),
          ))
          .go();

      _report.debug(
        'Deleted nutrition items for event $eventId',
        area: 'race_checklist',
      );
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'race_checklist',
        message: 'Error deleting nutrition items',
      );
      rethrow;
    }
  }

  /// Map Drift table entry to domain model
  domain.ChecklistItem _mapToDomain(ChecklistItem item) {
    return domain.ChecklistItem(
      id: item.id,
      eventId: item.eventId,
      userId: item.userId,
      category: item.category,
      itemName: item.itemName,
      sortOrder: item.sortOrder,
      isChecked: item.isChecked,
      checkedAt: item.checkedAt,
      notes: item.notes,
      isTemplateItem: item.isTemplateItem,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }
}
