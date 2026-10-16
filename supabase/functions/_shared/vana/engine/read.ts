/**
 * Box 3 · Read (one small model call): what kind of message this is, seeing almost nothing (proposal v7 §4.3).
 *
 * Input: prompts/read.md with {{last}} (Vana's last line) and {{step}} filled, and the athlete's message. No block, no
 * history. Output: every intent in order, each a label with a target where the label asks for one, plus durable facts.
 * Taps, receipts and the opener never reach Read. The schema is validated here so a loose model answer cannot route.
 */
import type { Model, PromptSource } from './adapters.ts';
import type { Intent, IntentLabel, Line, ReadResult } from './types.ts';
import type { Usage } from './adapters.ts';

export const LABELS: readonly IntentLabel[] = ['answers', 'declines', 'asks', 'leaves_flow', 'feedback', 'chat', 'safety'];
/** `visit`: the athlete would rather finish setup another time (the yes to the scripted check-in; read.md, ruled 2026-10-15). */
export const DECLINE_TARGETS = ['step', 'all_connections', 'visit'] as const;
export const SAFETY_TARGETS = ['eating_disorder', 'distress', 'medical', 'injury', 'vague_symptom', 'soft_restriction'] as const;
/** The safety targets that end the flow for the conversation (Q6). A medical, injury or symptom hit hands the next turn back. */
export const FLOW_ENDING_SAFETY: ReadonlySet<string> = new Set(['eating_disorder', 'distress']);

/** Coerce whatever the model returned into a ReadResult; anything unlabelled is dropped, an empty result reads as chat. */
export function coerceRead(raw: unknown): ReadResult {
  const o = (raw && typeof raw === 'object' ? raw : {}) as { intents?: unknown; facts?: unknown };
  const intents: Intent[] = (Array.isArray(o.intents) ? o.intents : [])
    .map((i) => (i && typeof i === 'object' ? i : {}) as { label?: unknown; target?: unknown })
    .filter((i): i is { label: IntentLabel; target?: unknown } => typeof i.label === 'string' && (LABELS as readonly string[]).includes(i.label))
    .map((i) => ({ label: i.label, ...(typeof i.target === 'string' && i.target.trim() ? { target: i.target.trim().toLowerCase().replace(/\s+/g, '_') } : {}) }));
  const facts = (Array.isArray(o.facts) ? o.facts : []).filter((f): f is string => typeof f === 'string' && f.trim().length > 0).map((f) => f.trim().slice(0, 200));
  return { intents: intents.length ? intents : [{ label: 'chat' }], facts };
}

export function readSystem(template: string, last: string | null, step: string | null): string {
  return template.replace(/^# .*\n+/, '').replace('{{last}}', (last ?? '(nothing yet)').slice(0, 300)).replace('{{step}}', step ?? 'none');
}

export const lastVanaLine = (history: Line[]): string | null => [...history].reverse().find((l) => l.role === 'vana')?.text ?? null;

export async function read(message: string, history: Line[], step: string | null, prompts: PromptSource, model: Model): Promise<{ result: ReadResult; usage: Usage }> {
  const system = readSystem(await prompts.get('read'), lastVanaLine(history), step);
  const { object, usage } = await model.read({ system, message });
  return { result: coerceRead(object), usage };
}
