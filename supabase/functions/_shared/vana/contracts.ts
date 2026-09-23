// Vana — shared contracts between server (tools) and UI (widgets). Single source of truth.
// Every tool result that renders in the chat is a `VanaPart`; the UI renders parts, never raw JSON.
export type MealType = 'breakfast' | 'lunch' | 'dinner' | 'snack';
export type MealContext = 'everyday' | 'pre-session' | 'recovery' | 'rest-day' | 'race-week' | 'carb-load' | 'travel';
export type Session = 'cook-sun' | 'topup-wed' | 'fresh-fri' | null;

export interface MealRef {                 // one row from search_meals()
  source: 'library' | 'saved';
  id: string;                              // 'D-048' or saved_meals uuid
  name: string;
  mealType: MealType;
  contexts: MealContext[];
  batch: boolean;
  prepMinutes: number | null;
  kcal: number | null; carbsG: number | null; proteinG: number | null; fatG: number | null;
  allergens: string[]; dietsOk: string[];
  swaps: string | null;
  why: string;                             // one honest line — the card's subtitle
  attribution: string;                     // full source string (detail sheet only)
  attributionShort: string;                // ≤40 chars: first named person/source — what cards and the model see
  ingredients: string;
  libraryMealId: string | null;            // for saved meals matched to the library
  score: number;
  kind?: 'assembly' | 'recipe';            // assembly = 1-6 plain components, no method ("chicken, rice & broccoli")
  pattern?: string | null;                 // assemblies: "protein + starch + veg"
  frequency?: string | null;               // staple / common / occasional
  icon?: string | null;                    // MealIconKey (meal_library.icon / saved_meals.icon), classified when missing
  myVote?: -1 | 0 | 1;                     // this user's thumb: -1 down, 1 up, 0 none. A -1 is filtered out of suggestions by search_meals.
  /** The Meal's current Dish photo, or null when it shows no picture at all (ADR 0003). */
  photo?: { url: string; credit: string | null; creditUrl: string | null } | null;
  /** @deprecated The frozen image pipeline's ladder. Still sent; the app ignores it. */
  imageMode?: 'dish' | 'mosaic' | 'tile' | 'none';
  /** @deprecated see photo */
  image?: { url: string; license: string | null; creator: string | null; credit: string | null; sourceUrl: string | null } | null;
  /** @deprecated see photo */
  imageTiles?: { url: string; name: string | null; license: string | null; creator: string | null; sourceUrl: string | null; provider: string | null }[];
}

