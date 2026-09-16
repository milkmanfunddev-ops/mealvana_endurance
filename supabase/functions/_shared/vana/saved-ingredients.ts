/**
 * Ingredients for a dish-level saved meal (playtest 2026-09-16 §5, option A).
 *
 * A saved meal made from a log (Describe / photo) stores the dish as its one item:
 * `items = [{name: "Egg & Veggie Scramble", portion: "1 serving", …macros}]`. The grocery builder
 * turned that into a shopping line ("Egg & veggie scramble — 4 servings") Kroger cannot match.
 *
 * `isDishLevel` tells such a row from a "Save to mine" copy, whose `items` are real ingredient rows.
 * `extractIngredients` asks the tool model ONCE for the per-one-serving ingredients — from the name,
 * the items, the athlete's notes ("Two eggs per serving") and the per-serving macros as a sanity
 * anchor — and writes them to `saved_meals.ingredients_json` in `meal_library.ingredients_json`'s
 * shape (`[{name, qty}]`). The write is conditioned on the column still being NULL, so two
 * concurrent adds cannot both pay for it, and a meal is never extracted twice unless the column
 * is NULL again.
 *
 * `ensureSavedMealIngredients` is the hook plan.ts calls when a saved meal joins a plan. It never
 * throws: a model failure leaves the column NULL and the list falls back to the dish line.
 */
import { generateObject } from 'npm:ai@6';
import { z } from 'npm:zod@3';
import { TOOL_MODEL } from './env.ts';
import type { VanaCtx } from './env.ts';
import { logCall } from './log.ts';
import { checkRateLimit } from './rate-limit.ts';

/** A saved_meals.items row as the app and the server write it (either name key; either quantity key). */
export interface SavedItem { name?: string; food_name?: string; portion?: string | number | null; quantity?: string | number | null; serving?: string | number | null; calories?: number | null; carb_g?: number | null; carbs_g?: number | null; protein_g?: number | null; fat_g?: number | null; role?: string | null }
/** The stored shape, same as meal_library.ingredients_json. */
export interface SavedIngredient { name: string; qty: string }

const norm = (s: unknown) => String(s ?? '').toLowerCase().replace(/&/g, ' and ').replace(/[^a-z0-9]+/g, ' ').trim();
const itemName = (i: SavedItem) => i.name ?? i.food_name ?? '';
const itemQty = (i: SavedItem) => String(i.portion ?? i.quantity ?? i.serving ?? '').trim();
const hasMacros = (i: SavedItem) => [i.calories, i.carb_g, i.carbs_g, i.protein_g, i.fat_g].some((x) => typeof x === 'number');
/** A quantity that names a real unit or a count of a thing, not a portion of the dish. */
const UNIT_RE = /\b(g|kg|mg|ml|l|oz|lb|lbs|cups?|tbsp|tbs|tsp|cloves?|slices?|pieces?|cans?|tins?|stalks?|sheets?|bunch|bunches|scoops?|fillets?|handfuls?|sprigs?|leaves|leaf|whole|large|medium|small)\b/;
export const hasQuantityUnit = (qty: string) => { const s = qty.toLowerCase(); return /\d|[½¼¾⅓⅔]/.test(s) && UNIT_RE.test(s) && !/\b(servings?|portions?|plates?|bowls?)\b/.test(s); };

/**
 * True when the items carry no ingredient-shaped rows: nothing at all, a single item, every item
 * named as the meal itself, or items that carry macros (a logged food, not a recipe line) with no
 * quantity unit anywhere. A "Save to mine" copy (several named ingredients with amounts, no macros)
 * is not dish-level.
 */
export function isDishLevel(items: SavedItem[] | null | undefined, mealName: string): boolean {
  const rows = (items ?? []).filter((i) => itemName(i).trim());
  if (rows.length <= 1) return true;
  const meal = norm(mealName);
  if (meal && rows.every((i) => { const n = norm(itemName(i)); return n === meal || n.includes(meal) || meal.includes(n); })) return true;
  if (rows.every(hasMacros) && !rows.some((i) => hasQuantityUnit(itemQty(i)))) return true;
  return false;
}

/** What the model returns: per ONE serving, a few lines, amounts as a number plus a unit. */
export const IngredientsZ = z.object({
  ingredients: z.array(z.object({
    name: z.string().min(1).max(60),
    qty: z.number().positive().nullable(),
    unit: z.string().max(20).nullable(),
  })).min(1).max(16),
});
export type IngredientsOut = z.infer<typeof IngredientsZ>;

export const INGREDIENTS_SYSTEM = `You write the shopping ingredients for ONE serving of a dish an endurance athlete cooks at home.
- List what someone buys to make it: whole foods and pantry items, each once. No sub-recipes, no "to taste" lines, no cooking steps.
- Amounts are per ONE serving. Use the athlete's notes when they say an amount ("two eggs per serving" → eggs, 2). Otherwise a sensible home-cook amount.
- qty is a number; unit is a short unit ("g", "ml", "cup", "tbsp", "tsp", "clove", "slice") or null for a count of whole things (eggs, bananas). Never "serving".
- The per-serving macros are given as a sanity check: your amounts should roughly add up to them. Do not invent ingredients the dish would not have.
- Between 2 and 12 lines. Names lower-case, singular where natural ("egg" not "eggs" is fine either way).`;

