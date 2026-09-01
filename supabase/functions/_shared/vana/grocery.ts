/** Deterministic shopping list: plan_meals × ingredients → canonical names → aisles → aggregated qty. Pantry skip from recent logs + staples. */
import type { MealPlan, ShoppingItem } from './contracts.ts';
import type { VanaCtx } from './env.ts';

const AISLE_RULES: Array<[string, string[]]> = [
  ['Produce', ['lettuce','spinach','kale','arugula','cabbage','broccoli','cauliflower','carrot','celery','onion','garlic','shallot','leek','scallion','potato','sweet potato','yam','pepper','tomato','cucumber','zucchini','courgette','squash','mushroom','avocado','lemon','lime','orange','apple','banana','berry','berries','blueberr','strawberr','raspberr','grape','pear','peach','plum','cherry','cilantro','parsley','basil','mint','rosemary','thyme','ginger','fennel','asparagus','bok choy','radish','beet','corn','edamame','plantain','greens','sukuma','dates','mango','pineapple','melon']],
  ['Protein', ['chicken','turkey','beef','mince','pork','lamb','bacon','sausage','ham','salmon','tuna','cod','halibut','tilapia','trout','mackerel','sardine','shrimp','prawn','tofu','tempeh','seitan','egg','eggs','steak']],
  ['Dairy', ['milk','butter','cream','yogurt','yoghurt','cheese','cheddar','mozzarella','parmesan','feta','ricotta','cottage','kefir','ghee','skyr','quark']],
  ['Bakery & Grains', ['bread','tortilla','pita','bagel','muffin','naan','rice','quinoa','couscous','barley','oats','oatmeal','pasta','noodle','spaghetti','penne','lasagn','ramen','soba','bun','polenta','ugali','injera','cornflakes','cereal','granola','crackers','rice cake','wrap','flour']],
  ['Pantry', ['sugar','honey','maple','salt','baking','vanilla','oil','vinegar','soy sauce','tamari','teriyaki','fish sauce','hot sauce','ketchup','mustard','mayo','tahini','peanut butter','almond butter','seed butter','jam','jelly','broth','stock','bouillon','tomato sauce','tomato paste','marinara','crushed tomatoes','chopped tomatoes','coconut milk','bread crumb','panko','cornstarch','raisin','almond','walnut','cashew','pecan','pistachio','sunflower','pumpkin seed','chia','flax','lentil','chickpea','bean','dal','miso','nori','umeboshi','pesto','curry','coconut','nutella','chocolate','cocoa','protein powder','whey','wine','dashi','kombu','sesame oil','olive oil']],
  ['Spices', ['cumin','paprika','oregano','chili powder','garlic powder','onion powder','cinnamon','nutmeg','clove','cardamom','coriander','bay leaf','seasoning','garam masala','turmeric','pepper flakes','spice']],
  ['Frozen', ['frozen','ice cream']],
  ['Beverages', ['coffee','tea','juice','soda','sparkling','kombucha','sports drink','electrolyte']],
];
const AISLE_ORDER = ['Produce','Protein','Dairy','Bakery & Grains','Pantry','Spices','Frozen','Beverages','Other'];
/** Things nobody buys for one week's plan — always "have". */
const ALWAYS_HAVE = ['salt','pepper','olive oil','water','oil','pinch'];
const esc = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
/** Specific phrases that must win over a broader Produce/Protein match. */
const PRIORITY: Array<[string, string[]]> = [['Pantry', ['crushed tomatoes','chopped tomatoes','tinned tomatoes','canned','tomato sauce','tomato paste','passata','marinara','coconut milk','peanut butter','almond butter','seed butter','stock','broth','dried','raisin','sun-dried']], ['Frozen', ['frozen']], ['Dairy', ['cottage cheese','greek yogurt','cream cheese']]];
export function classifyAisle(name: string): string {
  const f = name.toLowerCase();
  for (const [aisle, keys] of PRIORITY) for (const k of keys) if (f.includes(k)) return aisle;
  for (const [aisle, keys] of AISLE_RULES) for (const k of keys) if (new RegExp(`(?<![a-z])${esc(k)}`).test(f)) return aisle;
  return 'Other';
}
const COLLAPSE: Array<[RegExp, string]> = [[/\b(yellow|red|white|spanish|vidalia)\s+onion\b/, 'onion'], [/\bgarlic\s+cloves?\b/, 'garlic'], [/\bcloves?\s+of\s+garlic\b/, 'garlic'], [/\bbaby\s+spinach\b/, 'spinach'], [/\b(grilled|baked|roasted|raw|cooked|steamed|fresh|chopped|diced|sliced|boneless|skinless)\s+/g, ''], [/\s*\([^)]*\)\s*/g, ' '], [/\s+(splash|pinch|to taste|handful|drizzle)$/, '']];
export function canonicalName(name: string): string {
  let f = name.toLowerCase().trim().replace(/\s+/g, ' ');
  for (const [p, r] of COLLAPSE) f = f.replace(p, r);
  f = f.replace(/,.*$/, '').replace(/\s+(dry|uncooked|cooked)$/, '').trim();
  return f;
}
const FR: Record<string, number> = { '½': 0.5, '¼': 0.25, '¾': 0.75, '⅓': 1 / 3, '⅔': 2 / 3 };
export function parseQty(q: string): { n: number | null; unit: string } {
  const s = (q || '').trim().toLowerCase();
  if (!s) return { n: null, unit: '' };
  const m = /^(\d+\/\d+|\d+(?:[.,]\d+)?|[½¼¾⅓⅔])\s*([a-z]*)/.exec(s);
  if (!m) return { n: null, unit: s };
  let n: number; const raw = m[1];
  if (FR[raw] != null) n = FR[raw]; else if (raw.includes('/')) { const [a, b] = raw.split('/').map(Number); n = a / b; } else n = parseFloat(raw.replace(',', '.'));
  let unit = m[2] || ''; if (['tbsps', 'tbs'].includes(unit)) unit = 'tbsp'; if (unit === 'grams' || unit === 'gram') unit = 'g'; if (unit === 'cups') unit = 'cup'; if (unit.startsWith('ml')) unit = 'ml';
  return { n, unit };
}
const fmt = (n: number) => { const r = Math.round(n * 4) / 4; const w = Math.floor(r); const f = r - w; const fs = f === 0.5 ? '½' : f === 0.25 ? '¼' : f === 0.75 ? '¾' : ''; return w === 0 && fs ? fs : fs ? `${w} ${fs}` : String(Math.round(r * 100) / 100); };
export function aggregate(entries: { qty: string; mult: number }[]): string {
  const by = new Map<string, number>(); const other: string[] = [];
  for (const e of entries) { const { n, unit } = parseQty(e.qty); if (n == null) { if (e.qty) other.push(e.qty); continue; } by.set(unit, (by.get(unit) ?? 0) + n * e.mult); }
  const parts = [...by.entries()].map(([u, n]) => { const big = (x: number) => String(Math.round(x * 10) / 10); if (u === 'g' && n >= 1000) return `${big(n / 1000)} kg`; if (u === 'ml' && n >= 1000) return `${big(n / 1000)} l`; return u ? `${fmt(n)} ${u}` : fmt(n); });
  if (other.length) parts.push(other[0]);
  return parts.join(' + ');
}

