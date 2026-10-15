/**
 * Fake adapters for the tests and the ops harness: a mutable Snapshot, tools that draw cards and write receipts
 * against it, an in-memory memory store and row store, tiny prompts, a fixed clock, and a model whose answers the
 * test scripts. No network, no Supabase, no SDK.
 */
import type { Adapters, ChatMessage, Clock, DataReader, MemoryStore, Model, PromptSource, RowStore, ToolRunner, Usage } from './adapters.ts';
import type { ConversationState, ReadResult, Snapshot, ToolCall, ToolOutcome, ToolSpec } from './types.ts';
import { memoryPrompts } from './prompts.ts';
import { bracketOf, fmtDate, weekdayOf } from './dates.ts';

export const TODAY = '2026-10-06';   // a Tuesday

export function snapshot(over: Partial<Snapshot> = {}): Snapshot {
  return {
    today: TODAY,
    profile: { firstName: 'Sam', gutTraining: 'moderate', metVana: false },
    connections: { plan: null, wearable: null, wearableJustConnected: false, historySynced: false },
    workouts: [], history: [], race: null, pins: [], week: null, memories: [], doll: [], steps: {},
    ...over,
  };
}

export class FakeData implements DataReader {
  reads = 0;
  constructor(public d: Snapshot) {}
  read(): Promise<Snapshot> { this.reads++; return Promise.resolve(structuredClone(this.d)); }
}

export class FakeMemory implements MemoryStore {
  facts: string[] = [];
  steps: Record<string, 'done' | 'declined'> = {};
  constructor(private data?: FakeData) {}
  remember(_u: string, fact: string): Promise<void> { this.facts.push(fact); if (this.data && !this.data.d.memories.includes(fact)) this.data.d.memories.push(fact); return Promise.resolve(); }
  setStep(_u: string, step: string, status: 'done' | 'declined'): Promise<void> { this.steps[step] = status; return Promise.resolve(); }
}

export class FakeRows implements RowStore {
  rows = new Map<string, ConversationState>();
  load(id: string): Promise<ConversationState | null> { const r = this.rows.get(id); return Promise.resolve(r ? structuredClone(r) : null); }
  save(s: ConversationState): Promise<void> { this.rows.set(s.conversationId, structuredClone(s)); return Promise.resolve(); }
}

export const fakeClock = (today = TODAY): Clock => ({ today: () => today, now: () => new Date(`${today}T09:00:00Z`) });

const FORMULAS = [
  { id: 'f-gel', name: 'Gel + Water', activities: ['running', 'cycling'], brackets: ['90-150 min', '150-240 min'], gut: ['low', 'moderate', 'high'] },
  { id: 'f-chews', name: 'Chews + Sports Drink', activities: ['running'], brackets: ['90-150 min'], gut: ['moderate', 'high'] },
  { id: 'f-bottle', name: 'Bottle Mix', activities: ['cycling'], brackets: ['150-240 min', '> 240 min'], gut: ['moderate'] },
];

