/** Box 6: each of the five hard rules is caught, and the declared checks fire only where declared. */
import { assertEquals, assert } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { checkReply, stripDrawnCards, type CheckContext } from './check.ts';
import { ORIENTATION } from './flows/orientation.ts';
import { SENSITIVE } from './flows/shared.ts';
import { snapshot } from './fakes.ts';
import { HARD_RULES, type StepDeclaration } from './types.ts';
import { DEFAULT_LINES } from './scripted.ts';

const ctx = (over: Partial<CheckContext> = {}, step: StepDeclaration = ORIENTATION.steps.plan): CheckContext => ({
  snapshot: snapshot(), step, toolsCalled: [], receipts: [], cards: [], earlier: [], athleteWords: [], safetyHit: false, writeRefused: [], ...over,
});
const rules = (text: string, c: CheckContext) => checkReply(text, [], c).map((v) => v.rule);

Deno.test('rule 1 · no invented status: connected, pinned, fueled, a race that is not there', () => {
  assert(rules('Your Garmin is connected now.', ctx()).includes('status_truthful'));
  assert(rules("You've already pinned a formula.", ctx()).includes('status_truthful'));
  assert(rules('Saturday is fueled.', ctx({ athleteWords: ['Saturday'] })).includes('status_truthful'));
  assertEquals(rules('Your Garmin is connected now.', ctx({ snapshot: snapshot({ connections: { plan: null, wearable: 'garmin', wearableJustConnected: false, historySynced: false } }) })), []);
});

Deno.test('rule 2 · no claimed action without a tool: "passed on to the team", "I\'ve added it"', () => {
  assert(rules("I've passed that along to the team.", ctx()).includes('actions_backed'));
  assertEquals(rules("I've passed that along to the team.", ctx({ toolsCalled: ['saveFeedback'] })), []);
  assert(rules("I've added it to your calendar.", ctx()).includes('actions_backed'));
  assertEquals(rules("I've added it to your calendar.", ctx({ receipts: [{ what: 'race', line: 'Race added.' }] })), []);
});

Deno.test('rule 3 · no computed number: a fueling amount, or a weekday nothing gave', () => {
  assert(rules('Aim for 60 g of carbs per hour.', ctx()).includes('no_computed_number'));
  assert(rules("Let's fuel Saturday's run.", ctx()).includes('no_computed_number'));
  assertEquals(rules("Let's fuel Saturday's run.", ctx({ athleteWords: ['I run long on Saturdays'] })), []);
  assertEquals(rules("Let's fuel Saturday's run.", ctx({ snapshot: snapshot({ workouts: [{ id: 'w', date: '2026-10-10', title: 'Long run', type: 'run', minutes: 100 }] }) })), []);
});

Deno.test('rule 4 · no write without a yes: the loop refuses the tool and Check reports it', () => {
  const v = checkReply('Noted.', [], ctx({ writeRefused: ['rememberFact'] }));
  assertEquals(v.map((x) => x.rule), ['write_without_yes']);
});

Deno.test('rule 5 · nothing after a safety hit: a card or a steer back to a step', () => {
  const c = ctx({ safetyHit: true, cards: [{ id: 'x', kind: 'connect_plan', step: 'plan', payload: {} }] });
  assert(rules('Your training plan arrives here.', c).includes('after_safety'));
  assert(rules('Want to keep going with your plan?', ctx({ safetyHit: true })).includes('after_safety'));
  assertEquals(rules('Thank you for telling me. A registered dietitian can really help here.', ctx({ safetyHit: true }, SENSITIVE)), []);
});

Deno.test('declared checks fire only on their step: the broad race question, a pattern with no data, two questions, a repeated sentence, an app claim', () => {
  assert(rules('Are you racing or just building fitness?', ctx({}, ORIENTATION.steps.race)).includes('race_question_narrow'));
  assertEquals(rules('Are you racing or just building fitness?', ctx({}, ORIENTATION.steps.plan)).includes('race_question_narrow'), false);
  assert(rules('Looks like Saturdays are your long run day.', ctx({}, ORIENTATION.steps.week)).includes('pattern_from_data'));
  assertEquals(rules('Looks like Saturdays are your long run day.', ctx({ toolsCalled: ['longRunPattern'] }, ORIENTATION.steps.week)).includes('pattern_from_data'), false);
  assertEquals(rules('Looks like Saturdays are your long run day.', ctx({ athleteWords: ['I go long on Saturdays'] }, ORIENTATION.steps.week)).includes('pattern_from_data'), false);   // stated-then-asked: the athlete said it
  assert(rules('Do you use a plan app? Which one is it?', ctx()).includes('one_question'));
  const line = 'Your planned workouts arrive here ready to fuel, every one of them.';
  assert(rules(line, ctx({ earlier: [line] })).includes('same_words_twice'));
  assert(rules('The app will remind you before each one.', ctx()).includes('no_app_claims'));
  assert(rules('Here is Cozumel.', ctx({ foreignNames: ['Cozumel'] })).includes('name_from_data'));
});

Deno.test('a scripted line gets only the hard rules', () => {
  const v = checkReply("That's coming soon. I can't help with it yet. Want to keep going with your watch?", [], { ...ctx(), scripted: true });
  assertEquals(v, []);
  assertEquals(checkReply(DEFAULT_LINES.check_in, [], { ...ctx(), scripted: true }), []);
  assertEquals(checkReply(DEFAULT_LINES.safe, [], { ...ctx(), scripted: true }), []);
});

Deno.test('hard rules 6 and 7 are universal (Q4a): two questions or an unbacked pattern are caught on any step, scripted lines included', () => {
  assertEquals(HARD_RULES.length, 7);
  assert(rules('Do you use a plan app? Which one is it?', ctx({}, SENSITIVE)).includes('one_question'));
  assert(rules('Looks like Saturdays are your long run day.', ctx({}, ORIENTATION.steps.plan)).includes('pattern_from_data'));
  const two = checkReply("That's coming soon. Want to keep going with your plan? Or your watch?", [], { ...ctx(), scripted: true });
  assertEquals(two.map((v) => v.rule), ['one_question']);
});

Deno.test('a card drawn in words is stripped: table rows, separator rules, "(card: …)" notes; the lead-in stays', () => {
  const t = 'Where do you train?\n\n| Your training platform |\n|---|\n| Strava |\n| Garmin Coach |\n\n(card: formula_picker)\n[card: connect plan]';
  const s = stripDrawnCards(t);
  assertEquals(s.text, 'Where do you train?');
  assertEquals(s.stripped.length, 6);
  assertEquals(stripDrawnCards('Final Surge connected - nice. Which watch?'), { text: 'Final Surge connected - nice. Which watch?', stripped: [] });
});
