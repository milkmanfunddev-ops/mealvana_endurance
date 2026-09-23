/**
 * The picker's own chips fetch the next picker with no model turn (mp-464, approved as mp-477; ai-cost ticket 12).
 *
 * The seam is `vana-action`'s `next_picker` with a `chip` on the payload, run through `extraAction` and `runTapped` the
 * way the function runs it, over the fake database. `search_meals` is the one collaborator faked, as the database
 * answers it (producer-shaped rows), and it records what it was asked. No model is called anywhere in this file.
 *
 * Claims:
 *   1. "Other options" returns the next picker for the SAME meal type with the SAME filters, leaving out every meal the
 *      conversation already showed; the part parses against the picker's frozen contract (meal_picker.json's schema).
 *   2. "No recipe only" and "Under 20 min" are fixed picker arguments from ONE table, laid over the last picker's own.
 *   3. "I like these" / "Next" draw the next meal type's picker when that is the whole next step, and hand the tap back
 *      to Vana — nothing run, stored or logged — when the next step is a fork question or the wrap-up.
 *   4. The tap and the picker are stored as a textless suggestMeals call Vana replays on her next turn, logged as a tap
 *      that drew nothing, and the next chip reads the filters it was drawn with.
 *   5. The persona no longer carries the tapped picker chips as hers, and stays under ticket 11's size.
 *
 * Run: deno test --allow-all supabase/functions/tests/vana/picker_chips.test.ts
 */
