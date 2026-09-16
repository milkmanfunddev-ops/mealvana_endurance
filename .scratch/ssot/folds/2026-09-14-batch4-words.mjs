import { parse, serialize, apply } from '/Users/leemartin/development/mealvana_endurance/docs/ssot/decisions/_page/sync.mjs';
import fs from 'node:fs';
const P = '/Users/leemartin/development/mealvana_endurance/.scratch/mealplanning/decisions.md';
const R = '/Users/leemartin/development/mealvana_endurance/docs/ssot/decisions/mealplanning.md';
const D = '2026-09-14';
const proposals = parse(fs.readFileSync(P, 'utf8'));
const ssot = parse(fs.readFileSync(R, 'utf8'));
const at = '2026-09-14T13:30:00Z';
const verdicts = {
  'mp-144': { verdict: 'amend', at, text: 'we need to do a little more work on this!  as an admin we also need to have it be the case where we can go onto that page and write comments and say if it is a good recipe or not and give feedback and have that appear in our database for further consideration.  but only for logged in admin users.  but the rest of this is good!' },
  'mp-145': { verdict: 'amend', at, text: "let's keep these tiles but we don't need to show icons like this anywhere I don't think.  I think they clutter up the ui" },
  'mp-230': { verdict: 'amend', at, dropped: [2], text: 'it should be more flexible than that and there can be a little "show more" where it raises a sheet and can show lots of different options.  and remember this picker hopefully is the result of some tool some semantic searching something with our pgvectors right?' },
  'mp-231': { verdict: 'amend', at, dropped: [1, 2, 3], text: 'so please remember that this order doesn\'t have to be fixed like this.  perhaps someone doesn\'t eat breakfast or snacks.  also, remember that a user will be cooking a subset of these meals on the weekend or some other time and may not be cooking for a set "week".  perhaps for several days.  we can default to a week but not necessarily.  and the idea that Xuan wants is that you cook like 3 meals or something like that on the weekend and then eat throughout the week what you cooked in this batch process.  this is why servings are important and that there is enough servings and that recipes scale up throughout the week accordingly.  some people do not want to batch though!   in which case we do things differently.  moreover there needs to be a high precedence for liked meals and meals already cooked.  one potential option is to just mealplan or make a draft mealplan of everything that they ate last week for instance and when we are suggesting things there needs to be a super high preference for foods they have already cooked!' },
  'mp-244': { verdict: 'amend', at, text: 'we also need a tap back to the original recipe(s) for further information as needed.  but hopefully that can be done through some minimal ui' },
  'mp-245': { verdict: 'amend', at, text: 'I do hope Vana can call the feedback tool for wiredash to have a uniform wiredash entry for everything if possible' },
  'mp-255': { verdict: 'amend', at, text: "remember we don't need this entitlements table anymore" },
  'mp-262': { verdict: 'amend', at, dropped: [1, 2], text: 'ok Xuan and I are both ratifying and I hope that we can keep things in /docs/ssot for right now.  this should be portable though and should be runnable by xuan at some point so we need to make sure that other users can access this document easily and it is portable from one laptop to another' },
  'mp-237': { verdict: 'reject', at, text: 'the general conversation doesn\'t need example chips.  we can think of a potential opener though based off of which route they are on.  like "I see you are planning an event" or "I see you are carb loading" or something like that' },
  'mp-240': { verdict: 'reject', at, text: 'nope it is not this, it is variable.  a user can change which day the week starts and how many days and what not as settings.  we can have this as default but it has to be able to be changed' },
  'mp-250': { verdict: 'reject', at, text: "we won't ship without this purchase/7day free trial thing.  so no mealplanning without this" },
};
const r = apply(verdicts, proposals, ssot);
if (r.refused.length) throw new Error(JSON.stringify(r.refused));
const get = id => proposals.decisions.find(d => d.id === id);
const rewrite = (id, fn, note) => { const d = get(id); fn(d); d.meta.work = 'pending'; d.history.push({ date: D, note: note || "rewritten from Lee's words" }); };

