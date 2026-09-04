import 'cooking_session.dart';
import 'meal_source.dart';
import 'meal_type.dart';
import 'plan_meal.dart';
import 'plan_rule.dart';
import 'vana_setting.dart';

/// Model-free edits — `POST vana-action { type, payload }` (contract 02 §4).
///
/// Payload keys are the camelCase names the prototype's `actions.ts` reads.
/// Scope rule (server): payload `planId` → that plan; else `conversationId`
/// → that conversation's draft; else the week-level active plan. Both are
/// optional on every action and emitted only when set.
sealed class UiAction {
  const UiAction({this.planId, this.conversationId});

  final String? planId;
  final String? conversationId;

  /// The `type` discriminator.
  String get type;

  /// Action-specific payload fields (without scope).
  Map<String, Object?> payloadFields();

  /// Full payload: action fields + scope keys.
  Map<String, Object?> toPayloadJson() => {
    if (planId != null) 'planId': planId,
    if (conversationId != null) 'conversationId': conversationId,
    ...payloadFields(),
  };

  /// The request body.
  Map<String, Object?> toJson() => {'type': type, 'payload': toPayloadJson()};
}

/// A `{source, id}` pair identifying a library or saved meal.
class MealPick {
  const MealPick({required this.source, required this.id});

  final MealSource source;
  final String id;

  Map<String, Object?> toJson() => {'source': source.wire, 'id': id};
}

/// Add one or more meals to the plan (`{meals[{source,id}], servings?,
/// session?}`). Remote-ack.
class PickMealsAction extends UiAction {
  const PickMealsAction({
    required this.meals,
    this.servings,
    this.session,
    this.sendSession = false,
    super.planId,
    super.conversationId,
  });

  final List<MealPick> meals;
  final int? servings;

  /// When [sendSession] is true the key is emitted even if null (the server
  /// treats an absent key as "use the default session", `null` as "none").
  final CookingSession? session;
  final bool sendSession;

  @override
  String get type => 'pick_meals';

  @override
  Map<String, Object?> payloadFields() => {
    'meals': meals.map((m) => m.toJson()).toList(),
    if (servings != null) 'servings': servings,
    if (sendSession || session != null) 'session': session?.wire,
  };
}

/// Remove a meal by its source reference (`{source, id}`).
class UnpickMealAction extends UiAction {
  const UnpickMealAction({
    required this.source,
    required this.id,
    super.planId,
    super.conversationId,
  });

  final MealSource source;
  final String id;

  @override
  String get type => 'unpick_meal';

  @override
  Map<String, Object?> payloadFields() => {'source': source.wire, 'id': id};
}

/// Replace a plan meal with another meal (`{planMealId, source, id}`).
class SwapMealAction extends UiAction {
  const SwapMealAction({
    required this.planMealId,
    required this.source,
    required this.id,
    super.planId,
    super.conversationId,
  });

  final String planMealId;
  final MealSource source;
  final String id;

  @override
  String get type => 'swap_meal';

  @override
  Map<String, Object?> payloadFields() => {
    'planMealId': planMealId,
    'source': source.wire,
    'id': id,
  };
}

/// `{planMealId}` — server sets servings to 0 (deletes the row).
class RemoveMealAction extends UiAction {
  const RemoveMealAction({
    required this.planMealId,
    super.planId,
    super.conversationId,
  });

  final String planMealId;

  @override
  String get type => 'remove_meal';

  @override
  Map<String, Object?> payloadFields() => {'planMealId': planMealId};
}

/// `{planMealId, servings}`.
class SetServingsAction extends UiAction {
  const SetServingsAction({
    required this.planMealId,
    required this.servings,
    super.planId,
    super.conversationId,
  });

  final String planMealId;
  final int servings;

  @override
  String get type => 'set_servings';

  @override
  Map<String, Object?> payloadFields() => {
    'planMealId': planMealId,
    'servings': servings,
  };
}

