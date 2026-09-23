/** Athlete profiles + RPC stubs for the Vana evals harness (`evals/vana/README.md`).
 *
 *  Everything here is producer-shaped, the same convention as tests/vana/support: rows are exactly what the tables
 *  return (snake_case and all), so the harness never feeds a Vana module its own output. The four athletes are the
 *  "Athlete" dimension of the scenario tuples; `seed` switches add the state a task needs (a week plan to adjust, a
 *  debrief waiting). The RPC handlers stand in for the SQL functions the fake db cannot run (search_meals, the
 *  rate-limit reservation, confirm_meal_plan) with deterministic, in-memory behaviour. */
import { FakeDb } from '../../tests/vana/support/fake_db.ts';
import type { Tables, Row } from '../../tests/vana/support/fake_db.ts';

export const TEST_USER_ID = '11111111-1111-4111-8111-111111111111';
/** Every scenario runs against this fixed Wednesday, so fixtures are reproducible regardless of the run date. */
export const ANCHOR = '2026-09-23';

const U = TEST_USER_ID;
const day = (n: number) => {
  const d = new Date(ANCHOR + 'T00:00:00Z');
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
};
const at = (n: number, hm = '07:00') => `${day(n)}T${hm}:00`;
const iso = (n: number) => new Date(new Date(ANCHOR + 'T00:00:00Z').getTime() + n * 86400_000).toISOString();

export type AthleteKey = 'dense' | 'sparse' | 'vegetarian' | 'offseason';

// ---------------------------------------------------------------- meal library fixture (what search_meals ranks over)
/** One library meal, producer-shaped (the columns `rowToMealRef` reads). `score` is not a table column — the real
 *  RPC returns it; the stub adds it the same way. */
const meal = (id: string, name: string, mealType: string, over: Partial<Row> = {}): Row => ({
  id, name, meal_type: mealType, contexts: ['everyday'], batch: false, prep_minutes: null,
  kcal: 650, carbs_g: 75, protein_g: 38, fat_g: 20, allergens: [], diets_ok: ['omnivore'],
  swaps: null, why: 'balanced plate', attribution: 'the Mealvana library', attribution_short: 'Mealvana library',
  ingredients: '', ingredients_json: [], kind: 'recipe', pattern: 'protein + starch + veg', score: 0.5,
  ...over,
});