export function ingredientsPrompt(meal: { name: string; items: SavedItem[]; notes?: string | null; calories?: number | null; carbsG?: number | null; proteinG?: number | null; fatG?: number | null }): string {
  const macros = [['kcal', meal.calories], ['carbs g', meal.carbsG], ['protein g', meal.proteinG], ['fat g', meal.fatG]].filter(([, v]) => v != null).map(([k, v]) => `${k} ${v}`).join(', ');
  const items = meal.items.map((i) => `- ${itemName(i)}${itemQty(i) ? ` (${itemQty(i)})` : ''}`).join('\n');
  return [`DISH: ${meal.name}`, items ? `LOGGED AS:\n${items}` : '', meal.notes?.trim() ? `ATHLETE'S NOTES: ${meal.notes.trim()}` : '', macros ? `PER-SERVING MACROS: ${macros}` : ''].filter(Boolean).join('\n');
}

/** Model output → the stored rows. A null qty becomes a blank so grocery's per-serving defaults apply. */
export function toStoredIngredients(out: IngredientsOut): SavedIngredient[] {
  const seen = new Set<string>(); const rows: SavedIngredient[] = [];
  for (const i of out.ingredients) {
    const name = i.name.trim().toLowerCase(); if (!name || seen.has(name)) continue; seen.add(name);
    const unit = (i.unit ?? '').trim().toLowerCase().replace(/^servings?$/, '');
    const n = i.qty == null ? '' : Number.isInteger(i.qty) ? String(i.qty) : String(Math.round(i.qty * 100) / 100);
    rows.push({ name, qty: [n, unit].filter(Boolean).join(' ') });
  }
  return rows;
}

export interface IngredientDeps {
  /** The one model call. Injected so a test drives the writer from a fixed answer. */
  generate: (input: { system: string; prompt: string }) => Promise<{ object: IngredientsOut; inputTokens?: number; outputTokens?: number }>;
}
/** Mutable on purpose: plan.ts calls the hook without a deps argument, so a test swaps `generate` here. */
export const ingredientDeps: IngredientDeps = {
  generate: async ({ system, prompt }) => {
    const { object, usage } = await generateObject({ model: TOOL_MODEL, schema: IngredientsZ, maxOutputTokens: 500, system, prompt });
    return { object, inputTokens: usage?.inputTokens, outputTokens: usage?.outputTokens };
  },
};

// deno-lint-ignore no-explicit-any
type SavedRow = Record<string, any>;

/** One model call, then the conditional write. Returns the rows written, or null when the column was already set. */
export async function extractIngredients(v: VanaCtx, saved: SavedRow, deps: IngredientDeps = ingredientDeps): Promise<SavedIngredient[] | null> {
  const started = Date.now();
  const { object, inputTokens, outputTokens } = await deps.generate({ system: INGREDIENTS_SYSTEM, prompt: ingredientsPrompt({ name: saved.name, items: (saved.items ?? []) as SavedItem[], notes: saved.notes, calories: saved.calories, carbsG: saved.carbs_g == null ? null : Number(saved.carbs_g), proteinG: saved.protein_g == null ? null : Number(saved.protein_g), fatG: saved.fat_g == null ? null : Number(saved.fat_g) }) });
  const rows = toStoredIngredients(object);
  if (!rows.length) return null;
  const { data, error } = await v.db.from('saved_meals').update({ ingredients_json: rows, updated_at: new Date().toISOString() }).eq('id', saved.id).eq('user_id', v.userId).is('ingredients_json', null).select('id');
  if (error) throw new Error(error.message);
  await logCall(v.admin, { userId: v.userId, functionName: 'vana.ingredients', model: TOOL_MODEL, inputTokens, outputTokens });
  console.log(`[vana] ingredients for ${saved.id}: ${rows.length} line(s) in ${Date.now() - started}ms`);
  return (data ?? []).length ? rows : null;
}

/** The backfill: every saved meal already in a plan gets the same once-only treatment when the list is rebuilt
 *  (`refreshShopping`, a write path — a `get_plan` / `get_home` read never calls this). Sequential on purpose so the
 *  rate bucket is respected; a meal the bucket refuses waits for the next rebuild. Never throws. */
export async function backfillPlanIngredients(v: VanaCtx, meals: { source: string; savedMealId: string | null }[], deps: IngredientDeps = ingredientDeps): Promise<Record<string, EnsureOutcome>> {
  const out: Record<string, EnsureOutcome> = {};
  for (const id of [...new Set(meals.filter((m) => m.source === 'saved' && m.savedMealId).map((m) => m.savedMealId!))]) out[id] = await ensureSavedMealIngredients(v, id, deps);
  return out;
}

export type EnsureOutcome ='extracted' | 'present' | 'not-dish-level' | 'not-found' | 'rate-limited' | 'failed';

/** The hook: a saved meal joining a plan gets its ingredients once, if it is dish-level and has none yet. Never throws. */
export async function ensureSavedMealIngredients(v: VanaCtx, savedMealId: string, deps: IngredientDeps = ingredientDeps): Promise<EnsureOutcome> {
  try {
    const { data: s } = await v.db.from('saved_meals').select('id, name, items, notes, calories, carbs_g, protein_g, fat_g, ingredients_json').eq('id', savedMealId).eq('user_id', v.userId).maybeSingle();
    if (!s) return 'not-found';
    if (s.ingredients_json != null) return 'present';
    if (!isDishLevel((s.items ?? []) as SavedItem[], String(s.name ?? ''))) return 'not-dish-level';
    const rl = await checkRateLimit(v.admin, v.userId, 'vana.ingredients');
    if (!rl.allowed) return 'rate-limited';
    return (await extractIngredients(v, s, deps)) ? 'extracted' : 'present';
  } catch (e) {
    console.error('[vana] ingredient extraction failed:', savedMealId, (e as Error).message);
    return 'failed';
  }
}
