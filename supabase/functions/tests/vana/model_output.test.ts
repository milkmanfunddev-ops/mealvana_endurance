/**
 * The model is sent only what it reads (mp-471; mp-420 clause 5, mp-432).
 *
 * A tool whose result is larger than the model needs answers in two forms: the full part for the app, and a compact
 * form for the model. The app-facing part is the frozen contract fixture, untouched; the model-facing form is a pure
 * function of it, under a stated budget, and the same bytes on replay. No model is called. Producer-shaped data: the
 * frozen fixtures, fattened with the fields the 09-20 audit found on live rows (photo, image tiles, ingredients, a
 * 24-meal "Show more" tail) so the full form is the size the audit measured, not the 2026-08 fixture's.
 */
import { assert, assertEquals, assertNotEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { convertToModelMessages, hasToolCall, type UIMessage } from 'npm:ai@6.0.277';
import { makeVanaTools, modelView, MODEL_BUDGET_CHARS } from '../../_shared/vana/tools.ts';
import { MealPickerPartZ, BatchPartZ, DayGuidancePartZ, StaplesPartZ, ShoppingListPartZ, WeekPartZ } from '../../_shared/vana/schemas.ts';
import { assistantMessageRow, chatStopWhen, partsFromSteps, replayModelMessages } from '../../_shared/vana/chat.ts';
import { ndjsonFromFullStream } from '../../_shared/vana/stream.ts';

const dir = new URL('./fixtures/', import.meta.url);
const fixture = (name: string) => JSON.parse(Deno.readTextFileSync(new URL(`${name}.json`, dir)));
const chars = (v: unknown) => JSON.stringify(v).length;

/** A MealRef as search_meals returns it today: the frozen fixture plus the picture and text fields the audit named. */
// deno-lint-ignore no-explicit-any
const liveMeal = (m: any, i = 0) => ({
  ...m,
  id: `${m.id}-${i}`,
  ingredients: 'chicken thighs 500 g, jasmine rice 300 g, broccoli 2 heads, soy sauce 2 tbsp, sesame oil 1 tbsp, garlic 3 cloves, ginger 1 thumb, spring onions 4, lime 1, chilli flakes 1 tsp, brown sugar 1 tbsp, cornflour 1 tbsp, vegetable oil 2 tbsp, salt, pepper',
  attribution: 'Adapted from "Weeknight Bowls" by Someone Long-Named, published by A Publisher With A Long Name, 2024, under a licence line that runs on',
  photo: { url: `https://images.example.com/photos/${m.id}-${i}/1200x800.jpg?ixid=abcdefghijklmnopqrstuvwxyz0123456789`, credit: 'Photo by A. Photographer on Unsplash', creditUrl: 'https://unsplash.com/@aphotographer?utm_source=mealvana&utm_medium=referral' },
  imageMode: 'dish',
  image: { url: `https://images.example.com/photos/${m.id}-${i}/1200x800.jpg`, license: 'Unsplash', creator: 'A. Photographer', credit: 'Photo by A. Photographer on Unsplash', sourceUrl: 'https://unsplash.com/photos/abc123' },
  imageTiles: [0, 1, 2, 3].map((t) => ({ url: `https://images.example.com/tiles/${m.id}-${i}-${t}.jpg`, name: 'chicken', license: 'CC BY 2.0', creator: 'Someone', sourceUrl: 'https://flickr.com/photos/someone/123', provider: 'flickr' })),
});
// deno-lint-ignore no-explicit-any
const livePicker = (): any => { const base = fixture('meal_picker'); const meals = [...base.meals, ...base.meals].slice(0, 6).map(liveMeal); const more = Array.from({ length: 24 }, (_, i) => liveMeal(base.meals[i % base.meals.length], 100 + i)); return { ...base, meals, chips: ['Lighter ones', 'Show me pasta'], more }; };
// deno-lint-ignore no-explicit-any
const livePlan = (): any => {
  const b = fixture('batch').parts.find((p: { kind: string }) => p.kind === 'batch');
  const meal = b.plan.meals[0];
  const meals = Array.from({ length: 12 }, (_, i) => ({ ...meal, id: `pm-${i}`, name: `${meal.name} ${i}`, position: i, comments: [{ role: 'user', text: 'less spicy next time', at: '2026-09-20T10:00:00Z' }], swapsApplied: i % 3 ? [] : [{ from: 'white rice', to: 'brown rice', effect: '+3g fibre' }] }));
  const shopping = Array.from({ length: 40 }, (_, i) => ({ aisle: ['Produce', 'Meat', 'Dairy', 'Pantry'][i % 4], name: `Item ${i}`, qty: `${100 + i} g`, checked: false, have: i % 7 === 0, fromMealIds: ['pm-0', 'pm-1', 'pm-2'] }));
  const dayNotes = Object.fromEntries(Array.from({ length: 7 }, (_, i) => [`2026-09-0${i + 1}`, 'A full sentence about how this day eats around its session, written for the Plan tab and not for the model.']));
  return { kind: 'batch', plan: { ...b.plan, meals, shopping, dayNotes, days: Object.fromEntries(Array.from({ length: 7 }, (_, i) => [`2026-09-0${i + 1}`, { dinner: { source: 'plan', id: 'pm-0', name: meal.name, kcal: 620, carbsG: 75 } }])) } };
};

// deno-lint-ignore no-explicit-any
const tools = makeVanaTools({} as any, {} as any, 'meal_planning') as Record<string, any>;
// deno-lint-ignore no-explicit-any
const generalTools = makeVanaTools({} as any, {} as any, 'general') as Record<string, any>;
const modelForm = async (tool: string, output: unknown) => { const r = await tools[tool].toModelOutput({ toolCallId: 't1', input: {}, output }); assertEquals(r.type, 'json'); return r.value; };

// ---------------------------------------------------------------- the meal picker (criterion 1)
Deno.test('suggestMeals: the model gets the meals shown and a count of the rest; the app gets the frozen part', async () => {
  const full = livePicker();
  const before = JSON.stringify(full);
  const m = await modelForm('suggestMeals', full);
  assertEquals(JSON.stringify(full), before, 'the app-facing output is not touched');
  assert(MealPickerPartZ.safeParse(full).success, 'the app-facing part still parses against the contract');
  assertEquals(m.kind, 'meal_picker');
  assertEquals(m.meals.length, 6);
  assertEquals(m.moreCount, 24, 'the tail is a count');
  assertEquals(m.more, undefined);
  assertEquals(m.chips, ['Lighter ones', 'Show me pasta'], 'the chips the picker expects ride along — the model named them');
  assertEquals(m.defaultServings, full.defaultServings);
  assertEquals(m.meals[0].id, full.meals[0].id, 'ids are what the model picks by');
  assertEquals(m.meals[0].why, full.meals[0].why, 'the why-line is what the two sentences are written from');
  for (const k of ['photo', 'image', 'imageTiles', 'attribution', 'ingredients', 'swaps', 'allergens', 'dietsOk', 'score']) assertEquals(m.meals[0][k], undefined, `${k} is not sent`);
  assert(chars(full) > 30_000, `the full form is what the audit measured: ${chars(full)} chars`);
  assert(chars(m) <= MODEL_BUDGET_CHARS.meal_picker, `the model form is ${chars(m)} chars, over the ${MODEL_BUDGET_CHARS.meal_picker} budget`);
});

Deno.test('the frozen meal_picker fixture (no tail, no chips) has no invented count or chips', () => {
  const m = modelView(fixture('meal_picker')) as Record<string, unknown>;
  assertEquals(m.moreCount, 0);
  assertEquals('chips' in m, false);
  assertEquals('more' in m, false);
});

// ---------------------------------------------------------------- the other oversized tools (criterion 2), one test per tool
const BATCH_TOOLS = ['getBatch', 'updateBatch', 'swapMeal', 'draftWeek', 'sameAsLastTime'] as const;
for (const t of BATCH_TOOLS) {
  Deno.test(`${t}: a plan goes to the model as its meals and coverage, never its shopping list or day notes`, async () => {
    const full = livePlan();
    const before = JSON.stringify(full);
    const m = await modelForm(t, full);
    assertEquals(JSON.stringify(full), before);
    assert(BatchPartZ.safeParse(full).success, 'the app-facing part still parses');
    assertEquals(m.kind, 'batch');
    assertEquals(m.plan.meals.length, 12);
    const pm = m.plan.meals[0];
    assertEquals(pm.id, 'pm-0'); assertEquals(pm.servings, full.plan.meals[0].servings); assertEquals(pm.servingsLeft, full.plan.meals[0].servingsLeft); assertEquals(pm.mealType, 'dinner');
    assertEquals(pm.comments, ['less spicy next time'], "the athlete's note on a meal is something Vana reads");
    assertEquals(pm.swaps, ['white rice→brown rice']);
    assertEquals(m.plan.coverage, full.plan.coverage);
    assertEquals(m.plan.shoppingItems, 40);
    for (const k of ['shopping', 'dayNotes', 'days', 'dayNotesStale', 'conversationId']) assertEquals(m.plan[k], undefined, `${k} is not sent`);
    assert(chars(full) > 8_000, `full form ${chars(full)}`);
    assert(chars(m) <= MODEL_BUDGET_CHARS.batch, `the model form is ${chars(m)} chars, over the ${MODEL_BUDGET_CHARS.batch} budget`);
  });
}

Deno.test('dayGuidance: the two suggestions go compact; the label, note and carb floor stay', async () => {
  const base = fixture('day_guidance');
  const full = { ...base, suggestions: base.suggestions.map(liveMeal) };
  const m = await modelForm('dayGuidance', full);
  assert(DayGuidancePartZ.safeParse(full).success);
  assertEquals([m.kind, m.date, m.label, m.workout, m.minCarbsG, m.note], [full.kind, full.date, full.label, full.workout, full.minCarbsG, full.note]);
  assertEquals(m.suggestions.length, 2);
  assertEquals(m.suggestions[0].photo, undefined);
  assertEquals(m.suggestions[0].why, full.suggestions[0].why);
  assert(chars(m) <= MODEL_BUDGET_CHARS.day_guidance, `${chars(m)} > ${MODEL_BUDGET_CHARS.day_guidance}`);
  // the general set carries the same tool with the same form
  assertEquals(await generalTools.dayGuidance.toModelOutput({ toolCallId: 't', input: {}, output: full }), { type: 'json', value: m });
});

Deno.test('diagnoseStaples: six staples go compact with how often they were logged and whether they are ticked', async () => {
  const base = fixture('staples');
  const full = { ...base, meals: Array.from({ length: 6 }, (_, i) => ({ ...liveMeal(base.meals[0], i), timesLogged: 6 - i, ticked: i < 2 })), planCarbsPerDay: 220, targetCarbsPerDay: 344, covered: 4, of: 14 };
  const m = await modelForm('diagnoseStaples', full);
  assert(StaplesPartZ.safeParse(full).success);
  assertEquals(m.meals.length, 6);
  assertEquals([m.meals[0].timesLogged, m.meals[0].ticked, m.meals[5].ticked], [6, true, false]);
  assertEquals(m.meals[0].ingredients, undefined);
  assertEquals([m.planCarbsPerDay, m.targetCarbsPerDay, m.covered, m.of], [220, 344, 4, 14]);
  assert(chars(m) <= MODEL_BUDGET_CHARS.staples, `${chars(m)} > ${MODEL_BUDGET_CHARS.staples}`);
});

for (const t of ['confirmPlan', 'shoppingList'] as const) {
  Deno.test(`${t}: a 40-item shopping list goes to the model by aisle, one line an item`, async () => {
    const full = { kind: 'shopping_list', items: livePlan().plan.shopping, itemCount: 34, skipped: ['Item 0', 'Item 7'] };
    const m = await modelForm(t, full);
    assert(ShoppingListPartZ.safeParse(full).success);
    assertEquals([m.kind, m.itemCount, m.skipped], ['shopping_list', 34, ['Item 0', 'Item 7']]);
    assertEquals(m.items, undefined);
    assertEquals(Object.keys(m.aisles), ['Produce', 'Meat', 'Dairy', 'Pantry']);
    assertEquals(m.aisles.Produce[0], 'Item 0 · 100 g');
    assertEquals(m.aisles.Produce.length, 10);
    assert(chars(m) <= MODEL_BUDGET_CHARS.shopping_list, `${chars(m)} > ${MODEL_BUDGET_CHARS.shopping_list}`);
  });
}

Deno.test('planWeek: seven days go to the model as one line a day, meal names only', async () => {
  const base = fixture('week');
  const day = base.days[0];
  const full = { kind: 'week', periodDays: 7, days: Array.from({ length: 7 }, (_, i) => ({ ...day, date: `2026-09-0${i + 1}`, slots: { breakfast: { source: 'library', id: 'B-001', name: 'Oats & berries', kcal: 420, carbsG: 70 }, lunch: { source: 'plan', id: 'pm-1', name: 'Lentil salad', kcal: 520, carbsG: 60 }, dinner: day.slots.dinner, snack: null }, filled: ['breakfast', 'lunch', 'dinner'] })) };
  const m = await modelForm('planWeek', full);
  assert(WeekPartZ.safeParse(full).success);
  assertEquals(m.periodDays, 7);
  assertEquals(m.days.length, 7);
  assertEquals(m.days[0], { date: '2026-09-01', label: day.label, breakfast: 'Oats & berries', lunch: 'Lentil salad', dinner: day.slots.dinner.name, snack: null });
  assert(chars(m) <= MODEL_BUDGET_CHARS.week, `${chars(m)} > ${MODEL_BUDGET_CHARS.week}`);
});

Deno.test('every tool has a model-facing form, and a part that is not oversized passes through unchanged', async () => {
  for (const [name, t] of Object.entries({ ...tools, ...generalTools })) assert(typeof t.toModelOutput === 'function', `${name} has no toModelOutput`);
  for (const f of ['choices', 'hand_off', 'feedback_saved', 'receipt', 'needs_confirmation', 'pantry', 'debrief']) {
    const part = fixture(f);
    assertEquals(modelView(part), part, `${f} is sent as it is`);
  }
  assertEquals(await tools.askChoice.toModelOutput({ toolCallId: 't', input: {}, output: fixture('choices') }), { type: 'json', value: fixture('choices') });
  // A data tool's plain output is sent as it is, and nothing is null-ed or stringified on the way.
  assertEquals(await tools.getSetting.toModelOutput({ toolCallId: 't', input: {}, output: { key: 'batch_cooking', value: null, default: true } }), { type: 'json', value: { key: 'batch_cooking', value: null, default: true } });
  assertEquals(modelView(undefined), null, 'an undefined output is null, as the SDK would send it');
});

// ---------------------------------------------------------------- replay (criterion 3)
const storedPickerMessage = (output: unknown): UIMessage => ({ id: 'a1', role: 'assistant', parts: [{ type: 'text', text: 'Three dinners for a hill-repeat week.' }, { type: 'tool-suggestMeals', toolCallId: 'call-1', state: 'output-available', input: { mealType: 'dinner' }, output }] } as unknown as UIMessage);

Deno.test('replay sends the compact form: a stored picker with its 24-meal tail reaches the model as the meals shown plus a count', async () => {
  const full = livePicker();
  const messages: UIMessage[] = [{ id: 'u1', role: 'user', parts: [{ type: 'text', text: 'Something quick' }] } as UIMessage, storedPickerMessage(full), { id: 'u2', role: 'user', parts: [{ type: 'text', text: 'Other options' }] } as UIMessage];
  const model = await replayModelMessages(messages, tools);
  const toolMsg = model.find((m) => m.role === 'tool');
  assert(toolMsg, 'the tool result is replayed');
  const result = (toolMsg.content as { type: string; output: { type: string; value: unknown } }[]).find((c) => c.type === 'tool-result')!;
  assertEquals(result.output.type, 'json');
  assertEquals(result.output.value, modelView(full), 'the replayed form is the pure function of the stored part');
  assert(chars(result.output.value) <= MODEL_BUDGET_CHARS.meal_picker);
  assert(!JSON.stringify(model).includes('imageTiles'), 'no picture field reaches the model');
  // the same input replays as the same bytes (mp-420 clause 5)
  assertEquals(JSON.stringify(await replayModelMessages(messages, tools)), JSON.stringify(model));
  // and the stored message itself was not touched
  assertEquals(((messages[1].parts[1] as { output: unknown }).output as { more: unknown[] }).more.length, 24);
});

Deno.test('replay without the tools would send the whole part — the seam the ticket closes', async () => {
  const full = livePicker();
  const bare = await convertToModelMessages([storedPickerMessage(full)]);
  const withTools = await replayModelMessages([storedPickerMessage(full)], tools);
  assert(JSON.stringify(bare).includes('imageTiles'));
  assert(chars(bare) > chars(withTools) * 5, `bare ${chars(bare)} vs compact ${chars(withTools)}`);
});

Deno.test('replay: a legacy row (tool-legacy) and a part with no tool of that name are sent as stored', async () => {
  const part = fixture('choices');
  const legacy = { id: 'a0', role: 'assistant', parts: [{ type: 'text', text: 'Hi' }, { type: 'tool-legacy', toolCallId: 'a0:0', state: 'output-available', input: {}, output: part }] } as unknown as UIMessage;
  const model = await replayModelMessages([legacy], tools);
  const result = (model.find((m) => m.role === 'tool')!.content as { output: { value: unknown } }[])[0];
  assertEquals(result.output.value, part);
});

// ---------------------------------------------------------------- the picker message is stored once (criterion 3)
Deno.test('the assistant row holds the picker once: in parts, never again under metadata.ui_parts', () => {
  const full = livePicker();
  const steps = [{ text: 'Three dinners.', toolCalls: [{ toolName: 'suggestMeals' }], toolResults: [{ toolName: 'suggestMeals', toolCallId: 'c1', input: {}, output: full }] }];
  const { parts } = partsFromSteps('', steps, 8);
  const row = assistantMessageRow({ conversationId: 'conv-1', userId: 'u-1', text: 'Three dinners.', parts, steps, started: Date.now() - 1200, opener: false, openerVariant: 'plan', newPlan: false, kind: 'meal_planning', planSnapshot: null });
  const json = JSON.stringify(row);
  const id = full.meals[0].id;
  assertEquals(json.split(`"${id}"`).length - 1, 1, 'the first shown meal appears once in the stored row');
  assertEquals((row.metadata as Record<string, unknown>).ui_parts, undefined);
  assertEquals((row.metadata as Record<string, unknown>).tool_calls, ['suggestMeals']);
  assertEquals(row.content, 'Three dinners.');
  assertEquals((row.parts as unknown[]).length, 2);
  assertEquals(row.role, 'assistant');
  assertEquals(row.conversation_id, 'conv-1');
});

Deno.test('a row with no parts still carries its text as content, so an old reader has something to show', () => {
  const row = assistantMessageRow({ conversationId: 'c', userId: 'u', text: 'One line. Two lines.', parts: [], steps: [], started: Date.now(), opener: true, openerVariant: 'checkin', newPlan: false, kind: 'meal_planning', planSnapshot: null });
  assertEquals(row.content, 'One line. Two lines.');
  assertEquals((row.metadata as Record<string, unknown>).opener_variant, 'checkin');
});

// ---------------------------------------------------------------- a turn ends when Vana asks a choice, hands off, or saves feedback silently (criterion 4)
type Step = { toolCalls: { toolName: string }[]; usage?: { totalTokens?: number } };
const step = (...names: string[]): Step => ({ toolCalls: names.map((toolName) => ({ toolName })) });
/** How the pinned SDK evaluates `stopWhen`: every condition gets `{ steps }`, any true ends the loop. */
const stops = async (conds: ReturnType<typeof chatStopWhen>, steps: Step[]) => (await Promise.all(conds.map((c) => c({ steps } as never)))).some(Boolean);

Deno.test('the stop conditions, against the pinned SDK: askChoice ends the turn, a picker does not', async () => {
  const planning = chatStopWhen(false, false);
  assertEquals(await stops(planning, [step('askChoice')]), true, 'an opener that asked its question is done — no second step');
  assertEquals(await stops(planning, [step('suggestMeals')]), false, 'the sentence after a picker still needs its step');
  assertEquals(await stops(planning, [step()]), false, 'a text-only step never had a tool to stop on');
  assertEquals(await stops(planning, [step('setSetting'), step('askChoice')]), true, 'rule 4: setSetting then the next fork, stopped on the fork');
  assertEquals(await stops(planning, [step('setSetting')]), false);
  assertEquals(await stops(planning, [step('askChoice'), step('suggestMeals')]), false, 'only the LAST step is looked at, as hasToolCall does');
  assertEquals(await stops(planning, [step('recordDebrief'), step('suggestMeals')]), false);
});

Deno.test('the stop conditions: a hand-off ends the turn in the general set', async () => {
  const general = chatStopWhen(true, false);
  assertEquals(await stops(general, [step('handOff')]), true);
  assertEquals(await stops(general, [step('getWorkouts'), step('handOff')]), true);
  assertEquals(await stops(general, [step('getWorkouts')]), false);
});

Deno.test('the stop conditions: feedback ends the turn only when it is answered by the row alone', async () => {
  assertEquals(await stops(chatStopWhen(true, true), [step('saveFeedback')]), true, 'a pure vent: the row is the reply, no step to write a dropped apology');
  assertEquals(await stops(chatStopWhen(true, false), [step('saveFeedback')]), false, 'a complaint with a question still gets its answering step');
  assertEquals(await stops(chatStopWhen(false, true), [step('saveFeedback')]), true);
});

Deno.test('the stop conditions keep the step limit and the token ceiling', async () => {
  const planning = chatStopWhen(false, false); const general = chatStopWhen(true, false);
  assertEquals(await stops(planning, Array.from({ length: 6 }, () => step('searchMeals'))), true);
  assertEquals(await stops(planning, Array.from({ length: 5 }, () => step('searchMeals'))), false);
  assertEquals(await stops(general, Array.from({ length: 8 }, () => step('searchMeals'))), true);
  assertEquals(await stops(general, [{ toolCalls: [], usage: { totalTokens: 150_000 } }]), true);
  // the conditions are the SDK's own hasToolCall, not a look-alike
  assertEquals(await hasToolCall('askChoice')({ steps: [step('askChoice')] } as never), true);
});

Deno.test('a general-mode step whose only tools are terminal keeps its sentence — it is what the question or hand-off is about', () => {
  const handOff = { text: 'The meal-planning page builds the week with you.', toolCalls: [{ toolName: 'handOff' }], toolResults: [{ toolName: 'handOff', toolCallId: 'c1', input: {}, output: fixture('hand_off') }] };
  const { parts } = partsFromSteps('', [handOff], null);
  assertEquals(parts.map((p) => (p as { type: string }).type), ['text', 'tool-handOff']);
  // narration before a data tool is still dropped
  const fetched = partsFromSteps('', [{ text: "I'll pull up your plan.", toolCalls: [{ toolName: 'getWorkouts' }], toolResults: [] }, { text: 'Two runs this week.', toolCalls: [], toolResults: [] }], null);
  assertEquals(fetched.parts.map((p) => (p as { text?: string }).text), ['Two runs this week.']);
});

// ---------------------------------------------------------------- the done line says how many model steps the turn took (the eval reads it)
async function* oneStep() {
  yield { type: 'start-step' }; yield { type: 'text-start' }; yield { type: 'text-delta', text: 'Sunday is your long ride.' };
  yield { type: 'tool-input-start', toolName: 'askChoice' }; yield { type: 'tool-result', output: fixture('choices') };
  yield { type: 'finish-step' }; yield { type: 'finish', totalUsage: { inputTokens: 15_000, outputTokens: 80, inputTokenDetails: { cacheReadTokens: 14_000 } } };
}
async function* twoSteps() {
  yield { type: 'start-step' }; yield { type: 'tool-input-start', toolName: 'getWorkouts' }; yield { type: 'tool-result', output: [] }; yield { type: 'finish-step' };
  yield { type: 'start-step' }; yield { type: 'text-start' }; yield { type: 'text-delta', text: 'Two runs.' }; yield { type: 'finish-step' };
  yield { type: 'finish', totalUsage: { inputTokens: 30_000, outputTokens: 40 } };
}
const lastLine = async (s: AsyncIterable<unknown>) => { const body = await new Response(ndjsonFromFullStream(s)).text(); return JSON.parse(body.trim().split('\n').at(-1)!); };
Deno.test('done.usage.steps counts the model steps of the turn', async () => {
  assertEquals(await lastLine(oneStep()), { type: 'done', usage: { input_tokens: 15_000, output_tokens: 80, cache_read_tokens: 14_000, steps: 1 } });
  assertEquals((await lastLine(twoSteps())).usage.steps, 2);
});

Deno.test('a compact form is smaller than the full one for every oversized kind, and the budgets are stated', () => {
  for (const kind of ['meal_picker', 'batch', 'day_guidance', 'staples', 'shopping_list', 'week'] as const) assert(MODEL_BUDGET_CHARS[kind] > 0, `${kind} has a budget`);
  assertNotEquals(chars(modelView(livePicker())), chars(livePicker()));
});
