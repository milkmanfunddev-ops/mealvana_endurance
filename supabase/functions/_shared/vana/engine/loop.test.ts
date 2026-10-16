/** Box 5: the loop stops on a card, continues on a receipt, compacts tool results, forces the first tool and the landing. */
import { assertEquals, assert, assertStringIncludes } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { assemble } from './assemble.ts';
import { newCounters } from './counters.ts';
import { DEFAULT_FLOWS, freshState } from './engine.ts';
import { NONE } from './flows/none.ts';
import { ORIENTATION } from './flows/orientation.ts';
import { runPlan, historyMessages, type LoopContext } from './loop.ts';
import { DEFAULT_LINES } from './scripted.ts';
import { fakeAdapters, FakeModel, lastUser, snapshot, type GenInput } from './fakes.ts';
import type { Plan } from './types.ts';

type Ctx = LoopContext & { a: ReturnType<typeof fakeAdapters> };
async function ctxFor(flow = NONE, model = new FakeModel(), d = snapshot()): Promise<Ctx> {
  const a = fakeAdapters(d, model);
  const s = freshState('c1', 'u1'); s.flow = flow.id;
  const assembled = await assemble(s, flow, a);
  return { a, s, flow, assembled, reassemble: () => assemble(s, flow, a), lines: DEFAULT_LINES, counters: newCounters(), message: '', trail: [], calls: [] };
}

Deno.test('a receipt rides to the next step as [just done: …] and the block is rebuilt in between; the last step\'s words are the reply', async () => {
  const model = new FakeModel([], [
    { text: 'Got it.', toolCalls: [{ name: 'rememberFact', input: { fact: 'Hates cilantro' } }] },   // step 1, pass 1
    { text: 'Noted, cilantro is out.' },                                                            // step 1, pass 2 (words after the receipt)
    (i: GenInput) => ({ text: `Dinner picks, no cilantro. (saw: ${lastUser(i)})`, toolCalls: [{ name: 'suggestMeals', input: { mealType: 'dinner' } }] }),   // step 2
  ]);
  const ctx = await ctxFor(NONE, model);
  ctx.message = 'remember I hate cilantro, what\'s for dinner?';
  const plan: Plan = { steps: [{ flow: 'none', step: NONE.steps.set_value, intents: [], notes: [], writeAllowed: true }, { flow: 'none', step: NONE.steps.choose, intents: [], notes: [], writeAllowed: false }], pending: [], why: [], flowChanged: false };
  const r = await runPlan(plan, ctx);
  assertEquals(r.receipts, ['Noted: Hates cilantro.']);
  assertEquals(r.card?.kind, 'meal_picker');
  assertEquals((r.card?.payload as { filter: string[] }).filter, ['Hates cilantro']);   // the write rebuilt the block the picker read
  assertStringIncludes(r.text, '[just done: remembered: Hates cilantro]');                  // the note rode on step 2's message
  assertEquals(r.text.startsWith('Dinner picks'), true);                                   // step 1's words were dropped
  assertEquals(r.endedBy, 'card');
  assert(ctx.trail.some((t) => t.includes('rebuilt the block (a write marked it dirty)')));
  assertEquals(ctx.counters.steps_run, 2); assertEquals(ctx.counters.receipts, 1); assertEquals(ctx.counters.cards_shown, 1);
});

Deno.test('a card ends the turn: the second step does not run and its intents go pending', async () => {
  const model = new FakeModel([], [{ text: 'Your form.', toolCalls: [{ name: 'showRaceCard', input: {} }] }]);
  const ctx = await ctxFor(NONE, model);
  const plan: Plan = { steps: [{ flow: 'none', step: NONE.steps.draft_record, intents: [{ label: 'asks', target: 'race' }], notes: [], writeAllowed: true }, { flow: 'none', step: NONE.steps.set_value, intents: [{ label: 'asks', target: 'weight' }], notes: [], writeAllowed: true }], pending: [], why: [], flowChanged: false };
  const r = await runPlan(plan, ctx);
  assertEquals(r.card?.kind, 'race_card');
  assertEquals(ctx.counters.steps_run, 1);
  assertEquals(ctx.s.pending, [{ label: 'asks', target: 'weight' }]);
  assertEquals(ctx.counters.intents_pending, 1);
  assertEquals(model.generated.length, 1);
});

