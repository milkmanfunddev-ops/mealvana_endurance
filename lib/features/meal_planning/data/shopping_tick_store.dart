import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/services/prefs_provider.dart';
import '../domain/ui_action.dart';

part 'shopping_tick_store.g.dart';

/// One `checked` / `have` flip the athlete made that the server has not yet
/// acknowledged (testing-wave ticket 36, Findings 20-001 / 20-002).
///
/// Written locally before the `update_shopping_item` call goes out and
/// dropped once the server answers; while it sits here it is the upload
/// state of that tick. [rowId] is the `shopping_items.id` when the tick was
/// made on the live list; the offline copy (`meal_plans.shopping`, no ids)
/// leaves it null and the tick is matched by [name] on the plan's list
/// ([planId]) once one loads.
class PendingShoppingTick {
  const PendingShoppingTick({
    required this.name,
    required this.field,
    required this.value,
    required this.at,
    this.listId,
    this.planId,
    this.rowId,
  });

  final String name;
  final ShoppingField field;
  final bool value;
  final DateTime at;
  final String? listId;
  final String? planId;
  final String? rowId;

  /// Same list-or-plan, same line, same flag: the later tick replaces the
  /// earlier one.
  String get key =>
      '${listId ?? 'plan:$planId'}|${name.trim().toLowerCase()}|${field.wire}';

  /// True when this tick belongs to the list on screen: by list id on a
  /// live list; by plan on the offline copy (no list id), so a tick made on
  /// the plan's live list shows on its offline copy too (110-002), and a
  /// tick made on the offline copy is matched to the plan's live list by
  /// name once it loads (110-001).
  bool appliesTo({required String? listId, required String? planId}) {
    if (this.listId != null && listId != null) return this.listId == listId;
    return this.planId != null && this.planId == planId;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'field': field.wire,
    'value': value,
    'at': at.toUtc().toIso8601String(),
    if (listId != null) 'listId': listId,
    if (planId != null) 'planId': planId,
    if (rowId != null) 'rowId': rowId,
  };

  static PendingShoppingTick? fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final field = json['field'];
    final value = json['value'];
    final at = json['at'];
    if (name is! String || field is! String || value is! bool) return null;
    return PendingShoppingTick(
      name: name,
      field: field == ShoppingField.have.wire
          ? ShoppingField.have
          : ShoppingField.checked,
      value: value,
      at: at is String ? DateTime.tryParse(at) ?? DateTime.now() : DateTime.now(),
      listId: json['listId'] as String?,
      planId: json['planId'] as String?,
      rowId: json['rowId'] as String?,
    );
  }
}

/// The device's queue of unacknowledged shopping ticks, one JSON value per
/// user. Small (a handful of lines), read and written whole; a value that
/// fails to decode reads as empty.
class ShoppingTickStore {
  const ShoppingTickStore(this._prefs);

  final SharedPreferences _prefs;

  static String _key(String userId) => 'shopping.pending_ticks.$userId';

  List<PendingShoppingTick> read(String userId) {
    final raw = _prefs.getString(_key(userId));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final entry in decoded)
          if (entry is Map<String, dynamic>)
            if (PendingShoppingTick.fromJson(entry) case final tick?) tick,
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> write(String userId, List<PendingShoppingTick> ticks) async {
    if (ticks.isEmpty) {
      await _prefs.remove(_key(userId));
      return;
    }
    await _prefs.setString(
      _key(userId),
      jsonEncode([for (final t in ticks) t.toJson()]),
    );
  }

  /// Add [tick], replacing an earlier tick of the same line and flag.
  Future<List<PendingShoppingTick>> add(
    String userId,
    PendingShoppingTick tick,
  ) async {
    final next = [
      for (final t in read(userId))
        if (t.key != tick.key) t,
      tick,
    ];
    await write(userId, next);
    return next;
  }

  Future<List<PendingShoppingTick>> remove(
    String userId,
    PendingShoppingTick tick,
  ) async {
    final next = [
      for (final t in read(userId))
        if (t.key != tick.key) t,
    ];
    await write(userId, next);
    return next;
  }
}

@Riverpod(keepAlive: true)
ShoppingTickStore shoppingTickStore(Ref ref) =>
    ShoppingTickStore(ref.watch(sharedPreferencesProvider));
