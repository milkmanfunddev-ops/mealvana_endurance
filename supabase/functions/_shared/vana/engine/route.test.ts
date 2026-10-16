/** Box 4: intents + flow state → a plan of at most two steps, writes first, leftovers pending. */
import { assertEquals, assert, assertStringIncludes } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { flowLine, flowStateFor } from './assemble.ts';
import { freshState, DEFAULT_FLOWS } from './engine.ts';
import { ORIENTATION } from './flows/orientation.ts';
import { NONE } from './flows/none.ts';
import { route } from './route.ts';
import { snapshot } from './fakes.ts';

const fresh = () => { const s = freshState('c1', 'u1'); s.flow = 'orientation'; return s; };

Deno.test('"not now, but how do I see my workouts" = declines(step) then asks(app): plan skipped in code, Answer with [declined: plan]', () => {
  const s = fresh();
  const fs = flowStateFor(ORIENTATION, snapshot(), s);
  assertEquals(fs.step?.id, 'plan');
  const plan = route([{ label: 'declines', target: 'step' }, { label: 'asks', target: 'app' }], fs, s, 'not now, but how do I see my workouts?', DEFAULT_FLOWS);
  assertEquals(plan.steps.map((p) => p.step.id), ['answer']);
  assertEquals(plan.steps[0].notes, ['[declined: plan]']);
  assertEquals(s.declinedThisVisit, ['plan']);
  assertEquals(plan.pending, []);
});

Deno.test('a bare "not now" runs the next step\'s agent with [declined: …]; a blanket no closes both connections and ends the offers', () => {
  const s = fresh();
  const plan = route([{ label: 'declines', target: 'step' }], flowStateFor(ORIENTATION, snapshot(), s), s, 'not now', DEFAULT_FLOWS);
  assertEquals(plan.steps.map((p) => p.step.id), ['wearable']);
  assertEquals(plan.steps[0].notes, ['[declined: plan]']);
  const s2 = fresh();
  const plan2 = route([{ label: 'declines', target: 'all_connections' }], flowStateFor(ORIENTATION, snapshot(), s2), s2, "don't link anything, let me try the app first", DEFAULT_FLOWS);
  assertEquals(s2.declinedThisVisit, ['plan', 'wearable']);
  assert(s2.offersEnded);
  assertEquals(plan2.steps[0].step.id, 'week');
});

Deno.test('"remember I hate cilantro, what\'s for dinner" in the lobby = set_value then choose, the write first', () => {
  const s = freshState('c1', 'u1'); s.flow = 'none';
  const fs = flowStateFor(NONE, snapshot(), s);
  const plan = route([{ label: 'asks', target: 'memory' }, { label: 'asks', target: 'dinner' }], fs, s, 'remember I hate cilantro, what\'s for dinner?', DEFAULT_FLOWS);
  assertEquals(plan.steps.map((p) => p.step.id), ['set_value', 'choose']);
  assert(plan.steps[0].writeAllowed);
  assertEquals(plan.pending, []);
});

Deno.test('asks(other) and leaves_flow inside orientation → the scripted off_flow line with the steer; demand logged', () => {
  const s = fresh();
  const plan = route([{ label: 'asks', target: 'other' }], flowStateFor(ORIENTATION, snapshot(), s), s, 'can you plan my meals for the week?', DEFAULT_FLOWS);
  assertEquals(plan.steps[0].step.id, 'off_flow');
  assertEquals(plan.steps[0].notes, ['[steer: Want to keep going with your training plan?]']);
  assertEquals(s.demand[0].words, 'can you plan my meals for the week?');
  const s2 = fresh(); s2.offersEnded = true;
  const plan2 = route([{ label: 'leaves_flow', target: 'meal_planning' }], flowStateFor(ORIENTATION, snapshot(), s2), s2, 'plan my meals', DEFAULT_FLOWS);
  assertEquals(plan2.steps[0].step.id, 'off_flow');
  assertEquals(plan2.steps[0].notes, ['[steer: ]']);   // offers ended: the line alone
});