/** Tools against the fake Snapshot. Cards carry their prefill so a test can read what the engine bound. */
export class FakeTools implements ToolRunner {
  calls: ToolCall[] = [];
  constructor(private data: FakeData, private memory?: FakeMemory) {}
  specs(names: string[]): ToolSpec[] {
    const kinds: Record<string, ToolSpec['kind']> = { showConnectCard: 'card', showWeekPlanner: 'card', showWorkoutCard: 'card', recommendFormulas: 'card', showRaceCard: 'card', askChoice: 'card', setupRecap: 'card', suggestMeals: 'card', handOff: 'card', rememberFact: 'write', setSetting: 'write', forgetFact: 'write', saveFeedback: 'write', flagSensitive: 'flag', react: 'react' };
    return names.map((name) => ({ name, description: name, inputSchema: { type: 'object' }, kind: kinds[name] ?? 'read' }));
  }
  run(call: ToolCall, ctx: { step: string; words: string }): Promise<ToolOutcome> {
    this.calls.push(call);
    const d = this.data.d; const i = call.input;
    const card = (kind: string, payload: unknown): ToolOutcome => ({ type: 'card', card: { id: `${kind}-${this.calls.length}`, kind, step: ctx.step, caption: typeof i.caption === 'string' ? i.caption : undefined, payload } });
    switch (call.name) {
      case 'showConnectCard': return Promise.resolve(card(`connect_${i.kind}`, { kind: i.kind, tiles: i.kind === 'plan' ? ['Final Surge', 'TrainingPeaks', "I don't have one"] : ['Connect Garmin', "I don't have one"] }));
      case 'showWeekPlanner': return Promise.resolve(card('week_planner', {}));
      case 'showWorkoutCard': return Promise.resolve(card('workout_card', { mode: i.mode, workoutId: i.workoutId, prefill: { weekday: i.weekday, type: i.type, minutes: i.minutes }, replan: i.replan ?? false }));
      case 'recommendFormulas': {
        const sport = i.sport === 'ride' ? 'cycling' : 'running'; const b = bracketOf(Number(i.minutes));
        const items = FORMULAS.filter((f) => f.activities.includes(sport) && f.brackets.includes(b)).slice(0, 3).map((f) => ({ id: f.id, name: f.name }));
        return Promise.resolve(card('formulas', { phase: i.phase, sport: i.sport, minutes: i.minutes, items }));
      }
      case 'showRaceCard': return Promise.resolve(card('race_card', { race: { name: i.name, date: i.date, distance: i.distance } }));
      case 'askChoice': return Promise.resolve(card('choices', { question: i.question, options: i.options }));
      case 'setupRecap': return Promise.resolve(card('recap', { lines: [d.connections.plan ? `Plan: ${d.connections.plan}` : 'Plan app: skipped', d.race ? `${d.race.name}` : 'Race: none'] }));
      case 'suggestMeals': return Promise.resolve(card('meal_picker', { mealType: i.mealType ?? 'dinner', filter: d.memories }));
      case 'handOff': return Promise.resolve(card('hand_off', { route: i.route }));
      case 'rememberFact': { const fact = String(i.fact ?? ''); if (!d.memories.includes(fact)) d.memories.push(fact); this.memory?.facts.push(fact); return Promise.resolve({ type: 'receipt', receipt: { what: `remembered: ${fact}`, line: `Noted: ${fact}.` } }); }
      case 'setSetting': return Promise.resolve({ type: 'receipt', receipt: { what: `${i.key} set`, line: `${i.key} is now ${i.value}.` } });
      case 'saveFeedback': return Promise.resolve({ type: 'receipt', receipt: { what: 'feedback saved', line: '' } });
      case 'flagSensitive': return Promise.resolve({ type: 'view', data: { recorded: true }, view: '(flagged privately)' });
      case 'react': return Promise.resolve({ type: 'view', data: { emoji: i.emoji }, view: `(reacted ${i.emoji})` });
      case 'appGuide': return Promise.resolve({ type: 'view', data: { topic: i.topic }, view: `guide(${i.topic}): Workouts live on the Timeline; a workout gets its fueling plan when its card is saved.` });
      case 'getWorkouts': return Promise.resolve({ type: 'view', data: d.workouts, view: d.workouts.length ? d.workouts.map((w) => `${w.title} ${w.minutes}m ${fmtDate(w.date)}`).join('; ') : 'no upcoming workouts' });
      case 'longRunPattern': { const longs = d.history.filter((w) => w.minutes >= 90); return Promise.resolve(longs.length >= 2 ? { type: 'view', data: { weekday: weekdayOf(longs[0].date) }, view: `pattern: ${weekdayOf(longs[0].date)}s, about ${longs[0].minutes} min` } : { type: 'view', data: null, view: 'no long-workout pattern in the history' }); }
      case 'formulaCoverage': return Promise.resolve({ type: 'view', data: [], view: 'coverage: see the file' });
      case 'recallFacts': return Promise.resolve({ type: 'view', data: d.memories, view: d.memories.join(' | ') || 'nothing on file' });
      default: return Promise.resolve({ type: 'error', message: `unknown tool ${call.name}` });
    }
  }
}

