/** Zod schemas derived from contracts.ts (contract-v1) — the runtime check that what the functions emit is what the
 *  Dart parsers were written against. Used by tests/vana/contract.test.ts over the frozen fixtures; keep in lockstep
 *  with contracts.ts (a change here is a versioned contract change). Objects are `.strict()` where the contract is
 *  closed so an accidental extra key fails loudly; payloads the contract leaves open are `.passthrough()`. */
import { z } from 'npm:zod@3';

export const MealTypeZ = z.enum(['breakfast', 'lunch', 'dinner', 'snack']);
export const MealContextZ = z.enum(['everyday', 'pre-session', 'recovery', 'rest-day', 'race-week', 'carb-load', 'travel']);
export const SessionZ = z.enum(['cook-sun', 'topup-wed', 'fresh-fri']).nullable();
export const ConversationKindZ = z.enum(['meal_planning', 'general']);
export const MealIconKeyZ = z.enum(['bowl', 'oats', 'chicken', 'meat', 'fish', 'egg', 'salad', 'bread', 'wrap', 'pasta', 'soup', 'pizza', 'drink', 'fruit', 'nuts', 'yogurt', 'potato', 'beans', 'tofu', 'baked', 'snack', 'sweet', 'utensils']);
const VoteZ = z.union([z.literal(-1), z.literal(0), z.literal(1)]);
const numOrNull = z.number().nullable();

export const MealRefZ = z.object({
  source: z.enum(['library', 'saved']), id: z.string(), name: z.string(), mealType: MealTypeZ, contexts: z.array(MealContextZ),
  batch: z.boolean(), prepMinutes: numOrNull, kcal: numOrNull, carbsG: numOrNull, proteinG: numOrNull, fatG: numOrNull,
  allergens: z.array(z.string()), dietsOk: z.array(z.string()), swaps: z.string().nullable(), why: z.string(), attribution: z.string(), attributionShort: z.string().max(41),
  ingredients: z.string(), libraryMealId: z.string().nullable(), score: z.number(),
  kind: z.enum(['assembly', 'recipe']).optional(), pattern: z.string().nullable().optional(), frequency: z.string().nullable().optional(),
  icon: MealIconKeyZ.nullable().optional(), myVote: VoteZ.optional(),
}).strict();

export const PlanMealZ = z.object({
  id: z.string(), planId: z.string(), source: z.enum(['library', 'saved']), libraryMealId: z.string().nullable(), savedMealId: z.string().nullable(),
  name: z.string(), mealType: MealTypeZ, session: SessionZ, servings: z.number().int(), servingsLeft: z.number().int(),
  kcal: numOrNull, carbsG: numOrNull, proteinG: numOrNull, fatG: numOrNull,
  swapsApplied: z.array(z.object({ from: z.string(), to: z.string(), effect: z.string().optional() })),
  comments: z.array(z.object({ role: z.enum(['user', 'vana']), text: z.string(), at: z.string() })),
  position: z.number().int(), icon: MealIconKeyZ.nullable().optional(),
}).strict();
export const PlanRuleZ = z.object({ day: z.enum(['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']), rule: z.string(), mealId: z.string().optional(), accepted: z.boolean() }).strict();
export const ShoppingItemZ = z.object({ aisle: z.string(), name: z.string(), qty: z.string(), checked: z.boolean(), have: z.boolean(), fromMealIds: z.array(z.string()) }).strict();
export const DaySlotRefZ = z.object({ source: z.enum(['plan', 'saved', 'library']), id: z.string(), name: z.string(), kcal: numOrNull.optional(), carbsG: numOrNull.optional() }).strict();
export const DayPlanZ = z.object({ breakfast: DaySlotRefZ.nullable().optional(), lunch: DaySlotRefZ.nullable().optional(), dinner: DaySlotRefZ.nullable().optional(), snack: DaySlotRefZ.nullable().optional() }).strict();
export const DayTargetZ = z.object({ date: z.string(), kcal: z.number(), carbsG: z.number(), proteinG: z.number(), fatG: z.number(), sessionKcal: z.number(), planningKcal: z.number(), lunchDinnerKcal: z.number(), mode: z.string().nullable() }).strict();
export const MealPlanZ = z.object({
  id: z.string(), weekStart: z.string(), status: z.enum(['draft', 'confirmed', 'archived']), batchCooking: z.boolean(), days: z.record(DayPlanZ).optional(),
  conversationId: z.string().nullable().optional(), brief: z.string().nullable(), rules: z.array(PlanRuleZ), meals: z.array(PlanMealZ), shopping: z.array(ShoppingItemZ),
  dayNotes: z.record(z.string()), dayNotesStale: z.boolean().optional(),
  coverage: z.object({ lunchDinnerSlots: z.number(), covered: z.number(), perDay: z.object({ kcal: z.number(), carbsG: z.number(), proteinG: z.number() }).strict() }).strict(),
}).strict();
export const MemoryZ = z.object({ id: z.string(), kind: z.enum(['preference', 'constraint', 'pattern', 'episode', 'setting']), key: z.string().nullable(), fact: z.string(), value: z.unknown(), confidence: z.number(), lastConfirmedAt: z.string(), source: z.string().nullable().optional() }).strict();
export const MealDetailZ = z.object({
  meal: MealRefZ,
  ingredients: z.array(z.object({ name: z.string(), qty: z.string(), role: z.string().nullable().optional() }).passthrough()),
  methodSteps: z.array(z.string()),
  directions: z.object({ origin: z.enum(['source', 'alt_source', 'ai_generated', 'assembly_simple']).nullable(), sourceUrl: z.string().nullable(), sourceName: z.string().nullable(), verbatim: z.boolean() }).strict(),
  image: z.object({ url: z.string(), license: z.string().nullable(), creator: z.string().nullable(), credit: z.string().nullable(), sourceUrl: z.string().nullable() }).strict().nullable(),
  sourceUrl: z.string().nullable(), source: z.string(), swaps: z.array(z.string()), prep: z.string().nullable(), servings: z.number(), notes: z.string().nullable(), vote: VoteZ,
}).strict();