export interface PlanMeal {
  id: string; planId: string;
  source: 'library' | 'saved'; libraryMealId: string | null; savedMealId: string | null;
  name: string; mealType: MealType; session: Session;
  servings: number; servingsLeft: number;
  kcal: number | null; carbsG: number | null; proteinG: number | null; fatG: number | null;
  swapsApplied: { from: string; to: string; effect?: string }[];
  comments: { role: 'user' | 'vana'; text: string; at: string }[];
  position: number;
  icon?: string | null;                    // MealIconKey copied from the source meal at add/swap time
}
export interface PlanRule { day: 'mon'|'tue'|'wed'|'thu'|'fri'|'sat'|'sun'; rule: string; mealId?: string; accepted: boolean }
export interface ShoppingItem { aisle: string; name: string; qty: string; checked: boolean; have: boolean; fromMealIds: string[] }
// ---- additive 2026-09-16 (several shopping lists, Lee's playtest §5/§6): a list with its own rows (shopping.ts)
/** One `shopping_items` row: a ShoppingItem with an id, its list, where it came from and whether a hand edited it. */
export interface ShoppingListItem extends ShoppingItem { id: string; listId: string; source: 'plan' | 'manual'; edited: boolean; position: number }
export interface ShoppingListSummary { id: string; planId: string | null; name: string; createdAt: string; updatedAt: string; confirmedAt: string | null; itemCount: number }
export interface ShoppingListDetail extends ShoppingListSummary { items: ShoppingListItem[] }
export type DaySlot = 'breakfast' | 'lunch' | 'dinner' | 'snack';
export interface DaySlotRef { source: 'plan' | 'saved' | 'library'; id: string; name: string; kcal?: number | null; carbsG?: number | null }
export type DayPlan = Partial<Record<DaySlot, DaySlotRef | null>>;
export type ConversationKind = 'meal_planning' | 'general';
export interface DayTarget { date: string; kcal: number; carbsG: number; proteinG: number; fatG: number; sessionKcal: number; planningKcal: number; lunchDinnerKcal: number; mode: string | null }
export interface MealPlan {
  id: string; weekStart: string; status: 'draft' | 'confirmed' | 'archived'; batchCooking: boolean; days?: Record<string, DayPlan>;
  conversationId?: string | null;          // drafts are owned by the Vana conversation building them; null = week-level (Plan tab / legacy)
  brief: string | null; rules: PlanRule[]; meals: PlanMeal[]; shopping: ShoppingItem[];
  dayNotes: Record<string, string>;        // ISO date → Vana's one-liner for that day, precomputed (see server/vana/daynotes.ts)
  dayNotesStale?: boolean;
  coverage: { lunchDinnerSlots: number; covered: number; periodDays: number; mealTypes?: MealType[]; perDay: { kcal: number; carbsG: number; proteinG: number } };  // periodDays (additive, 2026-09-15, mp-269): the period the slots and perDay are counted over · mealTypes (additive, 2026-09-16, mp-231): the types the athlete plans, one slot per day of the period each
}
/** Meal detail — what /food/meals/:id and cooking mode need; built by the `get_meal` action for a library id or a saved uuid. */
export interface MealIngredient { name: string; qty: string; role?: string | null }
export type DirectionsOrigin = 'source' | 'alt_source' | 'ai_generated' | 'assembly_simple';
export interface MealDetail {
  meal: MealRef;
  ingredients: MealIngredient[];             // library ingredients_json / saved items
  methodSteps: string[];                     // meal_library.method_steps (a saved meal inherits its linked recipe's)
  directions: { origin: DirectionsOrigin | null; sourceUrl: string | null; sourceName: string | null; verbatim: boolean };   // provenance of methodSteps
  /** The Meal's current Dish photo, or null when the recipe screen starts at the title (ADR 0003). */
  photo: { url: string; credit: string | null; creditUrl: string | null } | null;
  /** @deprecated The frozen image pipeline's hero. Still sent; the app ignores it. */
  image?: { url: string; license: string | null; creator: string | null; credit: string | null; sourceUrl: string | null } | null;
  /** @deprecated see photo */
  imageMode?: 'dish' | 'mosaic' | 'tile' | 'none';
  /** @deprecated see photo */
  imageTiles?: { url: string; name: string | null; license: string | null; creator: string | null; sourceUrl: string | null; provider: string | null }[];
  sourceUrl: string | null;                  // "see the original recipe"
  source: string;                            // full attribution line (library) — '' for saved
  swaps: string[];                           // "water→milk (+10g protein)" strings, one per swap
  prep: string | null;
  servings: number;
  notes: string | null;                      // saved meals only — the athlete's own directions
  vote: -1 | 0 | 1;
}
export interface Memory { id: string; kind: 'preference'|'constraint'|'pattern'|'episode'|'setting'; key: string | null; fact: string; value: unknown; confidence: number; lastConfirmedAt: string; source?: string | null }   // source (additive, 2026-09-03): 'conversation' | 'onboarding' | 'settings' | 'debrief' — provenance for the memory drawer