/// `{planMealId, session}` — `session: null` clears it.
class SetSessionAction extends UiAction {
  const SetSessionAction({
    required this.planMealId,
    this.session,
    super.planId,
    super.conversationId,
  });

  final String planMealId;
  final CookingSession? session;

  @override
  String get type => 'set_session';

  @override
  Map<String, Object?> payloadFields() => {
    'planMealId': planMealId,
    'session': session?.wire,
  };
}

/// `{planMealId, from, to, effect?}`.
class ApplySwapAction extends UiAction {
  const ApplySwapAction({
    required this.planMealId,
    required this.swap,
    super.planId,
    super.conversationId,
  });

  final String planMealId;
  final SwapApplied swap;

  @override
  String get type => 'apply_swap';

  @override
  Map<String, Object?> payloadFields() => {
    'planMealId': planMealId,
    ...swap.toJson(),
  };
}

/// `{planMealId, role, text}`.
class AddCommentAction extends UiAction {
  const AddCommentAction({
    required this.planMealId,
    this.role = PlanCommentRole.user,
    required this.text,
    super.planId,
    super.conversationId,
  });

  final String planMealId;
  final PlanCommentRole role;
  final String text;

  @override
  String get type => 'add_comment';

  @override
  Map<String, Object?> payloadFields() => {
    'planMealId': planMealId,
    'role': role.wire,
    'text': text,
  };
}

/// `{day, rule, mealId?, accepted}` — `actions.ts` reads `accepted`
/// (defaults false), so it is always sent.
class AcceptRuleAction extends UiAction {
  const AcceptRuleAction({
    required this.rule,
    super.planId,
    super.conversationId,
  });

  final PlanRule rule;

  @override
  String get type => 'accept_rule';

  @override
  Map<String, Object?> payloadFields() => rule.toJson();
}

/// `{date?}` — confirm the draft; the server returns the shopping list.
/// Remote-ack.
class ConfirmPlanAction extends UiAction {
  const ConfirmPlanAction({this.date, super.planId, super.conversationId});

  /// `YYYY-MM-DD` used to refresh day notes; server defaults to today.
  final String? date;

  @override
  String get type => 'confirm_plan';

  @override
  Map<String, Object?> payloadFields() => {if (date != null) 'date': date};
}

/// Which shopping flag a [ToggleShoppingAction] flips.
enum ShoppingField {
  checked('checked'),
  have('have');

  const ShoppingField(this.wire);

  final String wire;
}

/// `{name, field, value}` — keyed by item name (the server's shape).
class ToggleShoppingAction extends UiAction {
  const ToggleShoppingAction({
    required this.name,
    required this.field,
    required this.value,
    super.planId,
    super.conversationId,
  });

  final String name;
  final ShoppingField field;
  final bool value;

  @override
  String get type => 'toggle_shopping';

  @override
  Map<String, Object?> payloadFields() => {
    'name': name,
    'field': field.wire,
    'value': value,
  };
}

/// `{planMealId, mealType?}` — log one serving; decrements `servingsLeft`.
class LogFromPlanAction extends UiAction {
  const LogFromPlanAction({
    required this.planMealId,
    this.mealType,
    super.planId,
    super.conversationId,
  });

  final String planMealId;
  final MealType? mealType;

  @override
  String get type => 'log_from_plan';

  @override
  Map<String, Object?> payloadFields() => {
    'planMealId': planMealId,
    if (mealType != null) 'mealType': mealType!.wire,
  };
}

/// `{key, value}` — boolean settings stored as `user_memories` rows.
class SetSettingAction extends UiAction {
  const SetSettingAction({
    required this.key,
    required this.value,
    super.planId,
    super.conversationId,
  });

  final VanaSetting key;
  final bool value;

  @override
  String get type => 'set_setting';

  @override
  Map<String, Object?> payloadFields() => {'key': key.wire, 'value': value};
}

/// `{id}`.
class DeleteMemoryAction extends UiAction {
  const DeleteMemoryAction({required this.id});