import { assert, assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { PICKER_CHIP_ARGS, pickerNextStep, runTapped, NO_MODEL } from '../../_shared/vana/chips.ts';
import { extraAction } from '../../_shared/vana/actions.ts';
import { conversationMessages, replayModelMessages } from '../../_shared/vana/chat.ts';
import { makeVanaTools, DEFAULT_PICKER_TITLE } from '../../_shared/vana/tools.ts';
import { PLANNING_PROMPT } from '../../_shared/vana/persona.ts';
import { MealPickerPartZ } from '../../_shared/vana/schemas.ts';
import { today, weekStartFor } from '../../_shared/vana/env.ts';
import type { MealType, VanaPart } from '../../_shared/vana/contracts.ts';
import { testCtx, TEST_USER_ID } from './support/vana_ctx.ts';
import type { Row, Tables } from './support/fake_db.ts';

const U = TEST_USER_ID;
const CONV = 'conv-picker-chips';
const PLAN = 'aaaaaaaa-0000-4000-8000-000000000121';
const fixture = JSON.parse(Deno.readTextFileSync(new URL('./fixtures/meal_picker.json', import.meta.url)));
type Picker = Extract<VanaPart, { kind: 'meal_picker' }>;

/** A library row as `search_meals` returns it: snake_case, scored. */
const libRow = (id: string, mealType: MealType, over: Record<string, unknown> = {}): Row => ({ source: 'library', id, name: `Meal ${id}`, meal_type: mealType, contexts: ['everyday'], batch: true, prep_minutes: 15, kcal: 600, carbs_g: 70, protein_g: 35, fat_g: 15, allergens: [], diets_ok: [], swaps: null, why: 'fits the week', attribution: 'the library', ingredients: 'rice, beans', library_meal_id: id, score: 0.9, kind: 'recipe', ...over });
/** Twelve meals per type: enough for a picker and a tail, so what is left out is visible. */
const LIBRARY: Row[] = (['dinner', 'lunch', 'breakfast', 'snack'] as MealType[]).flatMap((t) => Array.from({ length: 12 }, (_, i) => libRow(`${t[0].toUpperCase()}-${String(i + 1).padStart(3, '0')}`, t)));

const conversation = (): Row => ({ id: CONV, user_id: U, kind: 'meal_planning', title: null, summary: null, is_deleted: false, last_message_at: '2026-09-23T09:00:00Z', created_at: '2026-09-23T09:00:00Z' });
const planRow = (): Row => ({ id: PLAN, user_id: U, week_start: weekStartFor(today()), status: 'draft', batch_cooking: true, conversation_id: CONV, brief: null, rules: [], shopping: [], day_notes: {}, day_notes_stale: false, is_deleted: false, updated_at: '2026-09-23T09:00:00Z' });
const planMeal = (id: string, mealType: MealType, libraryMealId: string): Row => ({ id, plan_id: PLAN, user_id: U, source: 'library', library_meal_id: libraryMealId, saved_meal_id: null, name: id, meal_type: mealType, session: null, servings: 3, servings_left: 3, kcal: 600, carbs_g: 70, protein_g: 35, fat_g: 15, swaps_applied: [], comments: [], position: 0, icon: null, created_at: '2026-09-23T09:00:00Z' });
const setting = (key: string, value: unknown): Row => ({ id: `mem-${key}`, user_id: U, kind: 'setting', key, value, fact: key, confidence: 1, source: 'conversation', is_deleted: false, last_confirmed_at: '2026-09-20T09:00:00Z' });
/** Vana's picker turn as chat.ts stores it: a sentence and the suggestMeals call with its input and its part. */
const vanaPicker = (input: Record<string, unknown>, output: unknown, i = 0): Row => ({ id: `a-${i}`, conversation_id: CONV, user_id: U, role: 'assistant', content: 'Carbs before Thursday.', created_at: new Date(Date.UTC(2026, 8, 23, 9, 0, i)).toISOString(), metadata: { tool_calls: ['suggestMeals'] }, parts: [{ type: 'text', text: 'Carbs before Thursday.' }, { type: 'tool-suggestMeals', toolCallId: `call-${i}`, state: 'output-available', input, output }] });

/** The frozen fixture's picker, relabelled onto this library so its meals are ones the search can return. */
const shownDinners = (): Picker => ({ ...fixture, mealType: 'dinner', meals: fixture.meals.slice(0, 3).map((m: Record<string, unknown>, i: number) => ({ ...m, id: `D-00${i + 1}`, source: 'library', mealType: 'dinner' })) });

// deno-lint-ignore no-explicit-any
interface World { search?: (args: any) => Row[]; settled?: boolean; walk?: MealType[]; planMeals?: Row[]; pickerInput?: Record<string, unknown>; picker?: Picker }
function world(w: World = {}) {
  const asked: Record<string, unknown>[] = [];
  const memories = w.settled === false ? [] : [setting('batch_cooking', true), setting('coverage_scope', 'dinners_lunches')];
  if (w.walk) memories.push(setting('meal_types', w.walk));
  const tables: Tables = {
    vana_conversations: [conversation()], vana_messages: [vanaPicker(w.pickerInput ?? { title: 'Three dinners to start', mealType: 'dinner', count: 5, kind: 'recipe', query: 'salmon', chips: ['Lighter ones', 'Show me pasta'] }, w.picker ?? shownDinners())],
    vana_calls: [], user_memories: memories, meal_plans: [planRow()], plan_meals: w.planMeals ?? [planMeal('pm1', 'dinner', 'D-001')],
  };
  const v = testCtx(tables, { rpc: { search_meals: (args) => { asked.push(args); return w.search ? w.search(args) : LIBRARY.filter((r) => r.meal_type === args.p_meal_type); } } });
  return { v, asked };
}
/** A tap the way vana-action runs it: the action, then the store-and-log step. */
async function tap(v: ReturnType<typeof world>['v'], chipKind: string, chip: string, extra: Record<string, unknown> = {}) {
  const payload = { conversationId: CONV, chipKind, chip, ...extra };
  return await runTapped(v, 'next_picker', payload, (await extraAction(v, 'next_picker', payload))!);
}
const pickerOf = (r: { parts: VanaPart[] }) => MealPickerPartZ.parse(r.parts[0]) as Picker;

// ---------------------------------------------------------------- 1. "Other options"

Deno.test('"Other options" returns the next picker for the same type and filters, leaving out every meal already shown', async () => {
  const { v, asked } = world();
  const result = await tap(v, 'more', 'Other options');

  assertEquals(result.parts.length, 1);
  const picker = pickerOf(result);   // the frozen contract's schema: the app parses it exactly as Vana's picker
  assertEquals(picker.mealType, 'dinner');
  assertEquals(picker.title, DEFAULT_PICKER_TITLE, 'the tool\'s own default, never a line in her voice');
  assert(!('chips' in picker), 'the chips Vana named were for her picker, not this one');
  const ids = picker.meals.map((m) => m.id);
  for (const gone of ['D-001', 'D-002', 'D-003']) assert(!ids.includes(gone), `${gone} was already shown or is in the plan`);
  assertEquals(picker.meals.length, 5, 'the same count as the picker it follows');
  // The same search: same type, same query, same kind; the plan and the shown meals left out.
  assertEquals(asked.length, 1);
  assertEquals(asked[0].p_meal_type, 'dinner');
  assertEquals(asked[0].p_query, 'salmon');
  assertEquals(asked[0].p_kind, 'recipe');
  assert(!('toVana' in result));
  assert(!('toolInput' in result), 'the stored call\'s input is the server\'s, the app never sees it');
});

Deno.test('a second "Other options" leaves out the first one\'s meals too: a chip-fetched picker counts as shown', async () => {
  const { v } = world();
  const first = pickerOf(await tap(v, 'more', 'Other options'));
  const second = pickerOf(await tap(v, 'more', 'Other options'));
  for (const m of second.meals) assert(!first.meals.some((x) => x.id === m.id), `${m.id} was on the picker before`);
});

// ---------------------------------------------------------------- 2. the two filters, one table

Deno.test('"No recipe only" and "Under 20 min" are fixed picker arguments from one table', () => {
  assertEquals(PICKER_CHIP_ARGS, { more: {}, no_recipe: { kind: 'assembly' }, under_20: { maxPrepMinutes: 20 } });
});

Deno.test('"No recipe only" asks for assemblies and keeps the rest of the last picker\'s filters', async () => {
  const { v, asked } = world();
  const picker = pickerOf(await tap(v, 'no_recipe', 'No recipe only'));
  assertEquals(picker.mealType, 'dinner');
  assertEquals(asked[0].p_kind, 'assembly');
  assertEquals(asked[0].p_query, 'salmon', 'the query the athlete gave still stands');
});

Deno.test('"Under 20 min" keeps only meals the athlete can make in 20 minutes', async () => {
  // Half the dinners take 45 minutes.
  const { v } = world({ pickerInput: { mealType: 'dinner' }, search: (args) => LIBRARY.filter((r) => r.meal_type === args.p_meal_type).map((r, i) => (i % 2 ? { ...r, prep_minutes: 45 } : r)) });
  const picker = pickerOf(await tap(v, 'under_20', 'Under 20 min'));
  assert(picker.meals.length > 0);
  for (const m of picker.meals) assert(m.prepMinutes != null && m.prepMinutes <= 20, `${m.id} takes ${m.prepMinutes} minutes`);
});

Deno.test('a filter tapped after a filter keeps both: the stored tap carries the arguments it was drawn with', async () => {
  const { v, asked } = world({ pickerInput: { mealType: 'dinner' } });
  await tap(v, 'under_20', 'Under 20 min');
  await tap(v, 'no_recipe', 'No recipe only');
  assertEquals(asked[1].p_kind, 'assembly');
  const assistant = v.fake.rows('vana_messages').filter((r) => r.role === 'assistant').at(-1)!;
  assertEquals(assistant.parts[0].input, { mealType: 'dinner', maxPrepMinutes: 20, kind: 'assembly' });
});

// ---------------------------------------------------------------- 3. "I like these" / "Next"

Deno.test('the step after "I like these": the next open type on the walk, a fork question, or the wrap-up', () => {
  const walk: MealType[] = ['dinner', 'lunch', 'breakfast'];
  const base = { lastType: 'dinner' as MealType, walk, covered: new Set<MealType>(['dinner']), batchKnown: true, coverageScope: 'all' };
  assertEquals(pickerNextStep(base), { step: 'picker', mealType: 'lunch' });
  assertEquals(pickerNextStep({ ...base, covered: new Set<MealType>(['dinner', 'lunch']) }), { step: 'picker', mealType: 'breakfast' });
  assertEquals(pickerNextStep({ ...base, lastType: 'breakfast', covered: new Set<MealType>(['dinner', 'breakfast']) }), { step: 'picker', mealType: 'lunch' }, 'a type skipped earlier comes round again');
  assertEquals(pickerNextStep({ ...base, named: 'breakfast' }), { step: 'picker', mealType: 'breakfast' }, 'the type the chip named, when it is open');
  assertEquals(pickerNextStep({ ...base, named: 'snack' }), { step: 'picker', mealType: 'lunch' }, 'a named type off the walk is not followed');
  assertEquals(pickerNextStep({ ...base, batchKnown: false }), { step: 'ask' }, 'batch never chosen: Vana asks');
  assertEquals(pickerNextStep({ ...base, coverageScope: null }), { step: 'ask' }, 'coverage never chosen: Vana asks');
  assertEquals(pickerNextStep({ ...base, covered: new Set<MealType>(['dinner', 'lunch', 'breakfast']) }), { step: 'wrap_up' });
  assertEquals(pickerNextStep({ ...base, walk: ['dinner'] }), { step: 'wrap_up' }, 'dinners only: nothing after dinner');
});

Deno.test('"Next: Lunch" with both forks settled draws the lunch picker with no model, and stores the tap', async () => {
  const { v, asked } = world();
  const result = await tap(v, 'next', 'Next: Lunch', { mealType: 'lunch' });
  const picker = pickerOf(result);
  assertEquals(picker.mealType, 'lunch');
  assertEquals(asked[0].p_meal_type, 'lunch');
  assertEquals(asked[0].p_query, null, 'a new type starts from the week, not from the dinner filters');
  assertEquals(asked[0].p_kind, null);
  assert(typeof result.messageId === 'string' && typeof result.tapMessageId === 'string');
});

Deno.test('"I like these" with a fork never chosen goes to Vana: nothing searched, stored or logged', async () => {
  const { v, asked } = world({ settled: false });
  const before = v.fake.rows('vana_messages').length;
  const result = await tap(v, 'next', 'I like these');
  assertEquals(result, { parts: [], toVana: true, reason: 'ask' });
  assertEquals(asked, []);
  assertEquals(v.fake.rows('vana_messages').length, before);
  assertEquals(v.fake.writesTo('vana_calls', 'insert'), []);
});

Deno.test('"I like these" with every type on the walk covered goes to Vana for the wrap-up', async () => {
  const { v } = world({ planMeals: [planMeal('pm1', 'dinner', 'D-001'), planMeal('pm2', 'lunch', 'L-001')] });
  assertEquals(await tap(v, 'next', 'I like these'), { parts: [], toVana: true, reason: 'wrap_up' });
  assertEquals(v.fake.writesTo('vana_calls', 'insert'), []);
});

Deno.test('the walk the athlete chose decides the next type', async () => {
  const { v } = world({ walk: ['dinner', 'breakfast'] });
  assertEquals(pickerOf(await tap(v, 'next', 'I like these')).mealType, 'breakfast');
});

// ---------------------------------------------------------------- 4. stored and logged

Deno.test('the tap and its picker are stored as a textless suggestMeals call and logged as a free tap', async () => {
  const { v } = world();
  await tap(v, 'more', 'Other options');
  const [user, assistant] = v.fake.rows('vana_messages').slice(1);
  assertEquals(user.content, 'Other options');
  assertEquals(user.metadata, { input_mode: 'tap', tap: 'next_picker' });
  assertEquals(assistant.content, '', 'Vana writes no line');
  assertEquals(assistant.parts.map((p: { type: string }) => p.type), ['tool-suggestMeals'], 'no text part: nothing in her voice');
  assertEquals(assistant.parts[0].output.kind, 'meal_picker');
  assertEquals(assistant.parts[0].input, { mealType: 'dinner', query: 'salmon', count: 5, kind: 'recipe' }, 'the filters, not the wire payload');

  const calls = v.fake.writesTo('vana_calls', 'insert').map((w) => w.values);
  assertEquals(calls.length, 1);
  assertEquals(calls[0].function_name, 'vana.tap.next_picker.meal_planning');
  assertEquals(calls[0].model, NO_MODEL);
  assertEquals([calls[0].input_tokens, calls[0].output_tokens, calls[0].gateway_cost_usd, calls[0].debited, calls[0].input_mode], [0, 0, 0, false, 'tap']);
});

Deno.test('Vana\'s next turn reads the tapped picker as her own suggestMeals call, in its compact form', async () => {
  const { v } = world();
  await tap(v, 'more', 'Other options');
  const tools = makeVanaTools(v, {} as never, 'meal_planning');
  const sent = await replayModelMessages((await conversationMessages(v, CONV)).messages, tools);
  assertEquals(sent.map((m) => m.role), ['assistant', 'tool', 'user', 'assistant', 'tool']);
  const call = sent[3].content as unknown as { type: string; toolName: string }[];
  assertEquals(call.map((c) => [c.type, c.toolName]), [['tool-call', 'suggestMeals']]);
  const result = sent[4].content as unknown as { output: { value: { kind: string; moreCount?: number; more?: unknown } } }[];
  assertEquals(result[0].output.value.kind, 'meal_picker');
  assert(!('more' in result[0].output.value), 'the model reads the tiles and a count, never the tail');
});

// ---------------------------------------------------------------- 5. the persona

Deno.test('the persona no longer handles the tapped picker chips, keeps the typed asks and "Different protein", and stays small', () => {
  for (const gone of ['"Other options" / "something different"', '"No recipe only" → kind', '"Under 20 min" / "quick"']) assert(!PLANNING_PROMPT.includes(gone), `no longer in the persona: ${gone}`);
  for (const kept of ['something different', 'Different protein', 'maxPrepMinutes 20', 'kind "assembly"', '"I like these" / "Next: <type>"']) assert(PLANNING_PROMPT.includes(kept), `still in the persona: ${kept}`);
  assert(PLANNING_PROMPT.length < 15094, `the planning persona is ${PLANNING_PROMPT.length} characters`);
});