Deno.test('feedback → scripted ack; a vent that ends in a question also runs the active step; feedback(flow) ends the offers', () => {
  const s = fresh();
  const plan = route([{ label: 'feedback', target: 'vana' }, { label: 'asks', target: 'step' }], flowStateFor(ORIENTATION, snapshot(), s), s, 'why do you keep asking? what does connecting even do?', DEFAULT_FLOWS);
  assertEquals(plan.steps.map((p) => p.step.id), ['feedback', 'plan']);
  const s2 = fresh();
  const plan2 = route([{ label: 'feedback', target: 'flow' }], flowStateFor(ORIENTATION, snapshot(), s2), s2, 'this is so long', DEFAULT_FLOWS);
  assertEquals(plan2.steps.map((p) => p.step.id), ['feedback']);
  assert(s2.offersEnded);
  assertEquals(plan2.steps[0].notes, ['[steer: ]']);
});

Deno.test('safety wins over everything and ends the flow for the conversation; nothing routes to a flow step after it', () => {
  const s = fresh();
  const plan = route([{ label: 'answers' }, { label: 'safety', target: 'eating_disorder' }], flowStateFor(ORIENTATION, snapshot(), s), s, 'sure. honestly I skip dinner to stay light', DEFAULT_FLOWS);
  assertEquals(plan.steps.map((p) => p.step.id), ['sensitive']);
  assertEquals(s.safetyHit, 'eating_disorder');
  const later = route([{ label: 'answers' }], flowStateFor(ORIENTATION, snapshot(), s), s, 'ok lets continue setup', DEFAULT_FLOWS);
  assertEquals(later.steps.map((p) => p.step.id), ['sensitive']);
});

Deno.test('at most two steps; leftovers go pending with [then: …] on the last step; same shape merges', () => {
  const s = freshState('c1', 'u1'); s.flow = 'none';
  const fs = flowStateFor(NONE, snapshot(), s);
  const plan = route([{ label: 'asks', target: 'memory' }, { label: 'asks', target: 'dinner' }, { label: 'asks', target: 'app' }, { label: 'asks', target: 'app' }], fs, s, 'remember x, dinner?, how do I log?, where are workouts?', DEFAULT_FLOWS);
  assertEquals(plan.steps.map((p) => p.step.id), ['set_value', 'choose']);
  assertEquals(plan.pending.length, 2);
  assertStringIncludes(plan.steps[1].notes.join(' '), '[then: asks app, asks app]');
  assertEquals(s.pending.length, 2);
});

Deno.test('a second decline across visits is for good (Q7a): the row records it and the FLOW line says so', () => {
  const s = fresh();
  const d = snapshot({ steps: { plan: 'declined' } });
  const fs = flowStateFor(ORIENTATION, d, s);
  assertEquals(fs.step?.id, 'plan');   // one earlier no: offered again this visit
  const plan = route([{ label: 'declines', target: 'step' }], fs, s, 'still no', DEFAULT_FLOWS);
  assertEquals(s.declinedThisVisit, ['plan']);
  assertEquals(s.declinedForGood, ['plan']);
  assertEquals(plan.steps[0].step.id, 'wearable');
  assert(plan.why.some((w) => w.includes('for good')));
  assertStringIncludes(flowLine(flowStateFor(ORIENTATION, d, s), d), 'declined this visit: plan · declined for good: plan');
});