  final String id;

  @override
  String get type => 'delete_memory';

  @override
  Map<String, Object?> payloadFields() => {'id': id};
}

/// `{}` → `{parts: [], memories: Memory[]}`.
class ListMemoriesAction extends UiAction {
  const ListMemoriesAction();

  @override
  String get type => 'list_memories';

  @override
  Map<String, Object?> payloadFields() => const {};
}

/// `{date?, slot, source, id, name?}`.
class SetDaySlotAction extends UiAction {
  const SetDaySlotAction({
    this.date,
    required this.slot,
    required this.source,
    required this.id,
    this.name,
    super.planId,
    super.conversationId,
  });

  final String? date;
  final MealType slot;
  final DaySlotSource source;
  final String id;
  final String? name;

  @override
  String get type => 'set_day_slot';

  @override
  Map<String, Object?> payloadFields() => {
    if (date != null) 'date': date,
    'slot': slot.wire,
    'source': source.wire,
    'id': id,
    if (name != null) 'name': name,
  };
}

/// `{date?, slot}`.
class ClearDaySlotAction extends UiAction {
  const ClearDaySlotAction({
    this.date,
    required this.slot,
    super.planId,
    super.conversationId,
  });

  final String? date;
  final MealType slot;

  @override
  String get type => 'clear_day_slot';

  @override
  Map<String, Object?> payloadFields() => {
    if (date != null) 'date': date,
    'slot': slot.wire,
  };
}

/// `{date?}` → a `day` part. Remote-ack.
class PlanDayAction extends UiAction {
  const PlanDayAction({this.date, super.planId, super.conversationId});

  final String? date;

  @override
  String get type => 'plan_day';

  @override
  Map<String, Object?> payloadFields() => {if (date != null) 'date': date};
}

/// `{}` — start a fresh draft. Declared in `contracts.ts`; the prototype
/// server has no handler for it yet (edge fn must add one).
class NewPlanAction extends UiAction {
  const NewPlanAction({super.conversationId});

  @override
  String get type => 'new_plan';

  @override
  Map<String, Object?> payloadFields() => const {};
}

/// `{id?}` — a specific plan, else the scoped/active one.
class GetPlanAction extends UiAction {
  const GetPlanAction({this.id, super.planId, super.conversationId});

  final String? id;

  @override
  String get type => 'get_plan';

  @override
  Map<String, Object?> payloadFields() => {if (id != null) 'id': id};
}

/// `{}` → `{parts: [], plans: [...]}`.
class ListPlansAction extends UiAction {
  const ListPlansAction();

  @override
  String get type => 'list_plans';

  @override
  Map<String, Object?> payloadFields() => const {};
}

// ── App-only actions (the Flutter client's read/write channel) ──────────────

/// `{libraryMealId}` → `{meal: MealRef}` — the heart on the detail page.
class SaveMealAction extends UiAction {
  const SaveMealAction({required this.libraryMealId});

  final String libraryMealId;

  @override
  String get type => 'save_meal';

  @override
  Map<String, Object?> payloadFields() => {'libraryMealId': libraryMealId};
}

/// `{date?}` → `{parts: [batch?], home: HomePayload}`.
class GetHomeAction extends UiAction {
  const GetHomeAction({this.date});

  final String? date;

  @override
  String get type => 'get_home';

  @override
  Map<String, Object?> payloadFields() => {if (date != null) 'date': date};
}

/// `{id}` → `{meal: MealDetail}` (library id or saved uuid).
class GetMealAction extends UiAction {
  const GetMealAction({required this.id});

  final String id;

  @override
  String get type => 'get_meal';

  @override
  Map<String, Object?> payloadFields() => {'id': id};
}

/// `{limit?}` → `{meals: RecentMeal[]}` (server caps at 200).
class RecentMealsAction extends UiAction {
  const RecentMealsAction({this.limit});

  final int? limit;

