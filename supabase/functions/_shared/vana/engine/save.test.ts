/** Box 7: a tap becomes a receipt, confetti fires once per milestone, a decline is recorded, the block goes dirty. */
import { assertEquals, assert, assertStringIncludes } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { flowLine, flowStateFor } from './assemble.ts';
import { freshState } from './engine.ts';
import { ORIENTATION } from './flows/orientation.ts';
import { saveTap, milestonesFor, celebrate } from './save.ts';
import { DEFAULT_LINES } from './scripted.ts';
import { FakeData, FakeMemory, snapshot } from './fakes.ts';

const pinGel = { id: 'f-gel', name: 'Gel + Water', phase: 'during' as const, activities: ['running'], brackets: ['90-150 min'] };

Deno.test('a pin tap → receipt + formula_pinned confetti once; a second pin fires nothing', async () => {
  const data = new FakeData(snapshot({ workouts: [{ id: 'w1', date: '2026-10-10', title: 'Long run', type: 'run', minutes: 120 }] }));
  const s = freshState('c1', 'u1'); s.flow = 'orientation';
  const memory = new FakeMemory(data);
  const before = flowStateFor(ORIENTATION, data.d, s);
  data.d.pins.push(pinGel);   // the app pinned it
  const r = await saveTap({ step: 'formula', card: 'formulas', action: 'pin', saved: { what: 'Gel + Water pinned', when: 'for runs of 90–150 min' } }, ORIENTATION, before, s, () => data.read(), DEFAULT_LINES, memory);
  assertEquals(r.receipts[0].line, 'Gel + Water pinned, for runs of 90–150 min.');
  assertEquals(r.confetti, ['formula_pinned']);
  assertEquals(r.completedStep, 'formula');
  assertEquals(memory.steps.formula, 'done');
  assert(s.blockDirty);
  const before2 = flowStateFor(ORIENTATION, data.d, s);
  data.d.pins.push({ ...pinGel, id: 'f-2', name: 'Chews' });
  const r2 = await saveTap({ step: 'formula', card: 'formulas', action: 'pin', saved: { what: 'Chews pinned' } }, ORIENTATION, before2, s, () => data.read(), DEFAULT_LINES, memory);
  assertEquals(r2.confetti, []);
  assertEquals(s.celebrated, ['formula_pinned']);
});

Deno.test('a race save adds where it lives; a workout save fires long_workout_fueled; setup_done only once', async () => {
  const data = new FakeData(snapshot({ connections: { plan: 'TP', wearable: 'garmin', wearableJustConnected: false, historySynced: true }, pins: [pinGel], workouts: [{ id: 'w1', date: '2026-10-10', title: 'Long run', type: 'run', minutes: 120 }] }));
  const s = freshState('c1', 'u1'); s.flow = 'orientation';
  const memory = new FakeMemory(data);
  let before = flowStateFor(ORIENTATION, data.d, s);
  data.d.workouts[0].fueled = true; data.d.workouts[0].fueledWithPin = 'f-gel';
  const w = await saveTap({ step: 'long_run', card: 'workout_card', action: 'save', saved: { what: 'Long run saved', when: 'Saturday, 120 min' } }, ORIENTATION, before, s, () => data.read(), DEFAULT_LINES, memory);
  assertEquals(w.confetti, ['long_workout_fueled']);
  before = flowStateFor(ORIENTATION, data.d, s);
  data.d.race = { name: 'River City Half', date: '2026-12-12' };
  const r = await saveTap({ step: 'race', card: 'race_card', action: 'save', saved: { what: 'River City Half added', when: 'Dec 12' } }, ORIENTATION, before, s, () => data.read(), DEFAULT_LINES, memory);
  assertEquals(r.receipts[0].line, 'River City Half added, Dec 12. It lives on your Events page.');
  assertEquals(r.confetti, ['race_added']);
  assertEquals(celebrate(s, ['setup_done']), ['setup_done']);
  assertEquals(celebrate(s, ['setup_done']), []);
  assertEquals(milestonesFor(ORIENTATION, before, flowStateFor(ORIENTATION, data.d, s), s), []);
});

Deno.test('a decline tap records the step (and what it drags along); a second decline across visits is for good; a dismiss is shown once, never a decline', async () => {
  const data = new FakeData(snapshot({ steps: { race: 'declined' } }));   // the race was declined on an earlier visit
  const s = freshState('c1', 'u1'); s.flow = 'orientation';
  const memory = new FakeMemory(data);
  const before = flowStateFor(ORIENTATION, data.d, s);
  const r = await saveTap({ step: 'week', card: 'week_planner', action: 'decline' }, ORIENTATION, before, s, () => data.read(), DEFAULT_LINES, memory);
  assertEquals(r.declined, ['week', 'long_run']);
  assertEquals(memory.steps, { week: 'declined', long_run: 'declined' });
  assertEquals(s.blockDirty, false);
  const r2 = await saveTap({ step: 'race', card: 'race_card', action: 'decline' }, ORIENTATION, before, s, () => data.read(), DEFAULT_LINES, memory);
  assertEquals(r2.declined, ['race']);
  assertEquals(s.declinedForGood, ['race']);
  assertEquals(memory.steps.race, 'declined_for_good');
  assert(r2.trail[0].includes('for good'));
  const d2 = await saveTap({ step: 'plan', card: 'connect_plan', action: 'dismiss' }, ORIENTATION, before, s, () => data.read(), DEFAULT_LINES, memory);
  assertEquals(d2.declined, []); assertEquals(d2.receipts, []);
  assertEquals(s.shownThisVisit, ['plan']);
  const fs = flowStateFor(ORIENTATION, data.d, s);
  assertEquals(fs.statuses.plan, 'open');     // still open, not declined
  assertEquals(fs.step?.id, 'wearable');      // but not offered again this visit
  assertStringIncludes(flowLine(fs, data.d), 'shown once: plan');
});
