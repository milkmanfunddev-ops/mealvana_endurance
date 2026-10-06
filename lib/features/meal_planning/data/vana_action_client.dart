import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/services/app_external_deps.dart';
import '../domain/home_payload.dart';
import '../domain/meal_detail.dart';
import '../domain/meal_plan.dart';
import '../domain/meal_ref.dart';
import '../domain/ui_action.dart';
import '../domain/user_memory.dart';
import '../domain/vana_part.dart';
import '../domain/wire_record.dart';
import 'vana_chat_repository.dart';
import 'vana_transport.dart';
import '../../../shared/domain/decode_issue.dart';
import '../../../shared/services/report/decode_issue_report.dart';
import '../../../shared/services/report/report.dart';

part 'vana_action_client.g.dart';

@riverpod
VanaActionClient vanaActionClient(Ref ref) {
  return VanaActionClient(
    transport: ref.watch(vanaTransportProvider),
    report: ref.watch(appExternalDepsProvider).report,
  );
}

/// `POST vana-action` result: `{parts: VanaPart[], ...extras}` (contract 02
/// §4). Typed accessors read the extras the app-only actions add.
class VanaActionResult {
  const VanaActionResult({
    required this.parts,
    required this.extras,
    this.onIssue = ignoreDecodeIssue,
  });

  final List<VanaPart> parts;

  /// Where the typed accessors below report a malformed extra (the client
  /// passes `report.decodeIssue`); ignored by default.
  final DecodeIssue onIssue;

  /// Everything except `parts`, as sent (`home`, `meal`, `meals`,
  /// `memories`, `plans`, `notes`, `vote`, `logId`).
  final Map<String, dynamic> extras;

  /// The last `batch` part's plan — every plan-editing action returns one.
  MealPlan? get plan {
    MealPlan? out;
    for (final part in parts) {
      if (part is VanaBatchPart) out = part.plan;
    }
    return out;
  }

  /// `get_home` → `home`.
  HomePayload? get home => switch (asJsonMap(extras['home'])) {
    final map? => HomePayload.fromJson(map, onIssue: onIssue),
    null => null,
  };

  /// `get_meal` → `meal` (a [MealDetail]).
  MealDetail? get mealDetail => switch (asJsonMap(extras['meal'])) {
    final map? => MealDetail.fromJson(map, onIssue: onIssue),
    null => null,
  };

  /// `save_meal` → `meal` (a [MealRef]).
  MealRef? get savedMealRef => switch (asJsonMap(extras['meal'])) {
    final map? => MealRef.fromJson(map),
    null => null,
  };

  /// `recent_meals` → `meals`.
  List<RecentMeal> get recentMeals =>
      readRecordList(extras, 'meals', RecentMeal.fromJson, onIssue: onIssue);

  /// `list_memories` / `delete_memory` → `memories`.
  List<UserMemory> get memories =>
      readRecordList(extras, 'memories', UserMemory.fromJson, onIssue: onIssue);

  /// `set_meal_feedback` → `vote`.
  int? get vote => readInt(extras, 'vote');

  /// `set_saved_meal_notes` → `notes`.
  String? get notes => readString(extras, 'notes');

  /// `log_from_plan` → `logId`.
  String? get logId => readString(extras, 'logId');

  /// `rewind` → `removed` (how many `vana_messages` rows were deleted).
  int? get removed => readInt(extras, 'removed');

  /// `pantry_photo` → `messageId` (the persisted assistant message that
  /// carries the returned `pantry` part).
  String? get messageId => readString(extras, 'messageId');

  factory VanaActionResult.fromJson(
    Map<String, dynamic> json, {
    DecodeIssue onIssue = ignoreDecodeIssue,
  }) => VanaActionResult(
    parts: VanaPart.listFromJson(json['parts'], onIssue: onIssue),
    onIssue: onIssue,
    extras: {
      for (final entry in json.entries)
        if (entry.key != 'parts') entry.key: entry.value,
    },
  );
}

/// Model-free edits and reads against the `vana-action` edge function.
///
/// Every call is a remote-ack write/read: nothing is written locally here.
/// Repositories/controllers fold the returned `batch` part into Drift via
/// `MealPlanRepository.applyServerPlan`. Errors: `vana_exceptions.dart`
/// (401/403 `pro_required`/429/offline/other).
class VanaActionClient {
  VanaActionClient({
    required VanaTransport transport,
    required Report report,
    this.functionName = 'vana-action',
  }) : _transport = transport,
       _report = report;

  final VanaTransport _transport;
  final Report _report;
  final String functionName;

  Future<VanaActionResult> run(UiAction action) async {
    final started = DateTime.now();
    final json = await _transport.postJson(functionName, action.toJson());
    final result = VanaActionResult.fromJson(
      json,
      onIssue: _report.decodeIssue('meal_planning'),
    );
    _report.info(
      'action ${action.type} → ${result.parts.map((p) => p.kind).join(',')}',
      area: 'meal_planning',
      data: {
        'ms': DateTime.now().difference(started).inMilliseconds,
        'extras': result.extras.keys.toList(),
      },
    );
    return result;
  }
}