  @override
  String get type => 'recent_meals';

  @override
  Map<String, Object?> payloadFields() => {if (limit != null) 'limit': limit};
}

/// `{savedMealId, notes}` → `{notes}`.
class SetSavedMealNotesAction extends UiAction {
  const SetSavedMealNotesAction({
    required this.savedMealId,
    required this.notes,
  });

  final String savedMealId;
  final String notes;

  @override
  String get type => 'set_saved_meal_notes';

  @override
  Map<String, Object?> payloadFields() => {
    'savedMealId': savedMealId,
    'notes': notes,
  };
}

/// `{libraryMealId? | savedMealId?, vote, reason?}` → `{vote}`.
/// Exactly one of [libraryMealId] / [savedMealId] should be set.
class SetMealFeedbackAction extends UiAction {
  const SetMealFeedbackAction({
    this.libraryMealId,
    this.savedMealId,
    required this.vote,
    this.reason,
  }) : assert(
         (libraryMealId == null) != (savedMealId == null),
         'Provide exactly one of libraryMealId / savedMealId',
       ),
       assert(vote >= -1 && vote <= 1, 'vote must be -1, 0 or 1');

  final String? libraryMealId;
  final String? savedMealId;

  /// -1 down, 0 clear, 1 up.
  final int vote;
  final String? reason;

  @override
  String get type => 'set_meal_feedback';

  @override
  Map<String, Object?> payloadFields() => {
    if (libraryMealId != null) 'libraryMealId': libraryMealId,
    if (savedMealId != null) 'savedMealId': savedMealId,
    'vote': vote,
    if (reason != null) 'reason': reason,
  };
}

// ── Transcript + pantry actions (plan §5 Phases 6.1, 7.3) ───────────────────

/// `{conversationId, messageId}` — delete every message after (and
/// including) the edited user turn and restore the conversation's draft
/// plan to the snapshot taken after the previous assistant turn. Returns
/// `{parts: [batch?], removed}`; the client then sends the edited text as a
/// normal chat message on the same conversation.
/// `{planMealId, from, to}` — ingredient-level swap (plan Phase 6.3): the
/// server creates a saved variant with `from` replaced by `to`, swaps it into
/// the plan in place and recomputes the shopping list. Returns `{parts:[batch]}`.
class SwapIngredientAction extends UiAction {
  const SwapIngredientAction({
    required this.planMealId,
    required this.from,
    required this.to,
  });

  final String planMealId;
  final String from;
  final String to;

  @override
  String get type => 'swap_ingredient';

  @override
  Map<String, Object?> payloadFields() => {
    'planMealId': planMealId,
    'from': from,
    'to': to,
  };
}

class RewindAction extends UiAction {
  const RewindAction({required String conversationId, required this.messageId})
    : super(conversationId: conversationId);

  final String messageId;

  @override
  String get type => 'rewind';

  @override
  Map<String, Object?> payloadFields() => {'messageId': messageId};
}

/// `{conversationId, photoPath}` — [photoPath] is a `meal-photos` bucket
/// path (`{userId}/{uuid}.jpg`, the meal-logging upload). Returns
/// `{parts: [pantry], messageId}`; the server also persists the part as an
/// assistant message.
class PantryPhotoAction extends UiAction {
  const PantryPhotoAction({
    required String conversationId,
    required this.photoPath,
  }) : super(conversationId: conversationId);

  final String photoPath;

  @override
  String get type => 'pantry_photo';

  @override
  Map<String, Object?> payloadFields() => {'photoPath': photoPath};
}

/// `{conversationId, items}` — the names the athlete ticked on a `pantry`
/// card ("Use these"). Returns `{parts: []}`.
class SetPantryAction extends UiAction {
  const SetPantryAction({required String conversationId, required this.items})
    : super(conversationId: conversationId);

  final List<String> items;

  @override
  String get type => 'set_pantry';

  @override
  Map<String, Object?> payloadFields() => {'items': items};
}
