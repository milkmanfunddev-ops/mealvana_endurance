/** runTurn end to end on fakes: the opener, a typed turn, a tap that completes a step, a tap that resumes a pending intent. */
import { assertEquals, assert, assertStringIncludes } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { runTurn, OPENER } from './engine.ts';
import { fakeAdapters, FakeModel, lastUser, snapshot, type GenInput } from './fakes.ts';

const turn = (a: ReturnType<typeof fakeAdapters>, message?: string, tap?: Parameters<typeof runTurn>[0]['tap']) =>
  runTurn({ conversationId: 'c1', userId: 'u1', message, tap, situation: { route: '/main', opened: 'orientation' } }, a);

Deno.test('the opener: no Read, the first step with [opener], one model call, the card', async () => {
  const a = fakeAdapters(snapshot());
  const r = await turn(a, OPENER);
  assertEquals(r.read, null);
  assertEquals(r.counters.model_calls, 1);
  assertEquals(r.reply.card?.kind, 'connect_plan');
  assertStringIncludes(lastUser(a.model.generated[0]), '[opener]');
  assertEquals(r.state.flow, 'orientation');
  assertEquals(r.state.history.map((l) => l.role), ['athlete', 'vana']);
  assert(r.trail.some((t) => t.startsWith('route: situation starts orientation')));
});

Deno.test('a typed turn: Read, facts remembered, Route, the step; the counters carry the label', async () => {
  const model = new FakeModel([{ intents: [{ label: 'answers' }], facts: ['Owns a Garmin Forerunner'] }]);
  const a = fakeAdapters(snapshot(), model);
  await turn(a, OPENER);
  const r = await turn(a, 'yes I use TrainingPeaks');
  assertEquals(r.read?.intents, [{ label: 'answers' }]);
  assertEquals(a.memory.facts, ['Owns a Garmin Forerunner']);
  assertEquals(r.counters.read_label, ['answers']);
  assertEquals(r.counters.model_calls, 2);
  assertEquals(r.plan?.steps[0].step.id, 'plan');
  assertStringIncludes(model.readInputs[0].system, 'Step: plan');
});

Deno.test('a tap that completes a step: no Read, the receipt, confetti once, and the next step\'s agent with [receipt: …]', async () => {
  const d = snapshot({ connections: { plan: 'TP', wearable: 'garmin', wearableJustConnected: false, historySynced: false }, workouts: [{ id: 'w1', date: '2026-10-10', title: 'Long run', type: 'run', minutes: 120 }] });
  const a = fakeAdapters(d);
  await turn(a, OPENER);   // the formula picker
  a.data.d.pins.push({ id: 'f-gel', name: 'Gel + Water', phase: 'during', activities: ['running'], brackets: ['90-150 min'] });
  const r = await turn(a, undefined, { step: 'formula', card: 'formulas', action: 'pin', saved: { what: 'Gel + Water pinned', when: 'for runs of 90–150 min' } });
  assertEquals(r.read, null);
  assertEquals(r.reply.receipts, ['Gel + Water pinned, for runs of 90–150 min.']);
  assertEquals(r.reply.confetti, ['formula_pinned']);
  assertEquals(r.plan?.steps[0].step.id, 'long_run');
  assertStringIncludes(lastUser(a.model.generated.at(-1)!), '[receipt: Gel + Water pinned, for runs of 90–150 min.]');
  assertEquals(r.reply.card?.kind, 'workout_card');
  assertEquals((r.reply.card?.payload as { mode: string; workoutId: string }).mode, 'fuel');
  assertEquals(a.memory.steps.formula, 'done');
  assertEquals(r.counters.model_calls, 1);
});

Deno.test('a tap that clears a card with a pending intent resumes the plan, no Read', async () => {
  const model = new FakeModel(
    [{ intents: [{ label: 'asks', target: 'race' }, { label: 'asks', target: 'memory' }], facts: [] }],
    [
      { text: 'Your race form; then your cilantro note.', toolCalls: [{ name: 'showRaceCard', input: { name: 'River City Half' } }] },   // step 1 → card, memory pending
      (i: GenInput) => ({ text: `Noting it now. (${lastUser(i)})`, toolCalls: [{ name: 'rememberFact', input: { fact: 'Hates cilantro' } }] }),  // resumed set_value
      { text: 'Done, cilantro is off the list.' },
    ],
  );
  const a = fakeAdapters(snapshot({ profile: { firstName: 'Sam', gutTraining: 'moderate', metVana: true } }), model);
  const first = await runTurn({ conversationId: 'c1', userId: 'u1', message: 'add my River City Half, and remember I hate cilantro', situation: { route: '/main', opened: 'plan_button' } }, a);
  assertEquals(first.state.flow, 'none');
  assertEquals(first.reply.card?.kind, 'race_card');
  assertEquals(first.state.pending, [{ label: 'asks', target: 'memory' }]);
  assertStringIncludes(lastUser(model.generated[0]), '[then: asks memory]');
  a.data.d.race = { name: 'River City Half', date: '2026-12-12' };
  const second = await runTurn({ conversationId: 'c1', userId: 'u1', tap: { step: 'draft_record', card: 'race_card', action: 'save', saved: { what: 'River City Half added', when: 'Dec 12' } } }, a);
  assertEquals(second.read, null);
  assertEquals(second.plan?.steps.map((p) => p.step.id), ['set_value']);
  assertEquals(second.state.pending, []);
  assertEquals(second.reply.receipts, ['River City Half added, Dec 12.']);
  assertStringIncludes(lastUser(model.generated[1]), '[receipt: River City Half added, Dec 12.]');
  assertStringIncludes(second.reply.text, 'Done, cilantro is off the list.');
  assertEquals(a.data.d.memories, ['Hates cilantro']);
  assert(second.trail.some((t) => t.includes('resumed 1 pending intent')));
});

Deno.test('a decline tap runs the next step with [declined: …]; the gate refuses an empty turn with a trail line', async () => {
  const a = fakeAdapters(snapshot());
  await turn(a, OPENER);
  const r = await turn(a, undefined, { step: 'plan', card: 'connect_plan', action: 'decline' });
  assertEquals(r.plan?.steps[0].step.id, 'wearable');
  assertStringIncludes(lastUser(a.model.generated.at(-1)!), '[declined: plan]');
  assertEquals(r.state.declinedThisVisit, ['plan']);
  const e = await runTurn({ conversationId: 'c1', userId: 'u1' }, a);
  assertEquals(e.trail, ['gate: refused (empty turn: neither a message nor a tap)']);
});
