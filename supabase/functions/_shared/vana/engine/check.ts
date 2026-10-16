/**
 * Box 6 · Check (code): reads the words before the athlete does (proposal v7 §4.6; README "checks carried from v26").
 *
 * The seven hard rules run on every reply, scripted lines included: no invented status, no claimed action without a
 * tool, no computed number, no write without a yes, nothing after a safety hit (the flow ended), one question per reply,
 * no history pattern without a tool result (Q4a, 2026-10-15). The step's declared checks run on top. The regexes are the
 * v26 guard's (ops/experiments/setup-chat/check.ts), kept so the harness's scorer and this net never disagree.
 * fail → the loop sends [GUARD] once → still failing → the fixed safe line.
 */
import type { Card, CheckRule, Receipt, Snapshot, StepDeclaration } from './types.ts';
import { HARD_RULES } from './types.ts';
import { dayStem, weekdayOf } from './dates.ts';
import { historyPattern, nextLong, pinFor } from './gate.ts';

export interface Violation { rule: CheckRule; detail: string }

export interface CheckContext {
  snapshot: Snapshot;
  step: StepDeclaration;
  /** Tool names that ran in this step this turn (box 2 of hard rule 2). */
  toolsCalled: string[];
  receipts: Receipt[];
  cards: Card[];
  /** Vana's earlier lines in this conversation. */
  earlier: string[];
  /** What the athlete said, this turn and before: a weekday they named is theirs to hear back. */
  athleteWords: string[];
  /** Names from other athletes' data that must never appear (the harness passes its dataset's race words). */
  foreignNames?: string[];
  safetyHit: boolean;
  /** A write tool was called without a yes: the loop refused it and reports it here (hard rule 4). */
  writeRefused: string[];
  /** The scripted line was built by code: skip the model-only checks. */
  scripted?: boolean;
}