export const MEAL_LIBRARY: Row[] = [
  // dinners — omnivore
  meal('D-101', 'Marathon bolognese', 'dinner', { contexts: ['everyday', 'carb-load'], batch: true, kcal: 780, carbs_g: 98, protein_g: 42, why: 'classic big-batch carb loader', ingredients: 'beef, pasta, tomato, onion' }),
  meal('D-102', 'Roast chicken with potatoes', 'dinner', { contexts: ['everyday'], batch: true, kcal: 720, carbs_g: 62, protein_g: 48, allergens: [], ingredients: 'chicken, potatoes, carrots' }),
  meal('D-103', 'Salmon and rice bowl', 'dinner', { contexts: ['everyday', 'recovery'], kcal: 700, carbs_g: 70, protein_g: 44, allergens: ['fish'], diets_ok: ['omnivore', 'pescatarian', 'mediterranean'], ingredients: 'salmon, rice, edamame' }),
  meal('D-104', 'Pork stir-fry with noodles', 'dinner', { contexts: ['everyday', 'pre-session'], batch: false, prep_minutes: 25, kcal: 690, carbs_g: 82, protein_g: 36, allergens: ['soy', 'gluten'], ingredients: 'pork, noodles, broccoli' }),
  meal('D-105', 'Turkey chilli', 'dinner', { contexts: ['everyday'], batch: true, kcal: 640, carbs_g: 58, protein_g: 46, ingredients: 'turkey, beans, tomato' }),
  meal('D-106', 'Shrimp paella', 'dinner', { contexts: ['everyday'], kcal: 710, carbs_g: 86, protein_g: 40, allergens: ['shellfish'], diets_ok: ['omnivore', 'pescatarian'], ingredients: 'shrimp, rice, peppers' }),
  meal('D-107', 'Steak and sweet potato', 'dinner', { contexts: ['recovery'], kcal: 760, carbs_g: 55, protein_g: 52, ingredients: 'steak, sweet potato, greens' }),
  meal('D-108', 'Race-eve white rice and chicken', 'dinner', { contexts: ['race-week', 'carb-load'], kcal: 820, carbs_g: 120, protein_g: 40, fat_g: 10, prep_minutes: 20, kind: 'assembly', why: 'low-fibre, high-carb race-eve plate', ingredients: 'chicken breast, white rice' }),
  // dinners — vegetarian / vegan
  meal('D-201', 'Lentil dal with basmati', 'dinner', { contexts: ['everyday', 'recovery'], batch: true, kcal: 680, carbs_g: 92, protein_g: 30, diets_ok: ['vegetarian', 'vegan', 'omnivore', 'mediterranean'], ingredients: 'lentils, basmati rice, spinach' }),
  meal('D-202', 'Chickpea coconut curry', 'dinner', { contexts: ['everyday'], batch: true, kcal: 660, carbs_g: 78, protein_g: 24, diets_ok: ['vegetarian', 'vegan', 'omnivore'], ingredients: 'chickpeas, coconut milk, rice' }),
  meal('D-203', 'Tofu stir-fry with rice', 'dinner', { contexts: ['everyday', 'pre-session'], prep_minutes: 20, kcal: 620, carbs_g: 74, protein_g: 32, allergens: ['soy'], diets_ok: ['vegetarian', 'vegan', 'omnivore'], ingredients: 'tofu, rice, mixed veg' }),
  meal('D-204', 'Black bean tacos', 'dinner', { contexts: ['everyday'], prep_minutes: 15, kind: 'assembly', kcal: 640, carbs_g: 88, protein_g: 26, allergens: ['gluten'], diets_ok: ['vegetarian', 'vegan', 'omnivore'], ingredients: 'black beans, tortillas, avocado' }),
  meal('D-205', 'Paneer tikka with naan', 'dinner', { contexts: ['everyday'], kcal: 700, carbs_g: 70, protein_g: 34, allergens: ['dairy', 'gluten'], diets_ok: ['vegetarian', 'omnivore'], ingredients: 'paneer, naan, peppers' }),
  meal('D-206', 'Egg fried rice with edamame', 'dinner', { contexts: ['everyday'], prep_minutes: 15, kcal: 600, carbs_g: 76, protein_g: 28, allergens: ['eggs', 'soy'], diets_ok: ['vegetarian', 'omnivore'], ingredients: 'eggs, rice, edamame' }),
  meal('D-207', 'Mushroom risotto', 'dinner', { contexts: ['carb-load'], kcal: 740, carbs_g: 100, protein_g: 20, allergens: ['dairy'], diets_ok: ['vegetarian', 'omnivore'], ingredients: 'arborio rice, mushrooms, parmesan' }),
  meal('D-208', 'Veggie race-eve pasta', 'dinner', { contexts: ['race-week', 'carb-load'], kcal: 800, carbs_g: 115, protein_g: 26, fat_g: 12, diets_ok: ['vegetarian', 'omnivore'], ingredients: 'pasta, tomato, courgette' }),
  // lunches
  meal('L-301', 'Chicken grain bowl', 'lunch', { contexts: ['everyday', 'recovery'], kcal: 580, carbs_g: 60, protein_g: 42, ingredients: 'chicken, quinoa, roast veg' }),
  meal('L-302', 'Turkey and hummus wrap', 'lunch', { prep_minutes: 10, kind: 'assembly', kcal: 520, carbs_g: 58, protein_g: 34, allergens: ['gluten'], ingredients: 'turkey, wrap, hummus' }),
  meal('L-303', 'Couscous and chickpea salad', 'lunch', { prep_minutes: 12, kind: 'assembly', kcal: 540, carbs_g: 72, protein_g: 20, diets_ok: ['vegetarian', 'vegan', 'omnivore'], ingredients: 'couscous, chickpeas, cucumber' }),
  meal('L-304', 'Miso salmon onigiri', 'lunch', { contexts: ['everyday'], kcal: 510, carbs_g: 68, protein_g: 30, allergens: ['fish', 'soy'], diets_ok: ['pescatarian', 'omnivore'], ingredients: 'salmon, rice, nori' }),
  meal('L-305', 'Halloumi and freekeh salad', 'lunch', { kcal: 560, carbs_g: 55, protein_g: 28, allergens: ['dairy'], diets_ok: ['vegetarian', 'omnivore'], ingredients: 'halloumi, freekeh, tomato' }),
  meal('L-306', 'Peanut noodles with tofu', 'lunch', { prep_minutes: 15, kcal: 590, carbs_g: 70, protein_g: 26, allergens: ['peanuts', 'soy'], diets_ok: ['vegetarian', 'vegan', 'omnivore'], ingredients: 'noodles, tofu, peanut sauce' }),
  // breakfasts
  meal('B-401', 'Overnight oats with berries', 'breakfast', { prep_minutes: 5, kind: 'assembly', kcal: 480, carbs_g: 70, protein_g: 22, allergens: ['gluten'], diets_ok: ['vegetarian', 'omnivore'], ingredients: 'oats, milk, berries' }),
  meal('B-402', 'Bagel with eggs and honey', 'breakfast', { contexts: ['pre-session', 'carb-load'], prep_minutes: 10, kind: 'assembly', kcal: 560, carbs_g: 85, protein_g: 24, allergens: ['gluten', 'eggs'], ingredients: 'bagel, eggs, honey' }),
  meal('B-403', 'Tofu scramble on sourdough', 'breakfast', { prep_minutes: 15, kcal: 520, carbs_g: 58, protein_g: 30, allergens: ['gluten', 'soy'], diets_ok: ['vegetarian', 'vegan', 'omnivore'], ingredients: 'tofu, sourdough, spinach' }),
  // snacks
  meal('S-501', 'Rice cakes with honey', 'snack', { contexts: ['pre-session', 'race-week'], prep_minutes: 3, kind: 'assembly', kcal: 210, carbs_g: 48, protein_g: 3, fat_g: 1, ingredients: 'rice cakes, honey' }),
  meal('S-502', 'Greek yogurt with granola', 'snack', { contexts: ['recovery'], kind: 'assembly', kcal: 320, carbs_g: 42, protein_g: 18, allergens: ['dairy'], diets_ok: ['vegetarian', 'omnivore'], ingredients: 'yogurt, granola' }),
  meal('S-503', 'Trail mix', 'snack', { kind: 'assembly', kcal: 280, carbs_g: 28, protein_g: 8, allergens: ['peanuts', 'tree_nuts'], ingredients: 'nuts, dried fruit' }),
  meal('S-504', 'Banana with almond butter', 'snack', { contexts: ['pre-session'], prep_minutes: 2, kind: 'assembly', kcal: 240, carbs_g: 34, protein_g: 7, allergens: ['tree_nuts'], diets_ok: ['vegetarian', 'vegan', 'omnivore'], ingredients: 'banana, almond butter' }),
];

