/**
 * The interfaces the callers implement (proposal v7 §4 "where it runs"). The engine sees the world only through these:
 * the ops harness passes fakes, the `vana-chat` edge function passes Supabase-backed ones, tests pass the fakes in
 * fakes.ts. No Supabase client, no model SDK and no file read lives inside engine/ except behind one of these.
 */
import type { ConversationState, ReadResult, Snapshot, StepMemory, ToolCall, ToolOutcome, ToolSpec } from './types.ts';

/** One read of the athlete's rows. Called by Assemble when the block is missing, dirty or from another day. */
export interface DataReader { read(userId: string): Promise<Snapshot> }

/** Runs one tool by name. The step's tool list says what the model may call; this says what it does. */
export interface ToolRunner {
  specs(names: string[]): ToolSpec[];
  run(call: ToolCall, ctx: { userId: string; conversationId: string; step: string; words: string }): Promise<ToolOutcome>;
}

/** Lee's memory.ts behind it (box 8); an in-memory one for the harness; the real one waits for the user_memories migration. */
export interface MemoryStore {
  remember(userId: string, fact: string, opts?: { kind?: 'preference' | 'constraint' | 'pattern' | 'setting'; key?: string; value?: unknown; source?: string }): Promise<void>;
  /** Flow facts are keyed settings, one row per key: how orientation survives a week's pause. */
  setStep(userId: string, step: string, status: StepMemory): Promise<void>;
}

/** Prompts by stem (`shared`, `read`, `shape-choose`, `step-plan`, `scripted`, …). Files now; Langfuse plugs in here. */
export interface PromptSource { get(stem: string): Promise<string> }

export interface Clock { today(): string; now(): Date }

/** The conversation row. The engine reads it at the top of a turn and hands the new state back on TurnResult. */
export interface RowStore {
  load(conversationId: string): Promise<ConversationState | null>;
  save(state: ConversationState): Promise<void>;
}

export interface ChatMessage { role: 'system' | 'user' | 'assistant' | 'tool'; content: string; cache?: boolean }
export interface Usage { inputTokens: number; outputTokens: number; cachedTokens: number }

/** One model call per pass. The engine owns the pass loop (box 5); the adapter owns the SDK. */
export interface Model {
  read(input: { system: string; message: string }): Promise<{ object: ReadResult; usage: Usage }>;
  generate(input: { messages: ChatMessage[]; tools: ToolSpec[]; toolChoice: 'auto' | 'none' | { name: string }; role: 'step' | 'guard'; step: string }): Promise<{ text: string; toolCalls: ToolCall[]; usage: Usage }>;
}

/** Gate hooks (box 1). No-op adapters are fine for the harness. */
export interface Entitlement { allowed(userId: string): Promise<{ ok: true } | { ok: false; reason: string }> }
export interface RateLimit { take(userId: string): Promise<{ ok: true } | { ok: false; reason: string }> }

export interface Adapters {
  data: DataReader;
  tools: ToolRunner;
  memory: MemoryStore;
  prompts: PromptSource;
  clock: Clock;
  rows: RowStore;
  model: Model;
  entitlement?: Entitlement;
  rateLimit?: RateLimit;
}

export const NOOP_ENTITLEMENT: Entitlement = { allowed: () => Promise.resolve({ ok: true }) };
export const NOOP_RATE_LIMIT: RateLimit = { take: () => Promise.resolve({ ok: true }) };
