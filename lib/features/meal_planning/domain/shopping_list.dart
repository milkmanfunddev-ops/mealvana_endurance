import 'shopping_item.dart';
import 'wire_record.dart';

/// Where a shopping line came from — `shopping_items.source`.
enum ShoppingItemSource {
  plan('plan'),
  manual('manual');

  const ShoppingItemSource(this.wire);

  final String wire;

  static ShoppingItemSource fromWire(String? raw) =>
      raw == 'plan' ? ShoppingItemSource.plan : ShoppingItemSource.manual;
}

/// One `shopping_items` row — `ShoppingListItem` in `contracts.ts`: a
/// [ShoppingItem] with an id, its list, its origin and whether a hand edited
/// it (an edited or manual line survives a re-plan).
class ShoppingListItem extends ShoppingItem {
  const ShoppingListItem({
    required this.id,
    required this.listId,
    required super.aisle,
    required super.name,
    required super.qty,
    super.checked,
    super.have,
    super.fromMealIds,
    this.source = ShoppingItemSource.manual,
    this.edited = false,
    this.position = 0,
  });

  final String id;
  final String listId;
  final ShoppingItemSource source;
  final bool edited;
  final int position;

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) =>
      ShoppingListItem(
        id: requireString(json, 'id'),
        listId: requireString(json, 'listId'),
        aisle: readString(json, 'aisle') ?? '',
        name: requireString(json, 'name'),
        qty: readString(json, 'qty') ?? '',
        checked: readBool(json, 'checked') ?? false,
        have: readBool(json, 'have') ?? false,
        fromMealIds: readStringList(json, 'fromMealIds'),
        source: ShoppingItemSource.fromWire(readString(json, 'source')),
        edited: readBool(json, 'edited') ?? false,
        position: readInt(json, 'position') ?? 0,
      );

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'id': id,
    'listId': listId,
    'source': source.wire,
    'edited': edited,
    'position': position,
  };

  @override
  ShoppingListItem copyWith({
    String? aisle,
    String? name,
    String? qty,
    bool? checked,
    bool? have,
    List<String>? fromMealIds,
    bool? edited,
  }) => ShoppingListItem(
    id: id,
    listId: listId,
    aisle: aisle ?? this.aisle,
    name: name ?? this.name,
    qty: qty ?? this.qty,
    checked: checked ?? this.checked,
    have: have ?? this.have,
    fromMealIds: fromMealIds ?? this.fromMealIds,
    source: source,
    edited: edited ?? this.edited,
    position: position,
  );
}

/// A list without its rows — `ShoppingListSummary` in `contracts.ts`.
class ShoppingListSummary extends WireRecord {
  const ShoppingListSummary({
    required this.id,
    required this.planId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.confirmedAt,
    required this.itemCount,
  });

  final String id;

  /// The plan whose meals build this list; null for a hand-made list.
  final String? planId;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? confirmedAt;

  /// Lines not marked `have`.
  final int itemCount;

  /// What "most recent" sorts by: confirmation, else creation.
  DateTime get sortDate => confirmedAt ?? createdAt;

  factory ShoppingListSummary.fromJson(Map<String, dynamic> json) =>
      ShoppingListSummary(
        id: requireString(json, 'id'),
        planId: readString(json, 'planId'),
        name: readString(json, 'name') ?? '',
        createdAt: DateTime.parse(requireString(json, 'createdAt')),
        updatedAt: DateTime.parse(
          readString(json, 'updatedAt') ?? requireString(json, 'createdAt'),
        ),
        confirmedAt: switch (readString(json, 'confirmedAt')) {
          final s? => DateTime.parse(s),
          null => null,
        },
        itemCount: readInt(json, 'itemCount') ?? 0,
      );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'planId': planId,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'confirmedAt': confirmedAt?.toIso8601String(),
    'itemCount': itemCount,
  };
}

/// A list with its rows — `ShoppingListDetail` in `contracts.ts`.
class ShoppingListDetail extends ShoppingListSummary {
  const ShoppingListDetail({
    required super.id,
    required super.planId,
    required super.name,
    required super.createdAt,
    required super.updatedAt,
    required super.confirmedAt,
    required super.itemCount,
    required this.items,
  });

  final List<ShoppingListItem> items;

  factory ShoppingListDetail.fromJson(Map<String, dynamic> json) {
    final summary = ShoppingListSummary.fromJson(json);
    return ShoppingListDetail(
      id: summary.id,
      planId: summary.planId,
      name: summary.name,
      createdAt: summary.createdAt,
      updatedAt: summary.updatedAt,
      confirmedAt: summary.confirmedAt,
      itemCount: summary.itemCount,
      items: readRecordList(json, 'items', ShoppingListItem.fromJson),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'items': items.map((i) => i.toJson()).toList(),
  };
}