const byId = (id: string) => MEAL_LIBRARY.find((m) => m.id === id)!;

/** The three settings the Doll reads, as `user_memories` setting rows (memory.ts getSetting). */
const setting = (key: string, value: unknown): Row => ({ user_id: U, kind: 'setting', key, value, fact: `${key} = ${JSON.stringify(value)}`, confidence: 1, source: 'settings', last_confirmed_at: iso(-20), embedding: null });
const note = (kind: string, fact: string, n: number): Row => ({ user_id: U, kind, key: null, value: null, fact, confidence: 0.8, source: 'conversation', last_confirmed_at: iso(n), embedding: null });
const episode = (fact: string, n: number): Row => ({ ...note('episode', fact, n), key: 'conv-old' });

/** A plan with `meals` library dinners in it, `status`, week `startDayOffset` from the anchor week's Sunday. */
function planWith(status: string, weekStart: string, meals: string[], planId: string): { meal_plans: Row[]; plan_meals: Row[] } {
  return {
    meal_plans: [{ id: planId, user_id: U, week_start: weekStart, status, batch_cooking: true, conversation_id: null, brief: null, days: {}, rules: [], shopping: [], day_notes: {}, day_notes_stale: false, checkin_done_at: null, debrief_done_at: status === 'confirmed' ? iso(-2) : null, created_at: iso(-6), updated_at: iso(-2) }],
    plan_meals: meals.map((id, i) => { const m = byId(id); return { id: `${planId}-m${i}`, plan_id: planId, user_id: U, source: 'library', library_meal_id: id, saved_meal_id: null, name: m.name, meal_type: m.meal_type, session: null, servings: 2, servings_left: 2, kcal: m.kcal, carbs_g: m.carbs_g, protein_g: m.protein_g, fat_g: m.fat_g, position: i, comments: [], swaps_applied: [], created_at: iso(-6) }; }),
  };
}

