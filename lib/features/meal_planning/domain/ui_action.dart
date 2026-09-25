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
  const UiAction({this.planId, this.conversationId, this.chip});

  final String? planId;
  final String? conversationId;

  /// The label the athlete tapped, when this action is a fixed-label chip
  /// acting at once (mp-464, ticket 11): the server stores the tap as their
  /// turn and the result as Vana's, and logs it as a tap that drew nothing.
  /// Null on every other call, and only the chip actions
  /// (`VanaFixedChip.action`, "Use these") set it.
  final String? chip;

  /// The `type` discriminator.
  String get type;

  /// Action-specific payload fields (without scope).
  Map<String, Object?> payloadFields();

  /// Full payload: action fields + scope keys.
  Map<String, Object?> toPayloadJson() => {
    if (planId != null) 'planId': planId,
    if (conversationId != null) 'conversationId': conversationId,
    if (chip != null) 'chip': chip,
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
/// With [chip], the batch-cooking or coverage answer the athlete tapped
/// (mp-464): the server records the setting and stores the tap.
class SetSettingAction extends UiAction {
  const SetSettingAction({
    required this.key,
    required this.value,
    super.planId,
    super.conversationId,
    super.chip,
  });

  final VanaSetting key;

  /// A bool, a `week_start` day (`'mon'`), a `period_days` int or a
  /// `coverage_scope` (`'dinners'` | `'dinners_lunches'` | `'all'`).
  final Object value;

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

/// Delete a plan outright (`delete_plan`), [id] naming it and the scoped or
/// active plan standing in when it is omitted. Lee's 09-16 demo: there was
/// no way to get rid of a plan by hand. The result carries no `batch` — the
/// plan is gone — only a `receipt` whose undo puts it back.
class DeletePlanAction extends UiAction {
  const DeletePlanAction({this.id, super.planId, super.conversationId});

  final String? id;

  @override
  String get type => 'delete_plan';

  @override
  Map<String, Object?> payloadFields() => {if (id != null) 'id': id};
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

/// `{id, name}` → `{parts: [batch]}` — the athlete's own name for a plan
/// (mp-675); an empty [name] clears it back to the week.
class RenamePlanAction extends UiAction {
  const RenamePlanAction({required this.id, required this.name});

  final String id;
  final String name;

  @override
  String get type => 'rename_plan';

  @override
  Map<String, Object?> payloadFields() => {'id': id, 'name': name};
}

/// `{id}` → `{parts: [batch]}` — the plan [id] copied into this week as a
/// new draft (mp-675). The answer is the draft; the earlier plan is left as
/// it was, and this week's plan is untouched until the draft is confirmed.
class UsePlanAgainAction extends UiAction {
  const UsePlanAgainAction({required this.id});

  final String id;

  @override
  String get type => 'use_plan_again';

  @override
  Map<String, Object?> payloadFields() => {'id': id};
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

/// The Undo button on a receipt card (Lee's playtest 2026-09-16 §10): the
/// receipt's own `undo.params`, sent back verbatim. Returns
/// `{parts: [receipt(action: 'undo')]}`.
class UndoReceiptAction extends UiAction {
  const UndoReceiptAction({required this.params});

  final Map<String, dynamic> params;

  @override
  String get type => 'undo_receipt';

  @override
  Map<String, Object?> payloadFields() => Map<String, Object?>.from(params);
}

/// `{conversationId, items}` — the names the athlete ticked on a `pantry`
/// card ("Use these"). Returns `{parts: [memory_saved]}`. [chip] is the
/// app's own "I have … on hand" line, stored as the athlete's turn
/// (mp-464): Vana plans with the items on her next turn, with no turn spent
/// on the tap.
class SetPantryAction extends UiAction {
  const SetPantryAction({
    required String conversationId,
    required this.items,
    super.chip,
  }) : super(conversationId: conversationId);

  final List<String> items;

  @override
  String get type => 'set_pantry';

  @override
  Map<String, Object?> payloadFields() => {'items': items};
}

// ── Chips that act at once (mp-464 clause 1, ai-cost ticket 11) ─────────────
// Each is the body of the tool Vana used to call for that chip, run on the
// no-model endpoint with the label as `chip` so the server stores the tap.
// The result comes back as `{parts, tapMessageId, messageId}`.

/// `{conversationId?}` → `{parts: [batch]}` — the last confirmed plan copied
/// into this draft (mp-231 clause 5). Errors when there is none to copy.
class SameAsLastTimeAction extends UiAction {
  const SameAsLastTimeAction({super.planId, super.conversationId, super.chip});

  @override
  String get type => 'same_as_last_time';

  @override
  Map<String, Object?> payloadFields() => const {};
}

/// `{conversationId?, scope?}` → `{parts: [batch]}` — every type the athlete
/// plans filled from the library by this period's context.
class DraftWeekAction extends UiAction {
  const DraftWeekAction({
    this.scope,
    super.planId,
    super.conversationId,
    super.chip,
  });

  /// `'dinners'` | `'dinners_lunches'` | `'all'`, only when the athlete named
  /// how much to cover for this draft; null and their own walk decides.
  final String? scope;

  @override
  String get type => 'draft_week';

  @override
  Map<String, Object?> payloadFields() => {if (scope != null) 'scope': scope};
}

/// `{}` → `{parts: [week]}` — the confirmed collection laid across the days
/// of the period, on the Plan tab.
class PlanWeekAction extends UiAction {
  const PlanWeekAction({super.conversationId, super.chip});

  @override
  String get type => 'plan_week';

  @override
  Map<String, Object?> payloadFields() => const {};
}

/// `{title?}` → `{parts: [pantry]}` — what is likely in the house, as the
/// tappable grid.
class AskPantryAction extends UiAction {
  const AskPantryAction({this.title, super.conversationId, super.chip});

  final String? title;

  @override
  String get type => 'ask_pantry';

  @override
  Map<String, Object?> payloadFields() => {if (title != null) 'title': title};
}

/// `{}` → `{parts: []}` — the app opened the shopping list itself; the call
/// exists so the tap is stored in the conversation.
class OpenShoppingListAction extends UiAction {
  const OpenShoppingListAction({super.conversationId, super.chip});

  @override
  String get type => 'open_shopping_list';

  @override
  Map<String, Object?> payloadFields() => const {};
}

/// `{chipKind, mealType?}` → `{parts: [meal_picker]}`, or `{parts: [],
/// toVana: true, reason}` when the step is Vana's (mp-464, ai-cost ticket
/// 12). [chipKind] is a `VanaPickerChip.wire`: `more` / `no_recipe` /
/// `under_20` re-run the last picker with its filters and the chip's fixed
/// arguments; `next` draws the next meal type's picker when that is the whole
/// next step. [mealType] is the type a `Next: <type>` label named.
class NextPickerAction extends UiAction {
  const NextPickerAction({
    required this.chipKind,
    this.mealType,
    super.conversationId,
    super.chip,
  });

  final String chipKind;
  final MealType? mealType;

  @override
  String get type => 'next_picker';

  @override
  Map<String, Object?> payloadFields() => {
    'chipKind': chipKind,
    if (mealType != null) 'mealType': mealType!.wire,
  };
}

// ── Shopping lists (2026-09-16, several lists with hand edits) ───────────────
// Every one answers `{parts: [], list: ShoppingListDetail}` (or `lists`),
// read through [VanaActionResult.shoppingList] / [VanaActionResult.shoppingLists].

/// `{limit?}` → `{lists: ShoppingListSummary[]}`, most recent first.
class ListShoppingListsAction extends UiAction {
  const ListShoppingListsAction({this.limit});

  final int? limit;

  @override
  String get type => 'list_shopping_lists';

  @override
  Map<String, Object?> payloadFields() => {if (limit != null) 'limit': limit};
}

/// `{id?}` → `{list: ShoppingListDetail | null}`; no id = the most recent by
/// confirmation, else creation.
class GetShoppingListAction extends UiAction {
  const GetShoppingListAction({this.id});

  final String? id;

  @override
  String get type => 'get_shopping_list';

  @override
  Map<String, Object?> payloadFields() => {if (id != null) 'id': id};
}

/// `{name?, fromPlan?}` — an empty hand-made list, or one seeded from the
/// active plan's lines when [fromPlan] is true.
class CreateShoppingListAction extends UiAction {
  const CreateShoppingListAction({this.name, this.fromPlan = false});

  final String? name;
  final bool fromPlan;

  @override
  String get type => 'create_shopping_list';

  @override
  Map<String, Object?> payloadFields() => {
    if (name != null) 'name': name,
    if (fromPlan) 'fromPlan': true,
  };
}

/// `{id, name}`.
class RenameShoppingListAction extends UiAction {
  const RenameShoppingListAction({required this.id, required this.name});

  final String id;
  final String name;

  @override
  String get type => 'rename_shopping_list';

  @override
  Map<String, Object?> payloadFields() => {'id': id, 'name': name};
}

/// `{id}` — the list and every row on it go; answers the most recent list
/// left (`list`), or null when none remains.
class DeleteShoppingListAction extends UiAction {
  const DeleteShoppingListAction({required this.id});

  final String id;

  @override
  String get type => 'delete_shopping_list';

  @override
  Map<String, Object?> payloadFields() => {'id': id};
}

/// `{planId?}` → `{parts: [batch], list}` — Rebuild shopping list (ticket
/// 96): the plan's one list built from its meals the way confirm and every
/// edit build it (mp-244), updated in place or made again after a delete.
/// No [planId] = the week's active plan.
class RebuildShoppingListAction extends UiAction {
  const RebuildShoppingListAction({super.planId});

  @override
  String get type => 'rebuild_shopping_list';

  @override
  Map<String, Object?> payloadFields() => const {};
}

/// `{listId, name, qty?, aisle?}` — the server guesses the aisle when none
/// is given.
class AddShoppingItemAction extends UiAction {
  const AddShoppingItemAction({
    required this.listId,
    required this.name,
    this.qty,
    this.aisle,
  });

  final String listId;
  final String name;
  final String? qty;
  final String? aisle;

  @override
  String get type => 'add_shopping_item';

  @override
  Map<String, Object?> payloadFields() => {
    'listId': listId,
    'name': name,
    if (qty != null) 'qty': qty,
    if (aisle != null) 'aisle': aisle,
  };
}

/// `{id, name?, qty?, aisle?, checked?, have?}` — only the keys given are
/// written; a name or qty change marks the row `edited`.
class UpdateShoppingItemAction extends UiAction {
  const UpdateShoppingItemAction({
    required this.id,
    this.name,
    this.qty,
    this.aisle,
    this.checked,
    this.have,
  });

  final String id;
  final String? name;
  final String? qty;
  final String? aisle;
  final bool? checked;
  final bool? have;

  @override
  String get type => 'update_shopping_item';

  @override
  Map<String, Object?> payloadFields() => {
    'id': id,
    if (name != null) 'name': name,
    if (qty != null) 'qty': qty,
    if (aisle != null) 'aisle': aisle,
    if (checked != null) 'checked': checked,
    if (have != null) 'have': have,
  };
}

/// `{id}` — a manual row is deleted; a plan-built row becomes a tombstone
/// (`have`, `edited`) so the next re-plan does not bring it back.
class DeleteShoppingItemAction extends UiAction {
  const DeleteShoppingItemAction({required this.id});

  final String id;

  @override
  String get type => 'delete_shopping_item';

  @override
  Map<String, Object?> payloadFields() => {'id': id};
}