Deno.test('pass one is forced to the step\'s first tool with bound arguments; a disagreeing model argument is dropped and counted', async () => {
  const d = snapshot({ connections: { plan: 'TP', wearable: 'garmin', wearableJustConnected: false, historySynced: false }, workouts: [{ id: 'w1', date: '2026-10-10', title: 'Long ride', type: 'ride', minutes: 180 }] });
  const model = new FakeModel([], [(i: GenInput) => ({ text: 'Pick the fuel for that ride.', toolCalls: [{ name: (i.toolChoice as { name: string }).name, input: { phase: 'during', sport: 'run', minutes: 60 } }] })]);
  const ctx = await ctxFor(ORIENTATION, model, d);
  const r = await runPlan({ steps: [{ flow: 'orientation', step: ORIENTATION.steps.formula, intents: [], notes: [], writeAllowed: false }], pending: [], why: [], flowChanged: false }, ctx);
  assertEquals(model.generated[0].toolChoice, { name: 'recommendFormulas' });
  assertEquals((r.card?.payload as { sport: string; minutes: number }).sport, 'ride');
  assertEquals((r.card?.payload as { minutes: number }).minutes, 180);
  assertEquals(ctx.counters.bound_arg_disagreement, 1);
  assert(ctx.trail.some((t) => t.startsWith('gate: recommendFormulas bound over the model')));
});

Deno.test('a card with no words gets one landing pass with tools off; the pass cap and the landing are counted', async () => {
  const model = new FakeModel([], [{ text: '', toolCalls: [{ name: 'showConnectCard', input: {} }] }, { text: 'Your plan lands here.' }]);
  const ctx = await ctxFor(ORIENTATION, model);
  const r = await runPlan({ steps: [{ flow: 'orientation', step: ORIENTATION.steps.plan, intents: [], notes: [], writeAllowed: false }], pending: [], why: [], flowChanged: false }, ctx);
  assertEquals(r.text, 'Your plan lands here.');
  assertEquals(model.generated[1].toolChoice, 'none'); assertEquals(model.generated[1].tools, []);
  assertEquals(ctx.counters.forced_landing, 1);
  // a model that keeps calling reads: the last pass has no tools, pass_cap_hit counts
  const busy = new FakeModel([], [
    { text: '', toolCalls: [{ name: 'appGuide', input: { topic: 'races' } }] }, { text: '', toolCalls: [{ name: 'appGuide', input: { topic: 'races' } }] },
    { text: '', toolCalls: [{ name: 'appGuide', input: { topic: 'races' } }] }, { text: 'Races live on the Events page.' },
  ]);
  const ctx2 = await ctxFor(ORIENTATION, busy);
  const r2 = await runPlan({ steps: [{ flow: 'orientation', step: ORIENTATION.answerStep, intents: [], notes: [], writeAllowed: false }], pending: [], why: [], flowChanged: false }, ctx2);
  assertEquals(r2.text, 'Races live on the Events page.');
  assertEquals(busy.generated.length, 4);
  assertEquals(busy.generated[3].tools, []);
  assertEquals(ctx2.counters.forced_landing, 1);
  assertStringIncludes(busy.generated[1].messages.at(-1)!.content, 'guide(races)');   // compact replay: the one-line view, not raw data
});

Deno.test('a write tool without a yes is refused (hard rule 4) and the step still lands', async () => {
  const model = new FakeModel([], [{ text: '', toolCalls: [{ name: 'rememberFact', input: { fact: 'x' } }] }, { text: 'Want me to remember that?' }]);
  const ctx = await ctxFor(NONE, model);
  const r = await runPlan({ steps: [{ flow: 'none', step: NONE.steps.set_value, intents: [{ label: 'chat' }], notes: [], writeAllowed: false }], pending: [], why: [], flowChanged: false }, ctx);
  assertEquals(r.receipts, []);
  assertEquals(ctx.counters.check_catches.write_without_yes, 1);
  assertEquals(ctx.a.tools.calls.length, 0);
  assertStringIncludes(model.generated[1].messages.at(-1)!.content, 'refused');
});

