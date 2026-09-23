/**
 * Chips with one fixed meaning act at once, with no model turn (mp-464, ai-cost ticket 11).
 *
 * The seam is `vana-action` with a `chip` on the payload: the action runs as it always did, and then the tap and what
 * it produced are stored in the conversation, logged as a tap that drew nothing, and read back by the next turn as if
 * Vana had called the tool herself. No model is called anywhere in this file.
 *
 * Claims:
 *   1. The stored turn: a user row holding the label, an assistant row with NO text and the result as a tool part
 *      named after the tool the chip stands in for, the draft snapshot for rewind, and the conversation touched.
 *   2. The replay: the next turn reads the tap as a tool call plus its compact result (mp-471), an earlier prefix stays
 *      byte-for-byte what it was (ticket 07), and a tap with no part (the shopping list opening) still tells Vana what
 *      happened.
 *   3. The log: one `vana_calls` row per tap, no model, zero tokens, zero charge, `input_mode` 'tap', not debited.
 *   4. The actions themselves: the settle and navigate chips answer on the no-model endpoint; a label on a chip the
 *      endpoint does not act at once for stores nothing.
 *   5. The persona: the fixed labels it must use, and the chip instructions it no longer carries.
 *
 * Run: deno test --allow-read --allow-write --allow-env --allow-sys --node-modules-dir=none \
 *        supabase/functions/tests/vana/fixed_chips.test.ts
 */
