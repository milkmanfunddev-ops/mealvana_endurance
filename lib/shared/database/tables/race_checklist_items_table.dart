import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Table for race day checklist items
/// Stores gear and preparation items for each event with checked state
@DataClassName('ChecklistItem')
class RaceChecklistItemsTable extends Table {
  /// UUID primary key
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();

  /// Foreign key to events table
  TextColumn get eventId => text().named('event_id')();

  /// Foreign key to users table
  TextColumn get userId => text().named('user_id')();

  /// Item category - currently only 'gear', but can expand to 'nutrition', 'logistics', etc.
  TextColumn get category => text()();

  /// Display name of the checklist item
  TextColumn get itemName => text().named('item_name')();

  /// Sort order for display (lower numbers first)
  IntColumn get sortOrder =>
      integer().withDefault(const Constant(0)).named('sort_order')();

  /// Whether the item has been checked off
  BoolColumn get isChecked =>
      boolean().withDefault(const Constant(false)).named('is_checked')();

  /// When the item was checked (nullable - only set when checked)
  DateTimeColumn get checkedAt => dateTime().nullable().named('checked_at')();

  /// Optional notes for the item (e.g., "Packed in blue bag", "Need to buy")
  TextColumn get notes => text().nullable()();

  /// Whether this is a default template item (true) or user-added custom item (false)
  BoolColumn get isTemplateItem =>
      boolean().withDefault(const Constant(true)).named('is_template_item')();

  /// Metadata
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime).named('created_at')();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime).named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'race_checklist_items';

  @override
  List<String> get customConstraints => [
    // Valid categories (can be extended in future)
    "CHECK (category IN ('gear', 'nutrition', 'logistics', 'pre_race', 'race_morning'))",
  ];
}