/** The anchor week's Sunday (week_start default 'sun', env.ts weekStartFor). */
const THIS_WEEK = '2026-09-20';
const LAST_WEEK = '2026-09-13';

const macro = (n: number, carb: number, prot = 130, fat = 70, tdee = 2600, sess = 0, mode = null): Row => ({ user_id: U, target_date: day(n), carb_g: carb, prot_g: prot, fat_g: fat, tdee, session_kcal: sess, mode });

/** State switches a scenario can ask for on top of the athlete. */
export interface Seed { currentPlan?: boolean; lastWeekPlan?: boolean }
export type ProfileKey = AthleteKey;

/** The tables for one athlete, everything the Doll build and the tools touch. */
export function seedTables(athlete: AthleteKey, seed: Seed = {}): Tables {
  const t: Tables = { meal_library: MEAL_LIBRARY.map((m) => ({ ...m })), meal_feedback: [], saved_meals: [], vana_messages: [], vana_conversations: [], user_memories: [], meal_plans: [], plan_meals: [], plan_debriefs: [], meal_logs: [], activities: [], daily_macro_targets: [], events: [], onboarding_surveys: [], user_entitlements: [{ user_id: U, period_type: 'NORMAL', active_until: iso(240) }], user_feedback: [] };

  if (athlete === 'dense') {
    t.users = [{ id: U, first_name: 'Marcus', dietary_preference: 'omnivore', allergies: ['shellfish'], gut_training_level: 'advanced', home_city: 'Boulder', home_lat: 40.01, home_lon: -105.27, home_timezone: 'America/Denver' }];
    t.activities = [
      { scheduled_date_time: at(0, '06:30'), title: 'Swim — 2500m', activity_type: 'swim', duration_minutes: 60, intensity_level: 'moderate', distance_miles: 1.55, status: 'completed' },
      { scheduled_date_time: at(1, '18:00'), title: 'Tempo run', activity_type: 'run', duration_minutes: 50, intensity_level: 'hard', distance_miles: 7, status: null },
      { scheduled_date_time: at(2, '06:30'), title: 'Easy spin', activity_type: 'ride', duration_minutes: 75, intensity_level: 'easy', distance_miles: 25, status: null },
      { scheduled_date_time: at(3, '18:00'), title: 'Track intervals', activity_type: 'run', duration_minutes: 45, intensity_level: 'hard', distance_miles: 6, status: null },
      { scheduled_date_time: at(5, '07:30'), title: 'Long ride', activity_type: 'ride', duration_minutes: 180, intensity_level: 'moderate', distance_miles: 62, status: null },
      { scheduled_date_time: at(6, '09:00'), title: 'Long run', activity_type: 'run', duration_minutes: 95, intensity_level: 'moderate', distance_miles: 13, status: null },
      { scheduled_date_time: at(-1, '08:00'), title: 'Brick — ride/run', activity_type: 'ride', duration_minutes: 120, intensity_level: 'hard', distance_miles: 45, status: 'completed' },
    ];
    t.events = [{ event_name: 'Boulder 70.3', event_date: day(12), location: 'Boulder, CO', event_type: 'triathlon' }];
    t.daily_macro_targets = [macro(0, 380, 130, 70, 2700, 500), macro(1, 420), macro(2, 400), macro(3, 430), macro(4, 380), macro(5, 480, 140, 70, 2900, 1100), macro(6, 450), macro(8, 500), macro(11, 560), macro(12, 520, 120, 55, 2800, 2200)];
    t.user_memories = [
      setting('batch_cooking', true), setting('coverage_scope', 'dinners_lunches'), setting('meal_types', ['dinner', 'lunch']), setting('weekly_budget_usd', 120),
      note('preference', 'Loves a big bowl of pasta the night before long sessions', -30), note('constraint', 'Cannot stomach gels on the bike, uses real food', -18), note('pattern', 'Trains 6 days a week, Monday is the rest day', -9), note('preference', 'Prefers batch cooking on Sunday afternoons', -25),
      episode('Asked for higher-carb dinners during race prep', -5), episode('Swapped salmon out of a plan — prefers white fish', -12),
    ];
    t.meal_feedback = [
      { user_id: U, library_meal_id: 'D-101', saved_meal_id: null, vote: 1, updated_at: iso(-4) },
      { user_id: U, library_meal_id: 'D-106', saved_meal_id: null, vote: -1, updated_at: iso(-9) },
      { user_id: U, library_meal_id: 'L-301', saved_meal_id: null, vote: 1, updated_at: iso(-6) },
    ];
    t.saved_meals = [{ id: 'saved-dense-1', user_id: U, name: "Sarah's turkey meatballs", items: [{ name: 'turkey', portion: '500g' }, { name: 'pasta', portion: '400g' }], calories: 660, carbs_g: 72, protein_g: 44, fat_g: 18, library_meal_id: null, meal_types: ['dinner'], batch: true, is_deleted: false, icon: null }];
    t.onboarding_surveys = [{ user_id: U, goals: ['Go under 5 hours at Boulder 70.3', 'Stop bonking on the long ride'], sports: ['triathlon'], pitfalls: [] }];
    t.meal_logs = [{ user_id: U, log_date: ANCHOR, slot: 'breakfast', name: 'Overnight oats with berries', calories: 480, carbs_g: 70, protein_g: 22, fat_g: 12, is_deleted: false }];
    t.plan_debriefs = [{ user_id: U, plan_id: 'plan-last', completed: 5, planned: 6, skip_reason: 'travel one night', created_at: iso(-9) }];
  } else if (athlete === 'sparse') {
    t.users = [{ id: U, first_name: 'Sam', dietary_preference: null, allergies: [], gut_training_level: null }];
    t.activities = [{ scheduled_date_time: at(1, '07:00'), title: 'Easy run', activity_type: 'run', duration_minutes: 35, intensity_level: 'easy', distance_miles: 4, status: null }];
    t.daily_macro_targets = [macro(0, 280, 110, 60, 2100), macro(1, 280, 110, 60, 2100)];
  } else if (athlete === 'vegetarian') {
    t.users = [{ id: U, first_name: 'Priya', dietary_preference: 'vegetarian', allergies: ['peanuts', 'tree_nuts'], gut_training_level: 'developing', home_city: 'Chicago', home_lat: 41.88, home_lon: -87.63, home_timezone: 'America/Chicago' }];
    t.activities = [
      { scheduled_date_time: at(1, '06:00'), title: 'Easy run', activity_type: 'run', duration_minutes: 40, intensity_level: 'easy', distance_miles: 5, status: null },
      { scheduled_date_time: at(3, '18:00'), title: 'Yoga', activity_type: 'yoga', duration_minutes: 60, intensity_level: 'easy', status: null },
      { scheduled_date_time: at(5, '08:00'), title: 'Long run', activity_type: 'run', duration_minutes: 100, intensity_level: 'moderate', distance_miles: 14, status: null },
    ];
    t.events = [{ event_name: 'Chicago Marathon', event_date: day(34), location: 'Chicago, IL', event_type: 'run' }];
    t.daily_macro_targets = [macro(0, 320, 120, 65, 2300), macro(1, 330), macro(2, 310), macro(3, 320), macro(4, 310), macro(5, 420, 130, 65, 2500, 800), macro(6, 340)];
    t.user_memories = [
      setting('batch_cooking', true), setting('coverage_scope', 'dinners'),
      note('constraint', 'Partner is vegetarian too — no meat in the house at all', -40), note('pattern', 'Wednesdays are chaos, needs something already cooked', -15), note('preference', 'Loves Indian food, could eat dal every week', -22),
    ];
    t.meal_feedback = [
      { user_id: U, library_meal_id: 'D-201', saved_meal_id: null, vote: 1, updated_at: iso(-5) },
      { user_id: U, library_meal_id: 'D-204', saved_meal_id: null, vote: 1, updated_at: iso(-8) },
    ];
    t.onboarding_surveys = [{ user_id: U, goals: ['Run Chicago under 4:15'], sports: ['running'], pitfalls: ['skips dinner after late runs'] }];
  } else {
    // offseason
    t.users = [{ id: U, first_name: 'Dan', dietary_preference: 'omnivore', allergies: [], gut_training_level: 'intermediate', home_city: 'Portland', home_lat: 45.52, home_lon: -122.68, home_timezone: 'America/Los_Angeles' }];
    t.activities = [
      { scheduled_date_time: at(2, '07:00'), title: 'Easy ride', activity_type: 'ride', duration_minutes: 60, intensity_level: 'easy', distance_miles: 20, status: null },
      { scheduled_date_time: at(4, '09:00'), title: 'Trail run', activity_type: 'run', duration_minutes: 55, intensity_level: 'easy', distance_miles: 6, status: null },
    ];
    t.daily_macro_targets = [macro(0, 300, 120, 65, 2300), macro(1, 300), macro(2, 310), macro(3, 300), macro(4, 310), macro(5, 300), macro(6, 300)];
    t.user_memories = [
      setting('batch_cooking', true), setting('coverage_scope', 'dinners'),
      note('pattern', 'Off-season until January, base training only', -30), note('preference', 'Likes to try new recipes when not in race prep', -11),
    ];
    t.onboarding_surveys = [{ user_id: U, goals: ['Stay consistent through winter'], sports: ['cycling', 'running'], pitfalls: [] }];
    t.plan_debriefs = [{ user_id: U, plan_id: 'plan-last', completed: 4, planned: 5, skip_reason: null, created_at: iso(-11) }];
  }

  if (seed.currentPlan) Object.assign(t, { meal_plans: [...t.meal_plans, ...planWith('confirmed', THIS_WEEK, ['D-102', 'D-201', 'L-301', 'D-105'], 'plan-this').meal_plans], plan_meals: [...t.plan_meals, ...planWith('confirmed', THIS_WEEK, ['D-102', 'D-201', 'L-301', 'D-105'], 'plan-this').plan_meals] });
  if (seed.lastWeekPlan) {
    const p = planWith('confirmed', LAST_WEEK, ['D-101', 'D-202', 'D-104', 'L-303'], 'plan-last');
    p.meal_plans[0].debrief_done_at = null;
    Object.assign(t, { meal_plans: [...t.meal_plans, ...p.meal_plans], plan_meals: [...t.plan_meals, ...p.plan_meals] });
  }
  return t;
}

