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
  coverage: { lunchDinnerSlots: number; covered: number; perDay: { kcal: number; carbsG: number; proteinG: number } };
}
/** Meal detail — what /food/meals/:id and cooking mode need; built by the `get_meal` action for a library id or a saved uuid. */
export interface MealIngredient { name: string; qty: string; role?: string | null }
export type DirectionsOrigin = 'source' | 'alt_source' | 'ai_generated' | 'assembly_simple';
export interface MealDetail {
  meal: MealRef;
  ingredients: MealIngredient[];             // library ingredients_json / saved items
  methodSteps: string[];                     // meal_library.method_steps (a saved meal inherits its linked recipe's)
  directions: { origin: DirectionsOrigin | null; sourceUrl: string | null; sourceName: string | null; verbatim: boolean };   // provenance of methodSteps
  image: { url: string; license: string | null; creator: string | null; credit: string | null; sourceUrl: string | null } | null;
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
  | { kind: 'meal_picker'; title: string; mealType?: MealType; meals: MealRef[]; multi: boolean; defaultServings: number } // suggestMeals
  | { kind: 'batch'; plan: MealPlan }                                                             // updateBatch / getBatch
  | { kind: 'rule'; rule: PlanRule; meal?: MealRef }                                              // proposeRule
  | { kind: 'shopping_list'; items: ShoppingItem[]; itemCount: number; skipped: string[] }       // shoppingList
  | { kind: 'memory_saved'; memory: Memory }                                                      // rememberFact
  | { kind: 'logged'; planMealId: string; name: string; servingsLeft: number }                    // logFromPlan
  | { kind: 'day'; date: string; label: string; slots: DayPlan; filled: DaySlot[] }                // planDay / setDaySlot
  // ---- additive 2026-09-03 (plan Phases 3, 7, 8)
  | { kind: 'pantry'; title: string; items: { name: string; selected: boolean }[]; allowCustom: boolean; origin: 'suggested' | 'photo' }   // askPantry / pantry_photo — what's in the house; nothing is used until the athlete taps "Use these"
  | { kind: 'week'; days: { kind: 'day'; date: string; label: string; slots: DayPlan; filled: DaySlot[] }[] }                              // planWeek — the confirmed collection laid across the week (Phase 8)
  | { kind: 'debrief'; planId: string; completed: number; planned: number; skipReason: string | null; memories: Memory[] };                // recordDebrief — end-of-week debrief captured (Phase 3)

// ---- What the UI sends back (chip taps are plain user messages; structured edits go through these)
export interface UiAction {
  type: 'pick_meals' | 'unpick_meal' | 'swap_meal' | 'remove_meal' | 'set_servings' | 'confirm_plan' | 'toggle_shopping' | 'log_from_plan' | 'set_setting' | 'delete_memory' | 'set_day_slot' | 'clear_day_slot' | 'plan_day' | 'new_plan' | 'get_plan' | 'list_plans'
    | 'set_session' | 'apply_swap' | 'add_comment' | 'accept_rule' | 'list_memories' | 'save_meal'
    // app-only (the Flutter client has no server fns): get_home{date?} · get_meal{id} · recent_meals{limit?} · set_saved_meal_notes{savedMealId,notes} · set_meal_feedback{libraryMealId?|savedMealId?,vote,reason?}
    | 'get_home' | 'get_meal' | 'recent_meals' | 'set_saved_meal_notes' | 'set_meal_feedback'
    // additive 2026-09-03: rewind{conversationId, messageId} (drop every message after messageId and restore that turn's draft-plan snapshot) ·
    // pantry_photo{conversationId, photoPath} (ingredient detection on a `meal-photos` upload → a persisted `pantry` part) ·
    // set_pantry{conversationId, items: string[]} (what's on hand → shopping `have`) · swap_ingredient{planMealId, from, to} (saved variant + swap in place)
    | 'rewind' | 'pantry_photo' | 'set_pantry' | 'swap_ingredient';
  payload: Record<string, unknown>;
}

// ---- Athlete context injected on every turn (~1.5k tokens max). Built server-side, deterministic.
export interface AthleteContext {
  profile: { firstName: string | null; diet: string | null; allergies: string[]; gutTraining: string | null };
  week: { start: string; character: string; anchor: string | null; loadScore: number; workouts: { date: string; title: string; type: string; minutes: number | null; intensity: string | null }[] };
  race: { name: string; date: string; daysOut: number; location: string | null } | null;
  budget: { today: DayTarget | null; week: DayTarget[]; raceWeekCarbsG: number | null };   // straight from daily_macro_targets (the daily-macros service); never recomputed
  weather: { today: string | null; raceDay: string | null };
  holidays: { date: string; name: string; daysOut: number }[];   // US holidays in the next 2 weeks
  loggedToday: { count: number; carbsG: number };
  // batchKnown (additive, 2026-09-02): whether batch_cooking was ever chosen (plan row or setting memory).
  // Without it the context coalesced to `true` and the persona's "ask once when unknown" fork could never fire.
  // coverageScope (additive, 2026-09-03): the athlete's chosen coverage ('dinners' | 'dinners_lunches' | 'all'), null = never chosen → the persona asks once.
  plan: { exists: boolean; status: string | null; mealsLeft: number | null; batchCooking: boolean; batchKnown?: boolean; coverageScope?: string | null };
  memories: Memory[];       // top ~10 by recency/relevance
  // ---- additive 2026-09-03 (plan Phase 2 + 3; server-internal, Dart never sees AthleteContext)
  recentSession?: { date: string; title: string; type: string; minutes: number | null; intensity: string | null; status: string | null } | null;   // the notable session of the last 2 days ("you crushed a century yesterday")
  season?: string[];                                                                   // in-season produce this month (season.ts)
  grocery?: { weeklyUsd: number | null };                                              // weekly_budget_usd setting, if the athlete ever set one
  lastWeek?: { completed: number; planned: number; skipReason: string | null; weekStart: string } | null;   // the most recent debrief (plan_debriefs) — learnings feed forward
}

// ---- Conversations (vana_conversations / vana_messages)
export interface ConversationSummary { id: string; kind: ConversationKind; title: string | null; summary: string | null; lastMessageAt: string | null; createdAt: string }