// ---- Generative-UI parts (tool → widget). Names match the canvas notes.
export type VanaPart =
  | { kind: 'choices'; question?: string; options: string[]; details?: (string | null)[] }     // askChoice — 2..4 options; `details` (additive, 2026-09-03) = one trade-off line per option, same length as `options`, null where none
  | { kind: 'brief'; text: string; chips: string[]; cites: string[] }                            // weeklyBrief
  | { kind: 'day_guidance'; date: string; label: string; workout: string | null; minCarbsG: number; note: string; suggestions: MealRef[] } // dayGuidance
  | { kind: 'staples'; meals: (MealRef & { timesLogged: number; ticked: boolean })[]; planCarbsPerDay?: number; targetCarbsPerDay?: number | null; covered?: number; of?: number }           // diagnoseStaples (suggest only — nothing is added until tapped)
  // meal_picker — `chips` (additive 2026-09-16, mp-272/mp-230 clause 4, ticket 31): the labels this turn expects next,
  // 2..4 plain strings the APP draws in its own chip widget; absent or empty and the app's own set applies. A longer
  // list is clamped to four by the producer, a shorter one dropped — the schema only ever carries a legal one.
  // `more` (same ticket, mp-230 clause 2): the tail of the SAME search behind "Show more", never the shown handful.
  | { kind: 'meal_picker'; title: string; mealType?: MealType; meals: MealRef[]; multi: boolean; defaultServings: number; chips?: string[]; more?: MealRef[] } // suggestMeals
  | { kind: 'batch'; plan: MealPlan }                                                             // updateBatch / getBatch
  | { kind: 'rule'; rule: PlanRule; meal?: MealRef }                                              // proposeRule
  | { kind: 'shopping_list'; items: ShoppingItem[]; itemCount: number; skipped: string[] }       // shoppingList
  | { kind: 'memory_saved'; memory: Memory }                                                      // rememberFact
  | { kind: 'logged'; planMealId: string; name: string; servingsLeft: number }                    // logFromPlan
  | { kind: 'day'; date: string; label: string; slots: DayPlan; filled: DaySlot[] }                // planDay / setDaySlot
  // ---- additive 2026-09-03 (plan Phases 3, 7, 8)
  | { kind: 'pantry'; title: string; items: { name: string; selected: boolean }[]; allowCustom: boolean; origin: 'suggested' | 'photo' }   // askPantry / pantry_photo — what's in the house; nothing is used until the athlete taps "Use these"
  | { kind: 'week'; periodDays?: number; days: { kind: 'day'; date: string; label: string; slots: DayPlan; filled: DaySlot[] }[] }                              // planWeek — the confirmed collection laid across the week (Phase 8)
  | { kind: 'debrief'; planId: string; completed: number; planned: number; skipReason: string | null; memories: Memory[] }                 // recordDebrief — end-of-week debrief captured (Phase 3)
  // ---- additive 2026-09-09 (feedback loop) — typing feedback INTO Vana is the feedback system
  | { kind: 'feedback_saved'; message: string; sentiment: 'positive' | 'negative' | 'neutral'; about: 'vana' | 'app' | 'suggestion' } // saveFeedback — the athlete's words landed in user_feedback; the client draws the whole acknowledgement from it (the model writes nothing)
  | { kind: 'feedback_prompt' }                                                                                                             // server-appended after the FIRST conversation's opener: "Have feedback for me? Just type it here." (plain text)
  // ---- additive 2026-09-15 (mp-265 clause 4, ticket 27) — a deterministic action is a hand-off to the app's own screen, never done in the chat
  | { kind: 'hand_off'; target: HandOffTarget; label: string; entityId: string | null }                                                   // handOff — the app renders a button that navigates; entityId = the workout / event it is about, null when none
  // ---- additive 2026-09-16 (Lee's playtest §10) — Vana writes the app's own objects herself. Every write answers a receipt the
  // app draws as a small card ("Removed IRONMAN Cozumel · Undo"); `entity` tells the device which local store to refetch, and
  // `undo`, when present, is the `undo_receipt` action that puts it back. A delete without `confirmed: true` writes nothing and
  // answers `needs_confirmation` instead, so the model asks first (askChoice) and calls again after a yes.
  | { kind: 'receipt'; action: ReceiptAction; entity: ReceiptEntity; summary: string; entityId: string; undo: ReceiptUndo | null }
  | { kind: 'needs_confirmation'; action: ReceiptAction; entity: ReceiptEntity; summary: string; entityId: string };