export const TINY_PROMPTS: Record<string, string> = {
  shared: '# Shared\nYou are Vana.', read: '# Read\nLast: {{last}}\nStep: {{step}}', scripted: '', sensitive: '# Sensitive\nPlain and warm.',
  'shape-answer': '# Answer', 'shape-choose': '# Choose', 'shape-draft-record': '# Draft', 'shape-hand-off': '# Hand-off', 'shape-set-value': '# Set a value',
  'step-plan': '# plan', 'step-wearable': '# wearable', 'step-formula': '# formula', 'step-long-run': '# long run', 'step-race': '# race',
};
export const tinyPrompts = (): PromptSource => memoryPrompts(TINY_PROMPTS);

export type GenInput = Parameters<Model['generate']>[0];
export type GenOutput = { text: string; toolCalls?: ToolCall[] };
const USAGE: Usage = { inputTokens: 100, outputTokens: 20, cachedTokens: 0 };

/** A model the test scripts: `reads` answers Read in order; `gens` answers each generate in order, or a function of the input. */
export class FakeModel implements Model {
  generated: GenInput[] = [];
  readInputs: { system: string; message: string }[] = [];
  constructor(public reads: (ReadResult | ((m: string) => ReadResult))[] = [], public gens: (GenOutput | ((i: GenInput) => GenOutput))[] = []) {}
  read(input: { system: string; message: string }): Promise<{ object: ReadResult; usage: Usage }> {
    this.readInputs.push(input);
    const next = this.reads.shift() ?? { intents: [{ label: 'chat' as const }], facts: [] };
    return Promise.resolve({ object: typeof next === 'function' ? next(input.message) : next, usage: USAGE });
  }
  generate(input: GenInput): Promise<{ text: string; toolCalls: ToolCall[]; usage: Usage }> {
    this.generated.push(input);
    const next = this.gens.shift();
    const out = next ? (typeof next === 'function' ? next(input) : next) : this.defaultFor(input);
    return Promise.resolve({ text: out.text, toolCalls: out.toolCalls ?? [], usage: USAGE });
  }
  /** Obeys a forced tool, draws the step's card when it has one, lands with words otherwise. The words name every
   *  card subject so the lead-in check passes whatever step the fake lands on. */
  private defaultFor(i: GenInput): GenOutput {
    // a fresh sentence per call (same_words_twice would otherwise catch the fake repeating itself)
    const nth = ['first', 'second', 'third', 'fourth', 'fifth', 'sixth', 'seventh', 'eighth', 'ninth', 'tenth'][(this.generated.length - 1) % 10];
    const words = `A ${nth} word on ${i.step}: here is the card for your training plan, watch, formula, long workout, race or week.`;
    if (typeof i.toolChoice === 'object') return { text: words, toolCalls: [{ name: i.toolChoice.name, input: {} }] };
    const card = i.toolChoice !== 'none' ? i.tools.find((t) => t.kind === 'card') : undefined;
    if (card) return { text: words, toolCalls: [{ name: card.name, input: {} }] };
    return { text: 'Okay.' };
  }
}

export const lastUser = (i: GenInput): string => [...i.messages].reverse().find((m: ChatMessage) => m.role === 'user')?.content ?? '';

export function fakeAdapters(d: Snapshot, model = new FakeModel(), prompts: PromptSource = tinyPrompts()): Adapters & { data: FakeData; tools: FakeTools; memory: FakeMemory; rows: FakeRows; model: FakeModel } {
  const data = new FakeData(d);
  const memory = new FakeMemory(data);
  return { data, tools: new FakeTools(data, memory), memory, prompts, clock: fakeClock(d.today), rows: new FakeRows(), model };
}