rewrite('mp-144', d => {
  d.parts.decision = '1. Meal feedback holds one vote per person per meal. Tapping the same vote twice clears it. The detail screen shows the thumbs optimistically, and a thumbs down shows a note that Vana will not suggest that meal again.\n2. A disliked meal is filtered out of suggestions but still visible when browsing. A thumbs up adds 0.10 to the meal\'s search score.\n3. A signed-in admin sees a comment box on every meal page. They can say whether it is a good recipe and why, and each comment lands in a table for the team to review. Athletes never see the box.';
  d.parts.why += ' Lee on 2026-09-14: admins need to comment on recipes from the page and have it reach the database.';
  d.parts.touches += ' Admin flag, meal_reviews table, meal detail screen.';
});
rewrite('mp-145', d => {
  d.title = 'Meal icons are classified and stored, but not drawn';
  d.parts.decision = '1. The 23-key classifier stays and the key is stored on library, saved and plan meals, copied along on add and swap, so the data is there when it is wanted.\n2. Icons are not drawn on tiles, cards, the plan bar or the review sheet. Tiles keep their shape without the glyph.\n3. A meal with no photo shows a plain placeholder, not an icon.';
  d.parts.why = 'Lee on 2026-09-14: the icons clutter the UI. The classification is cheap to keep and costs nothing unseen.';
  d.parts.touches += ' Meal card, plan tile, plan bar, review sheet.';
});
rewrite('mp-230', d => {
  d.parts.decision = d.parts.decision.split('\n').map((l, i) => i === 1 ? '2. A picker shows a handful of meals from the semantic search over the library, with saved meals boosted. A "Show more" raises a sheet with many more options from the same search. The count is not fixed.' : l).join('\n');
  d.parts.why += ' Lee on 2026-09-14: the picker should be flexible, with a show-more sheet, and fed by the semantic search over the embedded library.';
});
rewrite('mp-231', d => {
  d.title = 'How a cooking period fills up';
  d.parts.question = 'Which meals get planned, over what span, and what gets suggested first.';
  d.parts.decision = '1. The order of meal types is not fixed. A person may skip breakfast, snacks or any type, and the walk only covers the types they plan.\n2. The plan spans a cooking period. A week is the default and the athlete can change it, so several days is fine.\n3. In batch mode the athlete cooks a few meals at one sitting and eats them across the period. Servings scale so the batch covers the days, and coverage counts servings against the period, not a fixed 14 slots.\n4. People who do not batch plan per day instead, and the walk, coverage and review follow that mode.\n5. Suggestions give the highest weight to meals the athlete has liked or already cooked. One tap drafts the period from what they ate last time.\n6. "Draft it for me" runs deterministically. The model selects nothing and only presents the result.';
  d.parts.why = 'Lee on 2026-09-14: the order is not fixed, the span is not a set week, batch cooking is cooking a few meals and eating them through the period, so servings must scale, non-batchers plan differently, and already-cooked or liked meals must come first.';
  d.parts.alternatives = 'A fixed dinner-lunch-breakfast-snack walk over 14 slots (the earlier reading), rejected as too rigid.';
  d.parts.touches = 'Chip logic, planning prompt, coverage service, plan bar denominator, batch setting, suggestMeals ranking, draftWeek tool, settings.';
});
rewrite('mp-244', d => {
  d.parts.decision += '\n5. Each row can tap back to the recipe or recipes it came from, through the count-badge sheet every multi-meal row already has, so no new control is added.';
  d.parts.why += ' Lee on 2026-09-14: a tap back to the original recipe, through minimal UI.';
});
rewrite('mp-245', d => {
  d.parts.decision += '\n6. Vana\'s feedback tool also files a Wiredash entry, so typed feedback and shaken reports land in one place. Wiredash entries are created on the device, so the server tool hands the row to the app to file. This is the reading; the device hand-off is the open detail.';
  d.parts.why += ' Lee on 2026-09-14: one uniform Wiredash entry for everything, if possible.';
});
rewrite('mp-255', d => {
  d.parts.decision = d.parts.decision.split('\n').slice(0, 2).join('\n') + '\n3. There is no entitlements table. Whether a person is in trial or paid is read from the store subscription state, and nothing about it is mirrored or synced.';
  d.parts.why += ' Lee on 2026-09-14: the entitlements table is not needed under the trial model.';
});
rewrite('mp-262', d => {
  d.title = 'Lee and Xuan both ratify, and the record must be portable';
  d.parts.question = 'Who ratifies, where the specs and decisions live, and who else must be able to run the page.';
  d.parts.decision = '1. Lee and Xuan both ratify. A spec or decision is settled when either has approved it on the page.\n2. Specs and the decision record stay in the app repo under docs/ssot for now. The QA repo is not touched.\n3. The decisions page, its files and its tooling are portable. Another person on another laptop can open the page, see the same record, and run the skills. Nothing depends on one machine.\n4. The prototype stays in its own repo. No TypeScript is copied into the app. SQL migrations live in the app repo.';
  d.parts.why = 'Lee on 2026-09-14: both ratify, keep things in docs/ssot for now, and Xuan must be able to run this from another laptop.';
  d.parts.alternatives = 'Ratification only in the QA repo and only by Xuan (the earlier reading).';
  d.parts.touches = 'docs/ssot/decisions, the page artifact and its sharing, the skills, the QA repo boundary.';
});

