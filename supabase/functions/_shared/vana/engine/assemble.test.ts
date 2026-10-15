/** Box 2: the block is built from a fake row, cached, and invalidated by a write, a new day or a flow change. */
import { assertEquals, assertStringIncludes, assert } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { assemble, flowLine, flowStateFor } from './assemble.ts';
import { ORIENTATION } from './flows/orientation.ts';
import { NONE } from './flows/none.ts';
import { freshState } from './engine.ts';
import { FakeData, fakeClock, snapshot } from './fakes.ts';

const state = () => freshState('c1', 'u1');

Deno.test('assemble builds the block from a fake row: TODAY, NEXT 7 DAYS, the Doll, the flow lines, FLOW', async () => {
  const data = new FakeData(snapshot({ doll: ['WEATHER sunny'], connections: { plan: 'TrainingPeaks', wearable: null, wearableJustConnected: false, historySynced: false }, workouts: [{ id: 'w1', date: '2026-10-10', title: 'Long run', type: 'run', minutes: 120 }] }));
  const s = state();
  const r = await assemble(s, ORIENTATION, { data, clock: fakeClock() });
  assert(r.rebuilt);
  assertStringIncludes(r.block, 'ATHLETE FILE\n- TODAY: Tuesday, Oct 6 2026');
  assertStringIncludes(r.block, 'Wednesday, Oct 7 = 2026-10-07');
  assertStringIncludes(r.block, 'WEATHER sunny');
  assertStringIncludes(r.block, '- PLAN: connected (TrainingPeaks)');
  assertStringIncludes(r.block, '- NEXT LONG WORKOUT (90+ min): Long run, 120 min (90-150 min), Saturday, Oct 10 (id w1), no fueling plan yet');
  assertStringIncludes(r.block, '- FLOW: orientation · step: wearable · done: plan, week · declined this visit: none · pending: none · first meeting: yes · opener: yes · safety hit: none');
  assertEquals(r.flowState.step?.id, 'wearable');
  assertEquals(data.reads, 1);
});

Deno.test('the block is reused on the next turn and rebuilt only when dirty, on a new day, or on a flow change', async () => {
  const data = new FakeData(snapshot());
  const s = state();
  await assemble(s, ORIENTATION, { data, clock: fakeClock() });
  const again = await assemble(s, ORIENTATION, { data, clock: fakeClock() });
  assertEquals(again.rebuilt, false);
  assertEquals(data.reads, 1);
  s.blockDirty = true;   // a write
  data.d.connections.plan = 'Final Surge';
  const afterWrite = await assemble(s, ORIENTATION, { data, clock: fakeClock() });
  assert(afterWrite.rebuilt);
  assertStringIncludes(afterWrite.block, 'PLAN: connected (Final Surge)');
  assertEquals(afterWrite.trail[0], 'assemble: rebuilt the block (a write marked it dirty)');
  assertEquals(data.reads, 2);
  const newDay = await assemble(s, ORIENTATION, { data, clock: fakeClock('2026-10-07') });
  assert(newDay.rebuilt); assertEquals(data.reads, 3);
  const flowChange = await assemble(s, NONE, { data, clock: fakeClock('2026-10-07') });
  assert(flowChange.rebuilt); assertEquals(data.reads, 4);
  assertStringIncludes(flowChange.block, '- FLOW: none');
});

Deno.test('the FLOW line carries this visit\'s declines, pending intents and a safety hit; the step skips declined ones', () => {
  const s = state();
  s.declinedThisVisit = ['plan'];
  s.pending = [{ label: 'asks', target: 'app' }];
  s.safetyHit = 'medical';
  const d = snapshot({ steps: { race: 'declined' } });
  const fs = flowStateFor(ORIENTATION, d, s);
  assertEquals(fs.step?.id, 'wearable');
  assertEquals(fs.statuses.plan, 'declined');
  assertStringIncludes(flowLine(fs, d), 'declined this visit: plan · declined before: race · pending: asks(app) · first meeting: yes · opener: yes · safety hit: medical');
});

Deno.test('every step done or declined → the wrap is the step; the recap shown → nothing left', () => {
  const s = state();
  s.declinedThisVisit = ['race'];
  const d = snapshot({ connections: { plan: 'TP', wearable: 'garmin', wearableJustConnected: false, historySynced: true }, pins: [{ id: 'f-gel', name: 'Gel + Water', phase: 'during', activities: ['running'], brackets: ['90-150 min'] }], workouts: [{ id: 'w1', date: '2026-10-10', title: 'Long run', type: 'run', minutes: 120, fueled: true, fueledWithPin: 'f-gel' }] });
  const fs = flowStateFor(ORIENTATION, d, s);
  assert(fs.complete);
  assertEquals(fs.step?.id, 'wrap');
  s.celebrated.push('setup_done');
  assertEquals(flowStateFor(ORIENTATION, d, s).step, null);
});
