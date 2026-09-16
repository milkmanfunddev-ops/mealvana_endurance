/** Contract test — every `contract-v1` fixture (copied verbatim from the prototype's tests/fixtures/, written from live
 *  dev calls as the QA user) must parse against the zod schemas derived from contracts.ts. This is the same check the
 *  Dart `fromJson` tests make; if a fixture stops parsing here, the contract moved and three places need the change
 *  (prototype TS, _shared/vana/, lib/features/meal_planning/domain/). Regenerate fixtures in the prototype (`pnpm test`). */
import { assert, assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { ActionResultZ, BatchPartZ, ChoicesPartZ, DayGuidancePartZ, PantryPartZ, WeekPartZ, DebriefPartZ, FeedbackSavedPartZ, FeedbackPromptPartZ, HomePayloadZ, MealDetailZ, MealPickerPartZ, NdjsonExchangeZ, RecentMealZ, ShoppingListPartZ, StaplesPartZ, VanaPartZ, clampChips } from '../../_shared/vana/schemas.ts';
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

Deno.test('contract: feedback_saved.json — typed-into-Vana feedback landed in user_feedback (2026-09-09)', () => {
  const fs = parse(FeedbackSavedPartZ, fixture('feedback_saved'), 'feedback_saved.json');
  assertEquals(fs.about, 'vana');
  parse(VanaPartZ, fixture('feedback_saved'), 'feedback_saved.json via VanaPartZ');
  assert(!FeedbackSavedPartZ.safeParse({ kind: 'feedback_saved', message: '', sentiment: 'neutral', about: 'app' }).success, 'message is required');
  assert(!FeedbackSavedPartZ.safeParse({ kind: 'feedback_saved', message: 'x', sentiment: 'meh', about: 'app' }).success, 'sentiment enum');
});

Deno.test('contract: feedback_prompt.json — server-appended first-conversation prompt (2026-09-09)', () => {
  parse(FeedbackPromptPartZ, fixture('feedback_prompt'), 'feedback_prompt.json');
  parse(VanaPartZ, fixture('feedback_prompt'), 'feedback_prompt.json via VanaPartZ');
  assert(!FeedbackPromptPartZ.safeParse({ kind: 'feedback_prompt', text: 'x' }).success, 'no payload — copy is content-managed on the client (plain text, no link)');
});

Deno.test('contract: single VanaPart fixtures', () => {
  const picker = parse(MealPickerPartZ, fixture('meal_picker'), 'meal_picker.json');
  assertEquals(picker.meals.length, 3);
  parse(ChoicesPartZ, fixture('choices'), 'choices.json');
  // choices_details.json — the additive `details` array (one trade-off line per option, 2026-09-03); old rows without it still parse above
  const cd = parse(ChoicesPartZ, fixture('choices_details'), 'choices_details.json');
  assertEquals(cd.details?.length, cd.options.length);
  assert(!ChoicesPartZ.safeParse({ kind: 'choices', options: ['a', 'b', 'c', 'd', 'e'] }).success, 'options cap is 4');
  const dg = parse(DayGuidancePartZ, fixture('day_guidance'), 'day_guidance.json');
  assertEquals(dg.suggestions.length, 2);
  parse(StaplesPartZ, fixture('staples'), 'staples.json');
  parse(ShoppingListPartZ, fixture('shopping_list'), 'shopping_list.json');
  // every one of them is also a member of the union the Dart parser switches on
  // additive 2026-09-03 parts (plan Phases 3/7/8)
  assertEquals(parse(PantryPartZ, fixture('pantry'), 'pantry.json').items.length, 4);
  assertEquals(parse(WeekPartZ, fixture('week'), 'week.json').days.length, 2);
  assertEquals(parse(DebriefPartZ, fixture('debrief'), 'debrief.json').memories[0].source, 'debrief');
  for (const f of ['meal_picker', 'choices', 'choices_details', 'day_guidance', 'staples', 'shopping_list', 'pantry', 'week', 'debrief']) parse(VanaPartZ, fixture(f), `${f}.json as VanaPart`);
});

/** mp-272 / mp-230 clause 4 (ticket 31) — a turn may name the chips it expects next, and the tail of the same
 *  search rides behind "Show more". Built on the FROZEN meal_picker.json so the additive fields are the only variable. */
Deno.test('contract: meal_picker chips are 2..4 strings, clamped or dropped before the wire', () => {
  const base = fixture('meal_picker');
  // The frozen fixture predates both fields and still parses; neither is invented on the way out.
  const plain = parse(MealPickerPartZ, base, 'meal_picker.json');
  assertEquals(plain.chips, undefined);
  assertEquals(plain.more, undefined);

  // A legal list rides through untouched.
  const named = parse(MealPickerPartZ, { ...base, chips: ['These three', 'Lighter ones', 'Show me pasta'] }, 'meal_picker + chips');
  assertEquals(named.chips, ['These three', 'Lighter ones', 'Show me pasta']);

  // The contract itself carries only a legal list: too few, too many, or blank never parses.
  for (const chips of [[], ['Only one'], ['a', 'b', 'c', 'd', 'e'], ['ok', '']]) {
    assert(!MealPickerPartZ.safeParse({ ...base, chips }).success, `chips ${JSON.stringify(chips)} is not a legal list`);
  }

  // …because the producer clamps first: >4 keeps the first four, <2 (after trimming, blanks and duplicates) is dropped.
  assertEquals(clampChips(['a', 'b', 'c', 'd', 'e']), ['a', 'b', 'c', 'd']);
  assertEquals(clampChips([' These three ', 'Lighter ones']), ['These three', 'Lighter ones']);
  assertEquals(clampChips(['Same', 'Same']), undefined);
  assertEquals(clampChips(['Only one']), undefined);
  assertEquals(clampChips([]), undefined);
  assertEquals(clampChips(undefined), undefined);
  assertEquals(clampChips('Not a list'), undefined);
  assertEquals(clampChips([1, 'a', null, 'b']), ['a', 'b']);
  assertEquals(clampChips(['x'.repeat(60), 'b'])?.[0].length, 40);
  // Whatever it returns parses as the contract's list.
  assert(MealPickerPartZ.safeParse({ ...base, chips: clampChips(['a', 'b', 'c', 'd', 'e']) }).success);

  // "Show more" carries the tail of the same search — MealRefs, same shape as the shown handful.
  const withMore = parse(MealPickerPartZ, { ...base, more: base.meals }, 'meal_picker + more');
  assertEquals(withMore.more?.length, 3);
  parse(VanaPartZ, { ...base, chips: ['One', 'Two'], more: base.meals }, 'meal_picker + chips + more as VanaPart');
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

// ---- mp-265 clause 4 / ticket 27: a deterministic action is a hand-off to the app's own screen, never done in the sheet.
Deno.test('contract: hand_off.json — a button to the screen the app already has (mp-265)', async () => {
  const { HandOffPartZ } = await import('../../_shared/vana/schemas.ts');
  const plan = parse(HandOffPartZ, fixture('hand_off'), 'hand_off.json');
  assertEquals(plan.target, 'meal_plan');
  assertEquals(plan.entityId, null);
  const activity = parse(HandOffPartZ, fixture('hand_off_entity'), 'hand_off_entity.json');
  assertEquals(activity.target, 'new_activity');
  assert(activity.entityId, 'fuelling a workout names the workout');
  for (const f of ['hand_off', 'hand_off_entity']) parse(VanaPartZ, fixture(f), `${f}.json as VanaPart`);
  assert(!HandOffPartZ.safeParse({ kind: 'hand_off', target: 'settings', label: 'x', entityId: null }).success, 'target is one of the four screens');
  assert(!HandOffPartZ.safeParse({ kind: 'hand_off', target: 'meal_plan', label: '', entityId: null }).success, 'label is required');
  assert(!HandOffPartZ.safeParse({ kind: 'hand_off', target: 'meal_plan', label: 'x' }).success, 'entityId is always sent, null when there is none');
});

Deno.test('contract: the handOff tool returns the hand_off part, in the sheet\'s general tool set', async () => {
  const { makeVanaTools } = await import('../../_shared/vana/tools.ts');
  // deno-lint-ignore no-explicit-any
  const tools = makeVanaTools({} as any, {} as any, 'general') as Record<string, any>;
  assert(tools.handOff, 'general mode offers handOff');
  const out = await tools.handOff.execute({ target: 'meal_plan', label: 'Open meal planning' }, { toolCallId: 't', messages: [] });
  parse(VanaPartZ, out, 'handOff output');
  assertEquals(out, fixture('hand_off'));
  const withId = await tools.handOff.execute({ target: 'event', label: 'Plan the race', entityId: 'ev-1' }, { toolCallId: 't', messages: [] });
  assertEquals(withId.entityId, 'ev-1');
});

// ---- Lee's playtest 2026-09-16 §10: Vana writes the app's own objects; every write answers a receipt, an unconfirmed delete a needs_confirmation.
Deno.test('contract: receipt.json / needs_confirmation.json — a card for every write, a question before a delete', async () => {
  const { ReceiptPartZ, NeedsConfirmationPartZ } = await import('../../_shared/vana/schemas.ts');
  const r = parse(ReceiptPartZ, fixture('receipt'), 'receipt.json');
  assertEquals(r.action, 'delete_event'); assertEquals(r.entity, 'event');
  assertEquals(r.undo?.action, 'undo_receipt'); assertEquals(r.undo?.params.action, 'delete_event');
  assert((r.undo?.params as { row?: { id?: string } }).row?.id, 'the deleted row rides on the undo so the device can put it back');
  const plain = parse(ReceiptPartZ, fixture('receipt_no_undo'), 'receipt_no_undo.json');
  assertEquals(plain.action, 'new_plan'); assertEquals(plain.undo, null);
  const ask = parse(NeedsConfirmationPartZ, fixture('needs_confirmation'), 'needs_confirmation.json');
  assertEquals(ask.entityId, r.entityId);
  for (const f of ['receipt', 'receipt_no_undo', 'needs_confirmation']) parse(VanaPartZ, fixture(f), `${f}.json as VanaPart`);
  assert(!ReceiptPartZ.safeParse({ ...fixture('receipt_no_undo'), undo: undefined }).success, 'undo is always sent, null when there is none');
  assert(!ReceiptPartZ.safeParse({ ...fixture('receipt_no_undo'), action: 'eat_plan' }).success, 'action is one the app knows');
  assert(!ReceiptPartZ.safeParse({ ...fixture('receipt_no_undo'), summary: '' }).success, 'summary is the card\'s line');
  assert(!ReceiptPartZ.safeParse({ ...fixture('receipt'), undo: { action: 'undo_receipt', params: {} } }).success, 'undo params name the action');
  // The action result of an Undo is an ordinary parts list with one receipt.
  parse(ActionResultZ, { parts: [{ ...fixture('receipt_no_undo'), action: 'undo' }] }, 'undo_receipt result');
});

Deno.test('contract: both personas carry the write rules and the delete-asks-first rule', async () => {
  const { GENERAL_PROMPT, PLANNING_PROMPT, WRITE_RULES, NEW_PLAN_STANDING } = await import('../../_shared/vana/persona.ts');
  for (const p of [GENERAL_PROMPT, PLANNING_PROMPT]) {
    assert(p.includes(WRITE_RULES), 'the shared write rules are in the prompt');
    for (const t of ['startNewPlan', 'createEvent', 'updateEvent', 'deleteEvent', 'logMeal', 'deleteLoggedMeal', 'listEvents']) assert(p.includes(t), `names ${t}`);
    assert(p.includes('confirmed: true'), 'a delete asks first');
  }
  assert(!GENERAL_PROMPT.includes('Planning or adding a race or event → target event'), 'adding an event is a write now, not a hand-off');
  assert(NEW_PLAN_STANDING.includes('never call startNewPlan'), 'in a New meal plan conversation the draft is the new plan');
});

Deno.test('contract: the general persona names the four hand-offs and never builds a plan in the sheet', async () => {
  const { GENERAL_PROMPT } = await import('../../_shared/vana/persona.ts');
  for (const target of ['meal_plan', 'new_activity', 'event', 'carb_loading']) assert(GENERAL_PROMPT.includes(target), `GENERAL_PROMPT names ${target}`);
  assert(!GENERAL_PROMPT.includes('"Start a meal plan"'), 'a plan request is a hand-off, not a chip');
});

// ---- 2026-09-16 (Lee: delete a plan by hand or through Vana; Vana edits workouts): the plan delete receipt and an activity receipt.
Deno.test('contract: receipt_delete_plan.json / receipt_activity.json — the Plan tab\'s delete and a workout write', async () => {
  const { ReceiptPartZ } = await import('../../_shared/vana/schemas.ts');
  const del = parse(ReceiptPartZ, fixture('receipt_delete_plan'), 'receipt_delete_plan.json');
  assertEquals(del.action, 'delete_plan'); assertEquals(del.entity, 'plan');
  assertEquals(del.undo?.params, { action: 'delete_plan', id: del.entityId }, 'undo needs only the id — the tombstone is lifted, nothing re-inserted');
  const act = parse(ReceiptPartZ, fixture('receipt_activity'), 'receipt_activity.json');
  assertEquals(act.action, 'create_activity'); assertEquals(act.entity, 'activity');
  for (const f of ['receipt_delete_plan', 'receipt_activity']) parse(VanaPartZ, fixture(f), `${f}.json as VanaPart`);
  parse(ActionResultZ, { parts: [fixture('receipt_delete_plan')] }, 'delete_plan action result');
});