Deno.test('Check: [GUARD] once and the rewrite is kept; twice and the safe line goes out', async () => {
  const model = new FakeModel([], [{ text: 'Your Garmin is connected now.', toolCalls: [{ name: 'showConnectCard', input: {} }] }, { text: 'WORDS: Your workouts flow in once your watch is linked.' }]);
  const ctx = await ctxFor(ORIENTATION, model);
  const r = await runPlan({ steps: [{ flow: 'orientation', step: ORIENTATION.steps.wearable, intents: [], notes: [], writeAllowed: false }], pending: [], why: [], flowChanged: false }, ctx);
  assertEquals(r.text, 'Your workouts flow in once your watch is linked.');
  assertEquals(ctx.counters.check_catches.status_truthful, 1); assertEquals(ctx.counters.check_retry_fixed, 1);
  assertEquals(model.generated[1].role, 'guard');
  assertStringIncludes(lastUser(model.generated[1]), '[GUARD]');
  const stubborn = new FakeModel([], [{ text: 'Your Garmin is connected now.', toolCalls: [{ name: 'showConnectCard', input: {} }] }, { text: 'WORDS: Garmin is connected, so we are set.' }]);
  const ctx2 = await ctxFor(ORIENTATION, stubborn);
  const r2 = await runPlan({ steps: [{ flow: 'orientation', step: ORIENTATION.steps.wearable, intents: [], notes: [], writeAllowed: false }], pending: [], why: [], flowChanged: false }, ctx2);
  assertEquals(r2.text, DEFAULT_LINES.safe);
  assertEquals(ctx2.counters.check_safe_line, 1);
});

Deno.test('scripted steps: off_flow with the steer, feedback runs saveFeedback, the wrap draws the recap', async () => {
  const ctx = await ctxFor(ORIENTATION);
  const { OFF_FLOW, FEEDBACK, CHECK_IN } = await import('./flows/shared.ts');
  const r = await runPlan({ steps: [{ flow: 'orientation', step: OFF_FLOW, intents: [], notes: ['[steer: Want to keep going with your training plan?]'], writeAllowed: false }], pending: [], why: [], flowChanged: false }, ctx);
  assertEquals(r.text, "That's coming soon. I can't help with it yet. Want to keep going with your training plan?");
  assertEquals(ctx.counters.model_calls, 0);
  ctx.message = 'this is a lot';
  const f = await runPlan({ steps: [{ flow: 'orientation', step: FEEDBACK, intents: [{ label: 'feedback', target: 'flow' }], notes: ['[steer: ]'], writeAllowed: false }], pending: [], why: [], flowChanged: false }, ctx);
  assertEquals(f.text, DEFAULT_LINES.feedback_ack);
  assertEquals(ctx.a.tools.calls.at(-1)?.name, 'saveFeedback');
  const w = await runPlan({ steps: [{ flow: 'orientation', step: ORIENTATION.steps.wrap, intents: [], notes: ['[steer: ]'], writeAllowed: false }], pending: [], why: [], flowChanged: false }, ctx);
  assertEquals(w.card?.kind, 'recap'); assertEquals(w.confetti, ['setup_done']); assertEquals(w.text, DEFAULT_LINES.wrap);
  const c = await runPlan({ steps: [{ flow: 'orientation', step: CHECK_IN, intents: [], notes: ['[steer: ]'], writeAllowed: false }], pending: [], why: [], flowChanged: false }, ctx);
  assertEquals(c.text, DEFAULT_LINES.check_in); assertEquals(c.steps[0].violations, []);
});

Deno.test('hard rule 4 has no exceptions: a named race is a prefilled draft card, never a direct write; no draft_record step carries a write tool', async () => {
  const model = new FakeModel([], [
    { text: 'Adding River City Half now.', toolCalls: [{ name: 'addRace', input: { name: 'River City Half', date: '2026-12-12' } }] },
    { text: 'Here is your race form, River City Half prefilled.', toolCalls: [{ name: 'showRaceCard', input: { name: 'River City Half' } }] },
  ]);
  const ctx = await ctxFor(ORIENTATION, model);
  ctx.message = 'add my River City Half on Dec 12';
  const r = await runPlan({ steps: [{ flow: 'orientation', step: ORIENTATION.steps.race, intents: [{ label: 'answers' }], notes: [], writeAllowed: true }], pending: [], why: [], flowChanged: false }, ctx);
  assertEquals(ctx.a.tools.calls.map((c) => c.name), ['showRaceCard']);
  assert(model.generated[1].messages.some((m) => m.role === 'tool' && m.content === 'addRace: not a tool of this step'));
  assertEquals(r.card?.kind, 'race_card'); assertEquals(r.receipts, []);
  for (const flow of Object.values(DEFAULT_FLOWS)) for (const step of Object.values(flow!.steps)) if (step.shape === 'draft_record') assertEquals(step.tools.filter((t) => t.kind === 'write'), [], `${flow!.id}.${step.id}`);
});

Deno.test('history: the last ten shown lines, past cards as notes, opening on a user turn', () => {
  const h = historyMessages([{ role: 'vana', text: 'Hi.', cards: ['connect_plan'] }, { role: 'athlete', text: 'hey' }]);
  assertEquals(h[0], { role: 'user', content: '[opened]' });
  assertEquals(h[1], { role: 'assistant', content: 'Hi.\n(card: connect_plan)' });
});