// ---- the v26 patterns -------------------------------------------------------------------------------------------
const HEDGE_WORDS = /\b(not|n't|never|no|once|after|when|if|until|will|to|can|could|want|would|wanna|let'?s|should)\b/i;
const FUEL_NUMBER = /\b\d+(\.\d+)?\s?(g|grams?|mg|milligrams?|ml|milliliters?|kcal|cal|calories)\b|\b\d+(\.\d+)?\s*(carbs?|grams?|g)?\s*(per|\/|an?)\s*(hour|hr|h)\b/i;
const APP_CLAIM = /\b(we|the app|it)('ll| will) fuel (each|every|them|it)\b[^.?!]{0,20}\b(as|when) (it|they) (arrive|land|sync)|\b(other|rest of your) workouts are (in|on) your (cards|calendar|timeline)\b|\b(app|it|we)('ll| will) remind you\b|\bswap (it|that|them) in (any ?time|whenever)\b|\b(garmin|watch) will (sync|pull|bring)\b|\byou'?ll be able to\b|\bwhen (meal planning|it) (lands|arrives|launches|ships)\b|\bfuels? (itself|themselves)\b|\b(carry|carries|cover|covers|fuel|fuels) (every|all( of)?|each) (your )?(long |new )?(runs?|rides?|workouts?|sessions?|one)\b|\bfuels? what you (really |actually )?(run|ride|do)\b|\bas you do them\b|\bautomatic(ally)?\b|\bevery (workout|session|run|ride)\b[^.?!]{0,30}\b(gets?|is|will be|are) fueled\b|\b(i'?ll|i will|i can) scale\b|\b(fuels?|fuel it|fueling it|fuelled) (it |them )?(as it happens|from there|on its own|for you)\b|\bshows? up (on|in) your (calendar|timeline) once\b|\bno (manual|guesswork)\b|\b(team|they|someone)\b[^.?!]{0,30}\b(will|'ll)\b[^.?!]{0,20}\b(fix|correct|update|change|adjust)\b/i;
const BROAD_RACE_Q = /\b(rac(e|ing)|training (toward|for))\b[^.?!]{0,50}\bor\b[^.?!]{0,40}\b(fitness|fun|for now|flexible|the joy)\b[^.?!]*\?/i;
const FEEDBACK_CLAIM = /\b(passed|sent|shared|flagged|noted|logged|saved|forwarded|passing)\b[^.?!]{0,40}\b(team|feedback|along)\b|\b(let me|i'?ll) (flag|pass|send|note) (it|that|this)\b|\b(team'?s?|they'?ve?|they'?re)\b[^.?!]{0,20}\b(got|taking|noted|has|have)\b[^.?!]{0,30}\b(feedback|request|noted|it)\b/i;
const WRITE_CLAIM = /\b(i'?ve|i have)\s+(added|scheduled|created|put|booked|saved|pinned|remembered|noted)\b|(?<!\b(?:gets?|will be|can be|would be|to be|be)\s)\b(added|scheduled|booked)\b[^.?!]{0,30}\b(to|on) your calendar\b/i;
const PATTERN = /\b(looks? like|seems? like|i (can )?see (that )?you|you usually|you tend to|usually do|pattern of|long[- ](run|ride|workout) days?)\b[^.?!]{0,60}\b(sun|mon|tues|wednes|thurs|fri|satur)days?\b|\b(sun|mon|tues|wednes|thurs|fri|satur)days?\b (are|is) (usually |typically )?your (long|usual)/i;
const Q_OPENING = /^(do|does|did|want|would|should|are|is|can|could|will|have|has)\b/i;
const SUBJECT: Record<string, RegExp> = {
  connect_plan: /\b(plan|platform|training ?peaks|final ?surge|runna|v\.?o2|coach)\b/i, connect_wearable: /\b(garmin|watch|wearable|device)\b/i,
  formulas: /\b(formula|fuel|fueling|gels?|chews?|drink|bottles?)\b/i, workout_card: /\b(run|ride|swim|workout|session|long|calendar|save)\b/i,
  race_card: /\b(race|event|marathon|half|70\.3|ironman|triathlon|training for)\b/i, week_planner: /\b(week|days?|schedule|routine|hours|train)\b/i,
};

export const sentences = (t: string): string[] => t.split(/(?<=[.?!])\s+|\n+/).filter(Boolean);
export const questionCount = (t: string): number => sentences(t).filter((s) => /\?$/.test(s.trim()) || (Q_OPENING.test(s.trim()) && /\.$/.test(s.trim()))).length;

/** The weekdays the reply may name: from the file, a tool result or the athlete's own words. */
export function knownDayStems(d: Snapshot, athleteWords: string[]): string[] {
  const out = new Set<string>();
  for (const w of d.workouts) out.add(dayStem(weekdayOf(w.date)));
  for (const w of d.week ?? []) out.add(dayStem(w.day));
  if (d.race) out.add(dayStem(weekdayOf(d.race.date)));
  const p = historyPattern(d); if (p) out.add(dayStem(p.weekday));
  for (const t of [...athleteWords, ...d.memories]) for (const m of t.matchAll(/\b(mon|tues|wednes|thurs|fri|satur|sun)/gi)) out.add(m[1].toLowerCase());
  return [...out];
}

export function checkReply(text: string, captions: string[], ctx: CheckContext): Violation[] {
  const out: Violation[] = [];
  const bad = (rule: CheckRule, detail: string) => out.push({ rule, detail });
  const declared = new Set<CheckRule>([...HARD_RULES, ...ctx.step.checks]);
  const d = ctx.snapshot;
  const all = [text, ...captions].join(' ');
  const nl = nextLong(d);
  const st = { plan: d.connections.plan, wearable: d.connections.wearable, race: d.race?.name ?? null, formulaPinned: d.pins.length > 0, longRunFueled: !!nl?.fueled, pinCovers: !d.pins.length || !nl ? null : !!pinFor(d, nl) };

  // hard rule 5: nothing after a safety hit that ended the flow (eating-disorder signs, distress) — no card, no steer back to a step
  if (ctx.safetyHit && ctx.step.id !== 'sensitive' && (ctx.cards.length || /\b(keep going|next step|set ?up|your (plan|garmin|formula|race))\b/i.test(all))) bad('after_safety', 'a step, card or steer after a safety hit; the flow ended for this conversation');
  // hard rule 4: the loop already refused the write; reported here so the counter sees it
  for (const w of ctx.writeRefused) bad('write_without_yes', `${w} was called without the athlete's yes; refused`);
  // hard rule 1: a status the file doesn't show
  for (const s of sentences(all).flatMap((x) => x.split(/,|;|\bbut\b|\bthough\b|\bwhile\b|—|–/))) {
    if (/meal plan|from your plan|in your plan|your plan'?s? (workouts|sessions)/i.test(s)) continue;
    if (/\b(might|may|could|maybe|possibl\w*|seems?)\b/i.test(s)) continue;
    const wear = /\b(garmin|watch|wearable)\b/i.test(s);
    const plan = /\b(training ?peaks|final ?surge|training plan|your plan)\b/i.test(s);
    if (/\b(synced|sync|pulled|showing|brought)\b[^.?!]{0,12}\b(any |no |your )?(workouts?|sessions?|activities)\b/i.test(s)) continue;
    const neg = /\b(isn't|aren't|not|haven't|hasn't|no)\b[^.?!]{0,25}\b(connected|linked|synced)\b|\b(can'?t|cannot|don'?t) see (your|a|any)\b[^.?!]{0,20}\b(plan|garmin|watch|training)\b/i.test(s);
    const pos = !neg && /\b(is|are|'s|now|already|got)\b[^.?!]{0,15}\b(connected|linked|synced)\b/i.test(s) && !HEDGE_WORDS.test(s.replace(/\bnow\b/i, ''));
    if (pos && wear && !st.wearable) bad('status_truthful', "says the wearable is connected; it isn't");
    if (pos && plan && !st.plan) bad('status_truthful', "says the plan is connected; it isn't");
    if (neg && wear && st.wearable) bad('status_truthful', "says the wearable isn't connected; it is");
    if (neg && plan && st.plan) bad('status_truthful', "says the plan isn't connected; it is");
    if (/\bno race\b|\b(don'?t|can'?t) see (a|any) race\b/i.test(s) && st.race) bad('status_truthful', "says there's no race; there is");
    if (/\b(you'?ve|you have|already|is|'s|now)\b[^.?!]{0,20}\bpinned\b/i.test(s) && !/\b(not|once|when|after|until|tap)\b/i.test(s) && !st.formulaPinned) bad('status_truthful', 'says a formula is pinned; none is');
    if ((/\b(is|'s|now|already|got)\b[^.?!]{0,20}\bfueled\b/i.test(s) || /\b(minutes|min|run|ride|workout)\s*[,—–-]\s*fueled\b/i.test(s) || /^\s*(and )?fueled\b/i.test(s)) && !/\b(not|once|when|after|until|tap|save|will be|gets?)\b/i.test(s) && !st.longRunFueled) bad('status_truthful', "says the long workout is fueled; it isn't yet");
    if (declared.has('pin_covers') && st.pinCovers === false && /\b(with|using) (the )?[a-z +]{0,30}\byou (just )?pinned\b|\b(gels?|formula|pin|chews?|bottles?)\b[^.?!]{0,20}\b(still )?covers? (it|this|that|the (run|ride|distance|workout|length)|your (long|run|ride)|(sun|mon|tues|wednes|thurs|fri|satur)day'?s)\b/i.test(s)) bad('pin_covers', "says the pinned formula covers the long workout; it is outside the formula's length bracket");
  }
  // hard rule 2: a claimed action with no tool behind it
  const wroteSomething = ctx.receipts.length > 0 || ctx.toolsCalled.some((t) => /^(saveFeedback|flagSensitive|rememberFact|setSetting|forgetFact|createEvent|logMeal)$/.test(t));
  if (FEEDBACK_CLAIM.test(all) && !ctx.toolsCalled.some((t) => t === 'saveFeedback' || t === 'flagSensitive')) bad('actions_backed', 'says it was passed on to the team, but saveFeedback was not called');
  if (WRITE_CLAIM.test(all) && !wroteSomething) bad('actions_backed', 'claims a save, add or pin that no tool or receipt backs');
  // hard rule 3: a computed number — fueling numbers, weekdays or dates nothing gave
  if (FUEL_NUMBER.test(all)) bad('no_computed_number', 'gives a fueling number (grams, ml, kcal, carbs per hour); numbers come from the app');
  const known = knownDayStems(d, ctx.athleteWords);
  const said = [...all.matchAll(/\b(mon|tues|wednes|thurs|fri|satur|sun)days?\b/gi)].map((m) => m[1].toLowerCase());
  const unknown = [...new Set(said.filter((x) => !known.includes(x)))];
  if (unknown.length) bad('no_computed_number', `names ${unknown.map((x) => x + 'day').join(', ')}, which nothing in the file, a tool result or the athlete gave`);

  // hard rule 6: one question per reply
  { const q = questionCount(text); if (q > 1) bad('one_question', `asks ${q} questions; one at most per reply`); }
  // hard rule 7: a history pattern needs a tool result (or the athlete's own words)
  if (PATTERN.test(all) && !ctx.toolsCalled.includes('longRunPattern') && !historyPattern(d) && !ctx.athleteWords.some((w) => /\b(mon|tues|wednes|thurs|fri|satur|sun)day/i.test(w))) bad('pattern_from_data', 'states a pattern with no history read');

  if (ctx.scripted) return out;
  // declared, model steps only
  if (declared.has('no_app_claims')) { const ac = all.match(APP_CLAIM); if (ac) bad('no_app_claims', `describes what the app does on its own ("${ac[0]}")`); }
  if (declared.has('race_question_narrow') && BROAD_RACE_Q.test(all)) bad('race_question_narrow', 'asks the broad "racing or just building fitness?" question; the race card carries the chip');
  if (declared.has('lead_in_names_step')) for (const c of ctx.cards) { const re = SUBJECT[c.kind]; if (re && text.trim() && !re.test(text)) bad('lead_in_names_step', `shows the ${c.kind.replace('_', ' ')} card but the words never say what it is for`); }
  if (declared.has('name_from_data') && ctx.foreignNames?.length) {
    const hit = ctx.foreignNames.find((n) => new RegExp(`\\b${n.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'i').test(all));
    if (hit) bad('name_from_data', `names "${hit}", which is not this athlete's race or anything they said`);
  }
  if (declared.has('same_words_twice') && ctx.earlier.length) {
    const norm = (x: string) => x.toLowerCase().replace(/[^a-z' ]+/g, ' ').replace(/\s+/g, ' ').trim();
    const seen = new Set(ctx.earlier.flatMap((e) => sentences(e).map(norm)).filter((x) => x.split(' ').length >= 7));
    const rep = sentences(text).map(norm).find((x) => seen.has(x));
    if (rep) bad('same_words_twice', `repeats a sentence word for word from earlier ("${rep.slice(0, 80)}")`);
  }
  return out;
}

/** The [GUARD] message: what was rejected, the file as the truth, and the exact format to answer in. */
export function guardMessage(violations: Violation[], flowLines: string[], captioned: number): string {
  const format = ['WORDS: <your words, or - if the reply had none>', ...Array.from({ length: captioned }, (_, i) => `CAPTION ${i + 1}: <the caption for card ${i + 1}, corrected>`)].join('\n');
  return `[GUARD] The app rejected these words before showing them:\n${violations.map((v) => `- ${v.detail}`).join('\n')}\nTHE ATHLETE FILE is the truth: ${flowLines.join(' · ')}\nRewrite the words only (the cards stay as shown; the athlete has not tapped anything yet). Fix only what was rejected; keep the same intent and any line about this athlete that was fine. Reply in exactly this format and nothing else:\n${format}`;
}

/** Parse the guard reply back into words and captions. */
export function parseGuardReply(text: string, captioned: number): { words: string; captions: (string | null)[] } {
  const words = (text.match(/^WORDS:\s*([\s\S]*?)(?=\n\s*CAPTION \d+:|$)/m) ?? [])[1]?.trim() ?? text.trim();
  const captions = Array.from({ length: captioned }, (_, i) => (text.match(new RegExp(`^CAPTION ${i + 1}:\\s*(.+)$`, 'm')) ?? [])[1]?.trim() ?? null);
  return { words: words === '-' ? '' : words, captions };
}