// ---- VanaPart (kind discriminant)
// `details` (optional) must be the same length as `options` — a refine() can't live in the discriminated union, so the contract test asserts it.
export const ChoicesPartZ = z.object({ kind: z.literal('choices'), question: z.string().optional(), options: z.array(z.string()).min(2).max(4), details: z.array(z.string().nullable()).optional() }).strict();
export const BriefPartZ = z.object({ kind: z.literal('brief'), text: z.string(), chips: z.array(z.string()), cites: z.array(z.string()) }).strict();
export const DayGuidancePartZ = z.object({ kind: z.literal('day_guidance'), date: z.string(), label: z.string(), workout: z.string().nullable(), minCarbsG: z.number(), note: z.string(), suggestions: z.array(MealRefZ) }).strict();
export const StaplesPartZ = z.object({ kind: z.literal('staples'), meals: z.array(MealRefZ.extend({ timesLogged: z.number(), ticked: z.boolean() }).strict()), planCarbsPerDay: z.number().optional(), targetCarbsPerDay: z.number().nullable().optional(), covered: z.number().optional(), of: z.number().optional() }).strict();
export const MealPickerPartZ = z.object({ kind: z.literal('meal_picker'), title: z.string(), mealType: MealTypeZ.optional(), meals: z.array(MealRefZ), multi: z.boolean(), defaultServings: z.number() }).strict();
export const BatchPartZ = z.object({ kind: z.literal('batch'), plan: MealPlanZ }).strict();
export const RulePartZ = z.object({ kind: z.literal('rule'), rule: PlanRuleZ, meal: MealRefZ.optional() }).strict();
export const ShoppingListPartZ = z.object({ kind: z.literal('shopping_list'), items: z.array(ShoppingItemZ), itemCount: z.number(), skipped: z.array(z.string()) }).strict();
export const MemorySavedPartZ = z.object({ kind: z.literal('memory_saved'), memory: MemoryZ }).strict();
export const LoggedPartZ = z.object({ kind: z.literal('logged'), planMealId: z.string(), name: z.string(), servingsLeft: z.number() }).strict();
export const DayPartZ = z.object({ kind: z.literal('day'), date: z.string(), label: z.string(), slots: DayPlanZ, filled: z.array(MealTypeZ) }).strict();
export const PantryPartZ = z.object({ kind: z.literal('pantry'), title: z.string(), items: z.array(z.object({ name: z.string(), selected: z.boolean() }).strict()), allowCustom: z.boolean(), origin: z.enum(['suggested', 'photo']) }).strict();
export const WeekPartZ = z.object({ kind: z.literal('week'), days: z.array(DayPartZ) }).strict();
export const DebriefPartZ = z.object({ kind: z.literal('debrief'), planId: z.string(), completed: z.number(), planned: z.number(), skipReason: z.string().nullable(), memories: z.array(MemoryZ) }).strict();
export const VanaPartZ = z.discriminatedUnion('kind', [ChoicesPartZ, BriefPartZ, DayGuidancePartZ, StaplesPartZ, MealPickerPartZ, BatchPartZ, RulePartZ, ShoppingListPartZ, MemorySavedPartZ, LoggedPartZ, DayPartZ, PantryPartZ, WeekPartZ, DebriefPartZ]);

// ---- wire
export const NdjsonLineZ = z.discriminatedUnion('type', [
  z.object({ type: z.literal('text'), delta: z.string() }).strict(),
  z.object({ type: z.literal('ui'), part: VanaPartZ }).strict(),
  z.object({ type: z.literal('status'), tool: z.string() }).strict(),
  z.object({ type: z.literal('done'), usage: z.object({ input_tokens: z.number().nullable(), output_tokens: z.number().nullable() }).strict().optional() }).strict(),
  z.object({ type: z.literal('error'), message: z.string() }).strict(),
]);
/** A recorded NDJSON exchange (fixtures opener.json / general_turn.json). */
export const NdjsonExchangeZ = z.object({ status: z.literal(200), headers: z.object({ 'x-conversation-id': z.string().min(1), 'x-vana-kind': ConversationKindZ, 'content-type': z.string().startsWith('application/x-ndjson') }).passthrough(), lines: z.array(NdjsonLineZ).min(1) });
/** `POST vana-action` → { parts, ...extras }. */
export const ActionResultZ = z.object({ parts: z.array(VanaPartZ) }).passthrough();
export const HomePayloadZ = z.object({
  context: z.object({}).passthrough(), brief: z.null(), day: DayGuidancePartZ, target: DayTargetZ.nullable(), weekTargets: z.array(DayTargetZ), staples: StaplesPartZ.nullable(),
  batch: BatchPartZ.nullable(), shopping: ShoppingListPartZ.nullable(), days: z.object({ date: z.string(), slots: DayPlanZ }).strict(),
  vana: z.object({ date: z.string(), stale: z.boolean(), text: z.string().nullable() }).strict(), memories: z.array(MemoryZ),
}).strict();
export const RecentMealZ = MealRefZ.extend({ lastUsedAt: z.string() }).strict();