/** What a receipt records. `undo` is the receipt the Undo button itself produces. */
export type ReceiptAction = 'new_plan' | 'delete_plan' | 'create_event' | 'update_event' | 'delete_event' | 'create_activity' | 'update_activity' | 'delete_activity' | 'log_meal' | 'delete_logged_meal' | 'undo';
/** The app object a write touched — the device refetches that store when the receipt arrives (events / meal logs are offline-first). */
export type ReceiptEntity = 'plan' | 'event' | 'activity' | 'meal_log';
/** `POST vana-action { type: 'undo_receipt', payload: params }` — `params.action` names the write being undone and carries what it needs. */
export interface ReceiptUndo { action: 'undo_receipt'; params: Record<string, unknown> & { action: ReceiptAction } }

/** The screens a hand-off lands on: meal_plan → the meal-planning page · new_activity → fuelling a workout ·
 *  event → planning an event · carb_loading → the carb-loading picks (on the event). */
export type HandOffTarget = 'meal_plan' | 'new_activity' | 'event' | 'carb_loading';

// ---- What the UI sends back (chip taps are plain user messages; structured edits go through these)
export interface UiAction {
  type: 'pick_meals' | 'unpick_meal' | 'swap_meal' | 'remove_meal' | 'set_servings' | 'confirm_plan' | 'toggle_shopping' | 'log_from_plan' | 'set_setting' | 'delete_memory' | 'set_day_slot' | 'clear_day_slot' | 'plan_day' | 'new_plan' | 'get_plan' | 'list_plans'
    | 'set_session' | 'apply_swap' | 'add_comment' | 'accept_rule' | 'list_memories' | 'save_meal'
    // app-only (the Flutter client has no server fns): get_home{date?} · get_meal{id} · recent_meals{limit?} · set_saved_meal_notes{savedMealId,notes} · set_meal_feedback{libraryMealId?|savedMealId?,vote,reason?}
    | 'get_home' | 'get_meal' | 'recent_meals' | 'set_saved_meal_notes' | 'set_meal_feedback'
    // additive 2026-09-03: rewind{conversationId, messageId} (drop every message after messageId and restore that turn's draft-plan snapshot) ·
    // pantry_photo{conversationId, photoPath} (ingredient detection on a `meal-photos` upload → a persisted `pantry` part) ·
    // set_pantry{conversationId, items: string[]} (what's on hand → shopping `have`) · swap_ingredient{planMealId, from, to} (saved variant + swap in place)
    | 'rewind' | 'pantry_photo' | 'set_pantry' | 'swap_ingredient'
    // additive 2026-09-16 (several shopping lists): list_shopping_lists{} → {lists} · get_shopping_list{id?} → {list|null} (default = most
    // recent by coalesce(confirmed_at, created_at)) · create_shopping_list{name?, fromPlan?} → {list} · rename_shopping_list{id, name} →
    // {list} · add_shopping_item{listId, name, qty?, aisle?} → {list} · update_shopping_item{id, name?, qty?, aisle?, checked?, have?} →
    // {list} (name/qty set edited=true) · delete_shopping_item{id} → {list}. All `parts: []`.
    // additive 2026-09-16 (Shopping tab redesign): delete_shopping_list{id} → {list|null} — the list and its rows go (a plan's list
    // empties the plan's mirror too); the answer is the most recent list left, null when none remains. `parts: []`.
    | 'list_shopping_lists' | 'get_shopping_list' | 'create_shopping_list' | 'rename_shopping_list' | 'delete_shopping_list' | 'add_shopping_item' | 'update_shopping_item' | 'delete_shopping_item'
    // additive 2026-09-16 (Vana writes, playtest §10): undo_receipt{...ReceiptUndo.params} — the Undo button on a receipt card. Answers
    // `{ parts: [receipt(action: 'undo')] }`; the device refetches the receipt's entity as for any receipt.
    | 'undo_receipt'
    // additive 2026-09-16 (Lee: the athlete deletes a plan by hand): delete_plan{id?, planId?, conversationId?} — the Plan tab's Delete.
    // Answers `{ parts: [receipt(action: 'delete_plan', undo: {…})] }` and no batch part; Undo is the receipt's undo_receipt.
    | 'delete_plan'
    // additive 2026-09-23 (mp-464, ai-cost ticket 11): the chips whose next step is fixed act at once, with no model turn.
    // same_as_last_time{conversationId?|planId?} → {parts:[batch]} (mp-231 clause 5, on the endpoint since 09-15) ·
    // draft_week{conversationId?, scope?} → {parts:[batch]} (the draftWeek tool's body) · plan_week{} → {parts:[week]} (planWeek's) ·
    // ask_pantry{title?} → {parts:[pantry]} (askPantry's) · open_shopping_list{} → {parts:[]} (the app opened the list itself).
    // Any of these, `set_setting` and `set_pantry` may carry `chip: <the label tapped>` beside `conversationId`: the server then
    // stores the tap as the athlete's turn and the result as a textless assistant turn typed as the tool it stands in for, logs
    // one `vana_calls` row with no model and `input_mode: 'tap'`, and answers `tapMessageId` / `messageId` beside `parts`.
    | 'same_as_last_time' | 'draft_week' | 'plan_week' | 'ask_pantry' | 'open_shopping_list';
  payload: Record<string, unknown>;
}