/** Pure aggregation over already-resolved meal ingredient lists — unit-tested. */
export function buildItems(meals: { id: string; servings: number; baseServings: number; ingredients: { name: string; qty: string }[] }[], have: Set<string>): ShoppingItem[] {
  const buckets = new Map<string, { name: string; entries: { qty: string; mult: number }[]; from: Set<string> }>();
  for (const m of meals) for (const ing of m.ingredients) {
    const key = canonicalName(ing.name); if (!key || ALWAYS_HAVE.some((h) => key === h)) continue;
    const b = buckets.get(key) ?? { name: key.charAt(0).toUpperCase() + key.slice(1), entries: [], from: new Set<string>() };
    b.entries.push({ qty: ing.qty, mult: m.servings / Math.max(1, m.baseServings) }); b.from.add(m.id); buckets.set(key, b);
  }
  const items: ShoppingItem[] = [...buckets.entries()].map(([key, b]) => ({ aisle: classifyAisle(key), name: b.name, qty: aggregate(b.entries), checked: false, have: [...have].some((h) => key.includes(h)), fromMealIds: [...b.from] }));
  items.sort((a, b) => AISLE_ORDER.indexOf(a.aisle) - AISLE_ORDER.indexOf(b.aisle) || a.name.localeCompare(b.name));
  return items;
}

/** Staples the user logged ≥2× in 30 days (by item name) count as "have". */
async function pantryFromLogs(v: VanaCtx): Promise<Set<string>> {
  const since = new Date(Date.now() - 30 * 86400_000).toISOString().slice(0, 10);
  const { data } = await v.db.from('meal_logs').select('items').eq('user_id', v.userId).eq('is_deleted', false).gte('log_date', since).limit(200);
  const counts = new Map<string, number>();
  for (const r of data ?? []) for (const i of (r.items ?? []) as { name?: string; food_name?: string }[]) { const k = canonicalName(i.name ?? i.food_name ?? ''); if (k) counts.set(k, (counts.get(k) ?? 0) + 1); }
  return new Set([...counts.entries()].filter(([k, c]) => c >= 2 && ['rice','oats','pasta','peanut butter','honey','olive oil','soy sauce'].some((s) => k.includes(s))).map(([k]) => k));
}

export async function buildShoppingList(v: VanaCtx, plan: MealPlan): Promise<ShoppingItem[]> {
  const resolved: { id: string; servings: number; baseServings: number; ingredients: { name: string; qty: string }[] }[] = [];
  for (const m of plan.meals) {
    if (m.source === 'library' && m.libraryMealId) {
      const { data } = await v.db.from('meal_library').select('ingredients_json').eq('id', m.libraryMealId).maybeSingle();
      let ings = ((data?.ingredients_json ?? []) as { name: string; qty: string }[]);
      for (const sw of m.swapsApplied) ings = ings.map((i) => (canonicalName(i.name) === canonicalName(sw.from) ? { ...i, name: sw.to } : i));
      resolved.push({ id: m.id, servings: m.servings, baseServings: 1, ingredients: ings });   // library portions are per athlete serving
    } else if (m.savedMealId) {
      const { data } = await v.db.from('saved_meals').select('items').eq('id', m.savedMealId).maybeSingle();
      const ings = ((data?.items ?? []) as { name?: string; food_name?: string; portion?: string; quantity?: string | number; serving?: string }[]).map((i) => ({ name: i.name ?? i.food_name ?? '', qty: String(i.portion ?? i.quantity ?? i.serving ?? '') }));
      resolved.push({ id: m.id, servings: m.servings, baseServings: 1, ingredients: ings });
    }
  }
  return buildItems(resolved, await pantryFromLogs(v));
}