// New cards from the three rule-carrying rejections.
const nextId = () => { const m = Math.max(...[...proposals.decisions, ...ssot.decisions].map(d => +d.id.split('-')[1])); return `mp-${String(m + 1).padStart(3, '0')}`; };
const add = (title, meta, parts, from) => { const id = nextId(); proposals.decisions.push({ id, title, meta: { status: 'proposed', image: 'none', caption: '', work: 'pending', ...meta }, parts, history: [{ date: D, note: `from Lee's rejection of ${from}` }] }); return id; };
const a = add('The general conversation opens on the screen underneath', { category: 'The planning conversation', screen: 'Vana sheet', source: 'Lee on the page 2026-09-14, on mp-237' }, {
  context: 'The general conversation used to open with three example chips. Vana lives on three screens and knows what is in view on each.',
  question: 'What the general conversation says first.',
  decision: '1. No example chips. The general conversation opens with a line that reads the screen underneath, such as "I see you are planning an event" or "I see you are carb loading".\n2. When the screen underneath says nothing useful, the opener falls back to the personal opener that every conversation already carries.\n3. Offline, rate limit and out-of-trial failures keep their one visible outcome each.',
  why: 'Lee on 2026-09-14: the general conversation does not need example chips; open from the route they are on.',
  alternatives: 'Three example chips and a "Start a meal plan" offer (mp-237), rejected.',
  touches: 'vana-chat opener, situation resolver, sheet conversation.',
});
const b = add('Week start and period length are settings', { category: 'Plan tab', screen: 'Settings, Plan tab', source: 'Lee on the page 2026-09-14, on mp-240' }, {
  context: 'The plan week was fixed to Sunday and cook days to fixed offsets. Athletes cook on different days and for different spans.',
  question: 'Which day a plan period starts and how long it runs.',
  decision: '1. The start day and the length of a plan period are settings the athlete can change. Sunday and seven days are the defaults.\n2. Cook days derive from those settings, not from fixed offsets.\n3. The Plan tab, coverage, the review sheet and the check-in opener all read the settings.',
  why: 'Lee on 2026-09-14: it is variable; a user can change which day the week starts and how many days.',
  alternatives: 'Sunday start with cook days at plus three and plus five (mp-240), rejected.',
  touches: 'Settings, week start, plan queries, session dates, review sheet, check-in opener.',
});
const c = add('Meal planning ships only with the trial and purchase model', { category: 'Pro and paywall', screen: 'Paywall', source: 'Lee on the page 2026-09-14, on mp-250' }, {
  context: 'The earlier plan shipped meal planning dark behind a gate flag and opened it later by granting entitlements or enabling purchase.',
  question: 'Whether meal planning can reach prod before the trial exists.',
  decision: '1. Meal planning does not ship until the seven-day trial and purchase model is live. No dark launch and no gate flag as the release plan.\n2. The trial move (see the open question beside the trial card) is therefore on the critical path for the meal-planning release.',
  why: 'Lee on 2026-09-14: we will not ship without the purchase and seven-day trial, so no meal planning without it.',
  alternatives: 'Shipping dark with a gate flag and a Buy button behind a purchase flag (mp-250), rejected.',
  touches: 'Release plan, gate flag, Pro screen, RevenueCat products.',
});
const q = get('mp-267');
q.parts.context += ' Lee added on 2026-09-14: the app-side entitlements table goes away under the trial model, and meal planning does not ship until the trial exists.';
q.history.push({ date: D, note: 'context extended from Lee\'s verdicts on mp-250 and mp-255' });
fs.writeFileSync(P, serialize(proposals));
fs.writeFileSync(R, serialize(ssot));
console.log('applied', r.applied.map(x => x.id + ':' + x.to).join(' '), '| new', a, b, c);