Deno.test('the second off-flow ask of a visit gets the scripted check-in instead of the steer, once (Q1a); declines(visit) ends the offers', () => {
  const s = fresh();
  const fs = flowStateFor(ORIENTATION, snapshot(), s);
  const one = route([{ label: 'asks', target: 'other' }], fs, s, 'can you plan my meals?', DEFAULT_FLOWS);
  assertEquals(one.steps[0].step.id, 'off_flow');
  assertEquals(one.steps[0].notes, ['[steer: Want to keep going with your training plan?]']);
  const two = route([{ label: 'asks', target: 'other' }], fs, s, 'what about recipes?', DEFAULT_FLOWS);
  assertEquals(two.steps.map((p) => p.step.id), ['check_in']);
  assertEquals(two.steps[0].notes, ['[steer: ]']);
  assert(s.checkInAsked); assertEquals(s.offFlowAsks, 2);
  const three = route([{ label: 'leaves_flow', target: 'meal_planning' }], fs, s, 'plan my meals', DEFAULT_FLOWS);
  assertEquals(three.steps[0].step.id, 'off_flow');   // never the check-in again this visit
  assertEquals(three.steps[0].notes, ['[steer: Want to keep going with your training plan?]']);
  const no = route([{ label: 'answers' }], fs, s, "no, let's finish", DEFAULT_FLOWS);
  assertEquals(no.steps[0].step.id, 'plan');
  const yes = route([{ label: 'declines', target: 'visit' }], fs, s, 'sure, another time', DEFAULT_FLOWS);
  assert(s.offersEnded); assertEquals(s.declinedThisVisit, []);
  assertEquals(yes.steps.map((p) => p.step.id), ['answer']);
  assertEquals(yes.steps[0].notes, ['[declined: visit]']);
  const after = route([{ label: 'asks', target: 'other' }], fs, s, 'gear advice?', DEFAULT_FLOWS);
  assertEquals(after.steps[0].step.id, 'off_flow'); assertEquals(after.steps[0].notes, ['[steer: ]']);
});

Deno.test('a medical hit is one turn with the sensitive agent, then the athlete\'s message decides; eating-disorder signs end the flow for the conversation (Q6)', () => {
  const s = fresh();
  const fs = flowStateFor(ORIENTATION, snapshot(), s);
  const med = route([{ label: 'safety', target: 'medical' }], fs, s, 'I take insulin for type 1', DEFAULT_FLOWS);
  assertEquals(med.steps.map((p) => p.step.id), ['sensitive']);
  assertEquals(s.safetyHit, 'medical'); assertEquals(s.flowEnded, false);
  const next = route([{ label: 'answers' }], fs, s, 'ok, lets keep going', DEFAULT_FLOWS);
  assertEquals(next.steps.map((p) => p.step.id), ['plan']); assertEquals(s.safetyHit, null);
  const s2 = fresh();
  route([{ label: 'safety', target: 'eating_disorder' }], fs, s2, 'I skip dinner to stay light', DEFAULT_FLOWS);
  assert(s2.flowEnded);
  assertEquals(route([{ label: 'answers' }], fs, s2, 'lets continue', DEFAULT_FLOWS).steps.map((p) => p.step.id), ['sensitive']);
});

Deno.test('pending survives a typed turn, named via [then: …], and is dropped only on a spoken decline (Q3c); the ruled steer texts (E8)', () => {
  const s = fresh();
  const fs = flowStateFor(ORIENTATION, snapshot(), s);
  s.pending = [{ label: 'asks', target: 'memory' }]; s.pendingWords = 'remember I hate cilantro';
  const chat = route([{ label: 'chat' }], fs, s, 'how are you?', DEFAULT_FLOWS);
  assertEquals(chat.steps[0].step.id, 'plan');
  assertStringIncludes(chat.steps[0].notes.join(' '), '[then: asks memory]');
  assertEquals(s.pending, [{ label: 'asks', target: 'memory' }]); assertEquals(s.pendingWords, 'remember I hate cilantro');
  route([{ label: 'declines', target: 'step' }], fs, s, 'not now', DEFAULT_FLOWS);
  assertEquals(s.pending, []); assertEquals(s.pendingWords, null);
  assertEquals(ORIENTATION.steps.wearable.steer, 'Want to keep going with your watch?');
  assertEquals(ORIENTATION.steps.long_run.steer, 'Want to keep going with fueling your next long workout?');
});