import { assert, assertEquals, assertNotEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import type { UIMessage } from 'npm:ai@6.0.277';
import { CHIP_LABELS } from '../../_shared/vana/chip-labels.ts';
import { NO_MODEL, TAP_TOOLS, isTapAction, recordTap, runTapped } from '../../_shared/vana/chips.ts';
import { extraAction, runAction } from '../../_shared/vana/actions.ts';
import { assistantMessageRow, conversationMessages, openerMessage, partsFromSteps, replayModelMessages, userMessageRow, withSituation } from '../../_shared/vana/chat.ts';
import { makeVanaTools } from '../../_shared/vana/tools.ts';
import { OPENERS, PLANNING_PROMPT } from '../../_shared/vana/persona.ts';
import { addDays, today, weekStartFor } from '../../_shared/vana/env.ts';
import type { VanaPart } from '../../_shared/vana/contracts.ts';
import { testCtx, TEST_USER_ID } from './support/vana_ctx.ts';
import type { Row, Tables } from './support/fake_db.ts';

const U = TEST_USER_ID;
const CONV = 'conv-chips';
const PLAN = 'aaaaaaaa-0000-4000-8000-000000000031';
const PREV = 'aaaaaaaa-0000-4000-8000-00000000002f';
// deno-lint-ignore no-explicit-any
const tools = makeVanaTools({} as any, {} as any, 'meal_planning');
const bytes = (m: unknown) => JSON.stringify(m);

const conversation = (): Row => ({ id: CONV, user_id: U, kind: 'meal_planning', title: null, summary: null, is_deleted: false, last_message_at: '2026-09-22T09:00:00Z', created_at: '2026-09-22T09:00:00Z' });
const planRow = (over: Record<string, unknown> = {}): Row => ({ id: PLAN, user_id: U, week_start: weekStartFor(today()), status: 'draft', batch_cooking: true, conversation_id: CONV, brief: null, rules: [], shopping: [], day_notes: {}, day_notes_stale: false, is_deleted: false, updated_at: '2026-09-22T09:00:00Z', ...over });
const mealRow = (id: string, planId: string, mealType: string, libraryMealId: string, servings: number): Row => ({ id, plan_id: planId, user_id: U, source: 'library', library_meal_id: libraryMealId, saved_meal_id: null, name: id, meal_type: mealType, session: null, servings, servings_left: servings, kcal: 700, carbs_g: 70, protein_g: 35, fat_g: 18, swaps_applied: [], comments: [], position: 0, icon: null, created_at: '2026-09-22T09:00:00Z' });
const world = (over: Partial<Tables> = {}): Tables => ({ vana_conversations: [conversation()], vana_messages: [], vana_calls: [], user_memories: [], meal_plans: [planRow()], plan_meals: [], ...over });
const stored = (row: Record<string, unknown>, i: number): Row => ({ id: `m${i}`, created_at: new Date(Date.UTC(2026, 8, 22, 9, 0, i)).toISOString(), ...row });
/** A finished step the way the SDK hands it to onFinish: text and one askChoice with its result. */
const askStep = (text: string, toolCallId: string, options: string[]) => ({ text, toolCalls: [{ toolName: 'askChoice' }], toolResults: [{ toolName: 'askChoice', toolCallId, input: { options }, output: { kind: 'choices', question: undefined, options } }] });

const SETTING_PART: VanaPart = { kind: 'memory_saved', memory: { id: 'mem-1', kind: 'setting', key: 'coverage_scope', fact: 'Plans dinners only', value: 'dinners', confidence: 1, lastConfirmedAt: '2026-09-22T09:00:01Z', source: 'settings' } };

// ---------------------------------------------------------------- 1. the stored turn

Deno.test('a tap stores the label as the athlete\'s turn and the result as a textless tool call, with the draft snapshot', async () => {
  const v = testCtx(world({ plan_meals: [mealRow('pm1', PLAN, 'dinner', 'D-001', 3)] }));
  const ids = await recordTap(v, { conversationId: CONV, label: CHIP_LABELS.coverageDinners, type: 'set_setting', input: { key: 'coverage_scope', value: 'dinners' }, parts: [SETTING_PART] });

  const rows = v.fake.rows('vana_messages');
  assertEquals(rows.map((r) => r.role), ['user', 'assistant']);
  const [user, assistant] = rows;
  assertEquals(user.content, CHIP_LABELS.coverageDinners);
  assertEquals(user.metadata, { input_mode: 'tap', tap: 'set_setting' });
  assertEquals(assistant.content, '', 'Vana writes no line');
  assertEquals(assistant.parts.length, 1, 'no text part either — nothing templated in her voice');
  assertEquals(assistant.parts[0].type, 'tool-setSetting', 'stored as the tool the chip stands in for');
  assertEquals(assistant.parts[0].state, 'output-available');
  assertEquals(assistant.parts[0].input, { key: 'coverage_scope', value: 'dinners' });
  assertEquals(assistant.parts[0].output, SETTING_PART);
  assertEquals(assistant.metadata.tap, 'set_setting');
  assertEquals(assistant.metadata.tool_calls, ['setSetting']);
  assertEquals(assistant.metadata.plan_snapshot.map((m: { id: string; servings: number }) => [m.id, m.servings]), [['D-001', 3]], 'an edit-rewind past this tap restores the draft as it stood');
  assertEquals(ids, { tapMessageId: user.id, messageId: assistant.id });
  assertNotEquals(v.fake.rows('vana_conversations')[0].last_message_at, '2026-09-22T09:00:00Z', 'the conversation is touched');
});

// ---------------------------------------------------------------- 2. the replay

Deno.test('the next turn reads the tap as a setSetting call with its result, and the earlier prefix replays byte-for-byte', async () => {
  const v = testCtx(world());
  // Turn 1: the opener asked the coverage fork.
  const step = askStep('Chattanooga is 11 days out.', 'call-1', [CHIP_LABELS.coverageDinners, CHIP_LABELS.coverageDinnersLunches, CHIP_LABELS.coverageAll]);
  v.fake.tables.vana_messages.push(stored(assistantMessageRow({ conversationId: CONV, userId: U, text: step.text, parts: partsFromSteps('', [step], 8).parts, steps: [step], started: Date.now(), opener: true, openerVariant: 'plan', newPlan: false, kind: 'meal_planning', planSnapshot: null, openerPrompt: OPENERS.meal_planning, situation: null }), 0));
  const before = await replayModelMessages((await conversationMessages(v, CONV)).messages, tools);
  // The tap.
  await recordTap(v, { conversationId: CONV, label: CHIP_LABELS.coverageDinners, type: 'set_setting', input: { key: 'coverage_scope', value: 'dinners' }, parts: [SETTING_PART] });
  // Turn 3: what the next turn sends.
  const history = (await conversationMessages(v, CONV)).messages;
  const next = { id: 'u-2', role: 'user', parts: [{ type: 'text', text: 'Next: lunch' }] } as UIMessage;
  const sent = withSituation(await replayModelMessages([...history, next], tools), null);

  assertEquals(bytes(sent.slice(0, before.length)), bytes(before), 'every message before the tap replays as it was');
  const roles = sent.map((m) => m.role);
  assertEquals(roles, ['user', 'assistant', 'tool', 'user', 'assistant', 'tool', 'user'], 'the opener, its question, the tap, its call and result, the new message');
  const tapped = sent[3].content as unknown as { type: string; text?: string }[];
  assertEquals(tapped, [{ type: 'text', text: CHIP_LABELS.coverageDinners }], 'the athlete\'s turn is the label, nothing more');
  const call = sent[4].content as unknown as { type: string; toolName?: string; input?: unknown; text?: string }[];
  assertEquals(call.map((c) => c.type), ['tool-call'], 'no text block: she wrote nothing');
  assertEquals(call[0].toolName, 'setSetting');
  assertEquals(call[0].input, { key: 'coverage_scope', value: 'dinners' });
  const result = sent[5].content as unknown as { type: string; toolName: string; output: { type: string; value: unknown } }[];
  assertEquals(result[0].toolName, 'setSetting');
  assertEquals(result[0].output, { type: 'json', value: SETTING_PART }, 'the same compact form a real call replays in');
  // Read twice, the same bytes: the cached prefix holds across the tap.
  assertEquals(bytes(await replayModelMessages((await conversationMessages(v, CONV)).messages, tools)), bytes(await replayModelMessages((await conversationMessages(v, CONV)).messages, tools)));
});

Deno.test('a tap that produced no part still tells the next turn what the app did', async () => {
  const v = testCtx(world());
  await recordTap(v, { conversationId: CONV, label: CHIP_LABELS.openShoppingList, type: 'open_shopping_list', input: {}, parts: [] });
  const replayed = await replayModelMessages((await conversationMessages(v, CONV)).messages, tools);
  assertEquals(replayed.map((m) => m.role), ['user', 'assistant', 'tool']);
  const result = replayed[2].content as unknown as { toolName: string; output: { value: unknown } }[];
  assertEquals(result[0].toolName, 'openShoppingList');
  assertEquals(result[0].output.value, { kind: 'done', action: 'open_shopping_list' });
  // The assistant row has one tool part and no text: the app draws nothing for an unknown kind, and never a bubble.
  const assistant = v.fake.rows('vana_messages')[1];
  assertEquals(assistant.content, '');
  assertEquals(assistant.parts.map((p: { type: string }) => p.type), ['tool-openShoppingList']);
});

Deno.test('a draft-week tap replays in the batch\'s compact form, like the tool call it stands in for', async () => {
  const v = testCtx(world());
  const plan = { id: PLAN, weekStart: '2026-09-21', status: 'draft', batchCooking: true, brief: null, rules: [], meals: [{ id: 'pm1', planId: PLAN, source: 'library', libraryMealId: 'D-001', savedMealId: null, name: 'Lentil bolognese', mealType: 'dinner', session: null, servings: 3, servingsLeft: 3, kcal: 700, carbsG: 70, proteinG: 35, fatG: 18, swapsApplied: [], comments: [], position: 0 }], shopping: [{ aisle: 'Produce', name: 'tomatoes', qty: '2', checked: false, have: false, fromMealIds: ['pm1'] }], dayNotes: {}, coverage: { lunchDinnerSlots: 7, covered: 3, periodDays: 7, perDay: { kcal: 700, carbsG: 70, proteinG: 35 } } };
  await recordTap(v, { conversationId: CONV, label: 'Draft my whole week', type: 'draft_week', input: {}, parts: [{ kind: 'batch', plan } as VanaPart] });
  const replayed = await replayModelMessages((await conversationMessages(v, CONV)).messages, tools);
  const result = replayed[2].content as unknown as { toolName: string; output: { value: { kind: string; plan: Record<string, unknown> } } }[];
  assertEquals(result[0].toolName, 'draftWeek');
  assertEquals(result[0].output.value.kind, 'batch');
  assertEquals(result[0].output.value.plan.shoppingItems, 1, 'the model gets the count, not the rows');
  assert(!('shopping' in result[0].output.value.plan), 'the full shopping list never rides the replay');
});

// ---------------------------------------------------------------- 3. the log

Deno.test('a tap is logged once: no model, zero tokens, zero charge, tapped, not debited', async () => {
  const v = testCtx(world({ user_entitlements: [{ user_id: U, period_type: 'P1M', active_until: '2026-10-15T00:00:00Z' }] }));
  await recordTap(v, { conversationId: CONV, label: CHIP_LABELS.batchOn, type: 'set_setting', input: { key: 'batch_cooking', value: true }, parts: [SETTING_PART] });
  const rows = v.fake.writesTo('vana_calls', 'insert').map((w) => w.values);
  assertEquals(rows.length, 1);
  const row = rows[0];
  assertEquals(row.function_name, 'vana.tap.set_setting.meal_planning');
  assertEquals(row.model, NO_MODEL);
  assertEquals(row.input_tokens, 0);
  assertEquals(row.output_tokens, 0);
  assertEquals(row.gateway_cost_usd, 0, 'free is the truth here, not "the gateway said nothing"');
  assertEquals(row.steps, 0);
  assertEquals(row.input_mode, 'tap');
  assertEquals(row.debited, false);
  assertEquals(row.conversation_id, CONV);
  assertEquals(row.subscriber_period_type, 'P1M', 'the plan label reads the same columns a chat row carries');
  assert(!row.function_name.startsWith('vana.chat'), 'a tap never joins the chat limiter\'s bucket');
});

// ---------------------------------------------------------------- 4. the actions

Deno.test('every at-once action stands in for a tool of the planning persona, or names what the app did', () => {
  const names = new Set(Object.keys(tools));
  for (const [type, tool] of Object.entries(TAP_TOOLS)) {
    if (type === 'open_shopping_list' || type === 'set_pantry') continue;   // no tool: the app did it, and the model reads the JSON
    assert(names.has(tool), `${type} → ${tool} is a real tool, so its replay is the compact form`);
  }
  for (const type of ['draft_week', 'same_as_last_time', 'set_setting', 'plan_week', 'ask_pantry', 'set_pantry', 'open_shopping_list']) assert(isTapAction(type), `${type} acts at once`);
  for (const type of ['pick_meals', 'confirm_plan', 'rewind', 'pantry_photo']) assert(!isTapAction(type), `${type} is not a chip`);
});

Deno.test('the coverage answer records the setting and, tapped, stores the turn; the batch answer re-derives the draft too', async () => {
  const v = testCtx(world());
  const coverage = await runTapped(v, 'set_setting', { conversationId: CONV, key: 'coverage_scope', value: 'dinners', chip: CHIP_LABELS.coverageDinners }, await runAction(v, { type: 'set_setting', payload: { conversationId: CONV, key: 'coverage_scope', value: 'dinners' } }));
  assertEquals(coverage.parts.map((p) => p.kind), ['memory_saved']);
  assert(typeof coverage.messageId === 'string' && coverage.messageId, 'the app gets the stored assistant row\'s id');
  assert(typeof coverage.tapMessageId === 'string' && coverage.tapMessageId);
  const setting = v.fake.rows('user_memories').find((m) => m.key === 'coverage_scope');
  assertEquals(setting?.value, 'dinners');

  const batch = await runTapped(v, 'set_setting', { conversationId: CONV, key: 'batch_cooking', value: false, chip: CHIP_LABELS.batchOff }, await runAction(v, { type: 'set_setting', payload: { conversationId: CONV, key: 'batch_cooking', value: false } }));
  assertEquals(batch.parts.map((p) => p.kind), ['memory_saved', 'batch']);
  assertEquals(v.fake.rows('vana_messages').filter((r) => r.role === 'user').map((r) => r.content), [CHIP_LABELS.coverageDinners, CHIP_LABELS.batchOff]);
  // The stored tool input is the tool's own shape, not the wire payload: no conversation id, no chip.
  const stored = v.fake.rows('vana_messages').filter((r) => r.role === 'assistant').map((r) => r.parts[0].input);
  assertEquals(stored, [{ key: 'coverage_scope', value: 'dinners' }, { key: 'batch_cooking', value: false }]);
});

Deno.test('"Same as last time" copies the last confirmed plan on the no-model endpoint and stores the tap', async () => {
  const ws = weekStartFor(today());
  const v = testCtx(world({
    meal_plans: [planRow({ id: PREV, week_start: addDays(ws, -7), status: 'confirmed', conversation_id: null }), planRow()],
    plan_meals: [mealRow('p1', PREV, 'dinner', 'D-001', 3)],
    meal_library: [{ id: 'D-001', name: 'Lentil bolognese', meal_type: 'dinner', contexts: [], batch: true, kcal: 700, carbs_g: 70, protein_g: 35, fat_g: 18, ingredients: 'lentils, tomatoes', source: 'the library' }],
  }));
  const result = await runTapped(v, 'same_as_last_time', { conversationId: CONV, chip: CHIP_LABELS.sameAsLastTime }, (await extraAction(v, 'same_as_last_time', { conversationId: CONV }))!);
  const batch = result.parts[0] as Extract<VanaPart, { kind: 'batch' }>;
  assertEquals(batch.plan.meals.map((m) => m.name), ['Lentil bolognese']);
  const assistant = v.fake.rows('vana_messages').find((r) => r.role === 'assistant')!;
  assertEquals(assistant.parts[0].type, 'tool-sameAsLastTime');
  assertEquals(assistant.parts[0].input, {});
  assertEquals(v.fake.writesTo('vana_calls', 'insert')[0].values.function_name, 'vana.tap.same_as_last_time.meal_planning');
});

Deno.test('"Use what I have" answers the pantry grid with no model; "Open shopping list" answers nothing and is still stored', async () => {
  const v = testCtx(world({ meal_logs: [{ user_id: U, is_deleted: false, log_date: today(), items: [{ name: 'eggs' }, { name: 'rice' }] }, { user_id: U, is_deleted: false, log_date: today(), items: [{ name: 'eggs' }] }], saved_meals: [] }));
  const pantry = await runTapped(v, 'ask_pantry', { conversationId: CONV, chip: 'Use what I have' }, (await extraAction(v, 'ask_pantry', { conversationId: CONV }))!);
  assertEquals(pantry.parts[0].kind, 'pantry');
  assertEquals((pantry.parts[0] as Extract<VanaPart, { kind: 'pantry' }>).items.map((i) => i.name), ['eggs', 'rice']);
  assertEquals(v.fake.rows('vana_messages').find((r) => r.role === 'assistant')!.parts[0].type, 'tool-askPantry');

  const opened = await runTapped(v, 'open_shopping_list', { conversationId: CONV, chip: CHIP_LABELS.openShoppingList }, (await extraAction(v, 'open_shopping_list', { conversationId: CONV }))!);
  assertEquals(opened.parts, []);
  assert(typeof opened.messageId === 'string');
  assertEquals(v.fake.rows('vana_messages').map((r) => r.content), ['Use what I have', '', CHIP_LABELS.openShoppingList, '']);
});

Deno.test('"Use these" records the pantry and stores the app\'s own line as the turn', async () => {
  const v = testCtx(world());
  const result = await runTapped(v, 'set_pantry', { conversationId: CONV, items: ['eggs', 'rice'], chip: 'I have eggs, rice on hand — use these' }, (await extraAction(v, 'set_pantry', { conversationId: CONV, items: ['eggs', 'rice'] }))!);
  assertEquals(result.parts.map((p) => p.kind), ['memory_saved']);
  const [user, assistant] = v.fake.rows('vana_messages');
  assertEquals(user.content, 'I have eggs, rice on hand — use these');
  assertEquals(assistant.parts[0].type, 'tool-setPantry');
  assertEquals(assistant.parts[0].input, { items: ['eggs', 'rice'] });
});

Deno.test('a tapped fork answer is remembered as said in the conversation, as the setSetting tool it replaces did; the settings sheet stays "settings"', async () => {
  const tapped = await runAction(testCtx(world()), { type: 'set_setting', payload: { conversationId: CONV, key: 'coverage_scope', value: 'dinners', chip: CHIP_LABELS.coverageDinners } });
  assertEquals((tapped.parts[0] as Extract<VanaPart, { kind: 'memory_saved' }>).memory.source, 'conversation');
  const sheet = await runAction(testCtx(world()), { type: 'set_setting', payload: { key: 'coverage_scope', value: 'dinners' } });
  assertEquals((sheet.parts[0] as Extract<VanaPart, { kind: 'memory_saved' }>).memory.source, 'settings');
});

Deno.test('without a chip, or without a conversation, or on an action that is not a chip, nothing is stored or logged', async () => {
  const v = testCtx(world());
  const plain = await runAction(v, { type: 'set_setting', payload: { conversationId: CONV, key: 'coverage_scope', value: 'all' } });
  const untouched = await runTapped(v, 'set_setting', { conversationId: CONV, key: 'coverage_scope', value: 'all' }, plain);
  assertEquals(untouched, plain);
  assertEquals(await runTapped(v, 'set_setting', { key: 'coverage_scope', value: 'all', chip: CHIP_LABELS.coverageAll }, plain), plain, 'no conversation to store into');
  assertEquals(await runTapped(v, 'confirm_plan', { conversationId: CONV, chip: 'Confirm' }, { parts: [] }), { parts: [] }, 'not a chip action');
  assertEquals(v.fake.rows('vana_messages'), []);
  assertEquals(v.fake.writesTo('vana_calls', 'insert'), []);
});

// ---------------------------------------------------------------- 5. the persona

Deno.test('the persona asks the two forks and the post-confirm question with exactly the labels the app acts on', () => {
  for (const label of [CHIP_LABELS.batchOn, CHIP_LABELS.batchOff, CHIP_LABELS.coverageDinners, CHIP_LABELS.coverageDinnersLunches, CHIP_LABELS.coverageAll, CHIP_LABELS.openShoppingList, CHIP_LABELS.layAcrossWeek, CHIP_LABELS.adjust]) {
    assert(PLANNING_PROMPT.includes(`"${label}"`), `the planning persona names "${label}"`);
  }
  assert(OPENERS.meal_planning.includes(`"${CHIP_LABELS.sameAsLastTime}"`), 'an opener that offers to repeat the last plan uses the label the app acts on');
});

Deno.test('the persona\'s chip instructions shrink to the chips that still reach Vana', () => {
  // Gone: the fixed-label chips as things she handles.
  for (const gone of ['"Draft my whole week" /', '"Same as last time" /', '"Lay it across the week" /', '"Use what I have" /', '→ setSetting batch_cooking', '→ setSetting coverage_scope']) {
    assert(!PLANNING_PROMPT.includes(gone), `no longer in the persona: ${gone}`);
  }
  // Still hers: what a typed message or a chip she named herself can ask for.
  for (const kept of ['just decide for me', 'repeat my last plan', 'what\'s in my fridge', 'Different protein', '"Adjust"', 'draftWeek', 'sameAsLastTime', 'askPantry', 'planWeek']) {
    assert(PLANNING_PROMPT.includes(kept), `still in the persona: ${kept}`);
  }
  // The prompt goes out on every planning turn: it must come out smaller than before ticket 11 (15,094 characters at
  // a740bd9c), not merely reworded.
  assert(PLANNING_PROMPT.length < 15094, `the planning persona is ${PLANNING_PROMPT.length} characters, not under 15,094`);
});