// ---- Athlete context injected on every turn (~1.5k tokens max). Built server-side, deterministic.
export interface AthleteContext {
  profile: { firstName: string | null; diet: string | null; allergies: string[]; gutTraining: string | null };
  week: { start: string; periodDays?: number; character: string; anchor: string | null; loadScore: number; workouts: { date: string; title: string; type: string; minutes: number | null; intensity: string | null }[] };
  race: { name: string; date: string; daysOut: number; location: string | null } | null;
  budget: { today: DayTarget | null; week: DayTarget[]; raceWeekCarbsG: number | null };   // straight from daily_macro_targets (the daily-macros service); never recomputed
  weather: { today: string | null; raceDay: string | null };
  holidays: { date: string; name: string; daysOut: number }[];   // US holidays in the next 2 weeks
  loggedToday: { count: number; carbsG: number };
  // batchKnown (additive, 2026-09-02): whether batch_cooking was ever chosen (plan row or setting memory).
  // Without it the context coalesced to `true` and the persona's "ask once when unknown" fork could never fire.
  // coverageScope (additive, 2026-09-03): the athlete's chosen coverage ('dinners' | 'dinners_lunches' | 'all'), null = never chosen → the persona asks once.
  // mealTypes (additive, 2026-09-16, mp-231): the meal types the athlete plans, in their order (the `meal_types` setting); null = never chosen, so the coverage scope stands in.
  plan: { exists: boolean; status: string | null; mealsLeft: number | null; batchCooking: boolean; batchKnown?: boolean; coverageScope?: string | null; mealTypes?: MealType[] | null };
  memories: Memory[];       // top ~10 margin notes by relevance/recency; never an episode (those are lastTalks)
  lastTalks?: { date: string; fact: string }[];   // additive 2026-09-11: the newest conversations' episode sentences, newest first
  // ---- additive 2026-09-03 (plan Phase 2 + 3; server-internal, Dart never sees AthleteContext)
  recentSession?: { date: string; title: string; type: string; minutes: number | null; intensity: string | null; status: string | null } | null;   // the notable session of the last 2 days ("you crushed a century yesterday")
  season?: string[];                                                                   // in-season produce this month (season.ts)
  grocery?: { weeklyUsd: number | null };                                              // weekly_budget_usd setting, if the athlete ever set one
  lastWeek?: { completed: number; planned: number; skipReason: string | null; weekStart: string } | null;   // the most recent debrief (plan_debriefs) — learnings feed forward
  // ---- additive 2026-09-09 (the Voodoo Doll: both conversation kinds read the same block)
  likes?: { name: string; stance: 'up' | 'down' }[];   // meal_feedback thumbs, newest first — read where they already live, never copied
  goals?: string[];                                    // onboarding_surveys.goals — what the athlete said they were training for
  home?: { city: string; lat: number | null; lon: number | null; timezone: string | null } | null;   // where they live — a Fact on the user record, not a Memory
}

// ---- Conversations (vana_conversations / vana_messages)
export interface ConversationSummary { id: string; kind: ConversationKind; title: string | null; summary: string | null; lastMessageAt: string | null; createdAt: string }