// ---------------------------------------------------------------- RPC stubs
/** Stand-ins for the SQL functions the fake db cannot run. `fakeRef` is resolved at call time so the handlers can
 *  read and write the live fake tables (set_meal_feedback upserts, confirm_meal_plan flips status). */
// deno-lint-ignore no-explicit-any
export function rpcHandlers(fakeRef: () => FakeDb): Record<string, (args: any) => unknown> {
  const libRows = (): Row[] => {
    const f = fakeRef();
    return (f.tables.meal_library ?? []).map((r) => ({ ...r, source: 'library' }));
  };
  const savedRows = (): Row[] => {
    const f = fakeRef();
    return (f.tables.saved_meals ?? []).filter((s) => !s.is_deleted).map((s) => ({ ...s, id: s.id, source: 'saved', name: s.name, meal_type: (s.meal_types ?? ['dinner'])[0], batch: !!s.batch, prep_minutes: null, kcal: s.calories, carbs_g: s.carbs_g, protein_g: s.protein_g, fat_g: s.fat_g, allergens: [], diets_ok: [], contexts: ['everyday'], why: 'one of your saved meals', attribution: 'your saved meal', attribution_short: 'your saved meal', ingredients: (s.items ?? []).map((i: { name?: string }) => i.name ?? '').join(', '), library_meal_id: s.library_meal_id ?? null, kind: 'recipe', pattern: null, score: 0.45 }));
  };
  return {
    // The reservation: always room (a deterministic corpus must not be throttled by its own speed).
    vana_reserve_call: () => crypto.randomUUID(),
    // Deterministic stand-in for the vector search: hard filters, context affinity, then fixture score.
    // deno-lint-ignore no-explicit-any
    search_meals: (a: any) => {
      let rows = [...libRows(), ...savedRows()];
      if (a.p_meal_type) rows = rows.filter((r) => r.meal_type === a.p_meal_type);
      if (a.p_batch === true) rows = rows.filter((r) => !!r.batch);
      if (a.p_batch === false) rows = rows.filter((r) => !r.batch);
      if (a.p_require_diet) rows = rows.filter((r) => (r.diets_ok ?? []).includes(a.p_require_diet));
      if (a.p_exclude_allergens?.length) rows = rows.filter((r) => !(r.allergens ?? []).some((x: string) => a.p_exclude_allergens.includes(x)));
      if (a.p_kind) rows = rows.filter((r) => r.kind === a.p_kind);
      if (!a.p_embedding && a.p_query) { const words = String(a.p_query).toLowerCase().split(/\s+/).filter((w: string) => w.length > 2); if (words.length) rows = rows.filter((r) => words.some((w: string) => `${r.name} ${r.ingredients}`.toLowerCase().includes(w))); }
      const ctx = new Set((a.p_contexts ?? []) as string[]);
      const aff = (r: Row) => (r.contexts ?? []).filter((c: string) => ctx.has(c)).length;
      rows.sort((x, y) => (aff(y) - aff(x)) || ((y.score ?? 0) - (x.score ?? 0)) || String(x.name).localeCompare(String(y.name)));
      return rows.slice(0, a.p_limit ?? 12);
    },
    // All notes are "relevant" without a real embedding — the corpus is one athlete's handful of notes.
    // deno-lint-ignore no-explicit-any
    recall_memories: (a: any) => (fakeRef().tables.user_memories ?? []).filter((m) => !m.is_deleted && m.kind !== 'episode' && m.kind !== 'setting').slice(0, a.p_limit ?? 8).map((m) => ({ id: m.id, fact: m.fact, kind: m.kind, last_confirmed_at: m.last_confirmed_at })),
    match_library: () => [],
    // A pair is supported when both components appear somewhere in the fixture library (deterministic).
    // deno-lint-ignore no-explicit-any
    library_pair_support: (a: any) => {
      const ing = libRows().map((r) => `${r.name} ${r.ingredients}`.toLowerCase());
      return (a.p_components ?? []).flatMap((c: string, i: number) => (a.p_components ?? []).slice(i + 1).map((c2: string) => {
        const hit = ing.filter((s) => s.includes(String(c).toLowerCase()) && s.includes(String(c2).toLowerCase())).length;
        return { comp_a: c, comp_b: c2, n_meals: hit };
      })).filter((p: { n_meals: number }) => p.n_meals > 0);
    },
    // deno-lint-ignore no-explicit-any
    set_meal_feedback: (a: any) => { const f = fakeRef(); const rows = f.tables.meal_feedback ?? []; const existing = rows.findIndex((r) => (a.p_library_meal_id ? r.library_meal_id === a.p_library_meal_id : r.saved_meal_id === a.p_saved_meal_id)); const row = { user_id: U, library_meal_id: a.p_library_meal_id ?? null, saved_meal_id: a.p_saved_meal_id ?? null, vote: a.p_vote, reason: a.p_reason ?? null, updated_at: new Date().toISOString() }; if (existing >= 0) rows[existing] = row; else rows.push(row); return null; },
    // The remote-ack RPC, replayed in memory: flip the draft to confirmed and hand back its id.
    // deno-lint-ignore no-explicit-any
    confirm_meal_plan: (a: any) => { const f = fakeRef(); const p = (f.tables.meal_plans ?? []).find((r) => r.id === a.p_plan_id); if (p) { p.status = 'confirmed'; p.shopping = a.p_shopping ?? []; p.updated_at = new Date().toISOString(); return p.id; } return null; },
    // deno-lint-ignore no-explicit-any
    plan_log_from_plan: (a: any) => { const f = fakeRef(); const m = (f.tables.plan_meals ?? []).find((r) => r.id === a.p_plan_meal_id); if (m) m.servings_left = Math.max(0, (m.servings_left ?? 1) - 1); const id = crypto.randomUUID(); (f.tables.meal_logs ??= []).push({ id, user_id: U, log_date: a.p_log_date ?? ANCHOR, slot: a.p_meal_type ?? m?.meal_type ?? 'dinner', name: m?.name ?? 'plan meal', is_deleted: false }); return id; },
    vana_claim_day_notes: () => true,
    vana_release_day_notes: () => true,
  };
}
