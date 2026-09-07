import 'wire_record.dart';

/// One shopping-list line — `ShoppingItem` in `contracts.ts`.
class ShoppingItem extends WireRecord {
  const ShoppingItem({
    required this.aisle,
    required this.name,
    required this.qty,
    this.checked = false,
    this.have = false,
    this.fromMealIds = const [],
  });

  final String aisle;
  final String name;
  final String qty;

  /// Ticked off while shopping.
  final bool checked;

  /// Already in the cupboard — excluded from `itemCount`, listed in `skipped`.
  final bool have;

  /// `plan_meals.id`s this line was built from.
  final List<String> fromMealIds;

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
    aisle: readString(json, 'aisle') ?? '',
    name: requireString(json, 'name'),
    qty: readString(json, 'qty') ?? '',
    checked: readBool(json, 'checked') ?? false,
    have: readBool(json, 'have') ?? false,
    fromMealIds: readStringList(json, 'fromMealIds'),
  );

  @override
  Map<String, dynamic> toJson() => {
    'aisle': aisle,
    'name': name,
    'qty': qty,
    'checked': checked,
    'have': have,
    'fromMealIds': fromMealIds,
  };

  ShoppingItem copyWith({
    String? aisle,
    String? name,
    String? qty,
    bool? checked,
    bool? have,
    List<String>? fromMealIds,
  }) => ShoppingItem(
    aisle: aisle ?? this.aisle,
    name: name ?? this.name,
    qty: qty ?? this.qty,
    checked: checked ?? this.checked,
    have: have ?? this.have,
    fromMealIds: fromMealIds ?? this.fromMealIds,
  );
}
