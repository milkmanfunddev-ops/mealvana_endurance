/** Contract test — every `contract-v1` fixture (copied verbatim from the prototype's tests/fixtures/, written from live
 *  dev calls as the QA user) must parse against the zod schemas derived from contracts.ts. This is the same check the
 *  Dart `fromJson` tests make; if a fixture stops parsing here, the contract moved and three places need the change
 *  (prototype TS, _shared/vana/, lib/features/meal_planning/domain/). Regenerate fixtures in the prototype (`pnpm test`). */
import { assert, assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { ActionResultZ, BatchPartZ, ChoicesPartZ, DayGuidancePartZ, HomePayloadZ, MealDetailZ, MealPickerPartZ, NdjsonExchangeZ, RecentMealZ, ShoppingListPartZ, StaplesPartZ, VanaPartZ } from '../../_shared/vana/schemas.ts';
import { z } from 'npm:zod@3';

const dir = new URL('./fixtures/', import.meta.url);
const fixture = (name: string) => JSON.parse(Deno.readTextFileSync(new URL(`${name}.json`, dir)));
function parse<T extends z.ZodTypeAny>(schema: T, value: unknown, label: string): z.infer<T> {
  const r = schema.safeParse(value);
  if (!r.success) throw new Error(`${label} does not match the contract:\n${r.error.issues.slice(0, 8).map((i) => `  ${i.path.join('.') || '<root>'}: ${i.message}`).join('\n')}`);
  return r.data;
}

Deno.test('contract: opener.json is a planning NDJSON exchange whose ui part is a meal_picker', () => {
  const ex = parse(NdjsonExchangeZ, fixture('opener'), 'opener.json');
  assertEquals(ex.headers['x-vana-kind'], 'meal_planning');
  assertEquals(ex.lines.at(-1)?.type, 'done');
  const picker = ex.lines.find((l) => l.type === 'ui' && l.part.kind === 'meal_picker');
  assert(picker, 'the planning opener renders a meal_picker');
  assert(ex.lines.some((l) => l.type === 'status'), 'a status line precedes the tool call');
});

Deno.test('contract: general_turn.json is a general NDJSON exchange ending in done', () => {
  const ex = parse(NdjsonExchangeZ, fixture('general_turn'), 'general_turn.json');
  assertEquals(ex.headers['x-vana-kind'], 'general');
  assertEquals(ex.lines.at(-1)?.type, 'done');
});

Deno.test('contract: single VanaPart fixtures', () => {
  const picker = parse(MealPickerPartZ, fixture('meal_picker'), 'meal_picker.json');
  assertEquals(picker.meals.length, 3);
  parse(ChoicesPartZ, fixture('choices'), 'choices.json');
  const dg = parse(DayGuidancePartZ, fixture('day_guidance'), 'day_guidance.json');
  assertEquals(dg.suggestions.length, 2);
  parse(StaplesPartZ, fixture('staples'), 'staples.json');
  parse(ShoppingListPartZ, fixture('shopping_list'), 'shopping_list.json');
  // every one of them is also a member of the union the Dart parser switches on
  for (const f of ['meal_picker', 'choices', 'day_guidance', 'staples', 'shopping_list']) parse(VanaPartZ, fixture(f), `${f}.json as VanaPart`);
});

Deno.test('contract: action results — batch, confirm_plan, home, meal_detail, recent_meals', () => {
  const batch = parse(ActionResultZ, fixture('batch'), 'batch.json');
  assert(batch.parts.some((p) => p.kind === 'batch'));
  const confirm = parse(ActionResultZ, fixture('confirm_plan'), 'confirm_plan.json');
  const kinds = confirm.parts.map((p) => p.kind);
  assert(kinds.includes('batch') && kinds.includes('shopping_list'), `confirm_plan returns batch + shopping_list, got ${kinds}`);
  const confirmed = confirm.parts.find((p) => p.kind === 'batch');
  assertEquals(parse(BatchPartZ, confirmed, 'confirm batch').plan.status, 'confirmed');

  const home = parse(ActionResultZ, fixture('home'), 'home.json');
  parse(HomePayloadZ, home.home, 'home.json .home');

  const detail = parse(ActionResultZ, fixture('meal_detail'), 'meal_detail.json');
  const md = parse(MealDetailZ, detail.meal, 'meal_detail.json .meal');
  assert(md.methodSteps.length > 0);
  const saved = parse(ActionResultZ, fixture('meal_detail_saved'), 'meal_detail_saved.json');
  assertEquals(parse(MealDetailZ, saved.meal, 'meal_detail_saved.json .meal').meal.source, 'saved');

  const recent = parse(ActionResultZ, fixture('recent_meals'), 'recent_meals.json');
  parse(z.array(RecentMealZ), recent.meals, 'recent_meals.json .meals');
});
