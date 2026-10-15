/**
 * Scripted lines (box 4 / box 7): the words code writes, code writes. Templates live in v7/prompts/scripted.md; this
 * module loads that file through the PromptSource (Langfuse later) and falls back to the same text when a key is
 * missing, so a harness without the file still speaks. Names in {braces} are filled by code.
 */
import type { PromptSource } from './adapters.ts';

export interface ScriptedLines {
  off_flow: string;          // "That's coming soon. I can't help with it yet." + " {steer}"
  feedback_ack: string;      // Lee's content-managed row (feedback_saved_row); a default until the row is wired
  wrap: string;
  receipt: string;           // "{what}, {when}."
  receipt_race: string;      // appended to a race receipt
  sensitive_medical: string;
  sensitive_ed_close: string;
  /** Check fell through twice: the one line the athlete sees instead (not in scripted.md; drafted here, Xuan edits). */
  safe: string;
}

export const DEFAULT_LINES: ScriptedLines = {
  off_flow: "That's coming soon. I can't help with it yet.",
  feedback_ack: 'Noted, and thank you. The team reads every one of these.',
  wrap: "That's your setup. There's more to explore in your formula library; tap through whenever.",
  receipt: '{what}, {when}.',
  receipt_race: 'It lives on your Events page.',
  sensitive_medical: 'Would you like us to help you find a sports dietitian?',
  sensitive_ed_close: 'We can pick setup up another time.',
  safe: "Let me put that another way once I've checked your file. The card below is still yours to tap.",
};

/** First quoted string after a `key (` heading in scripted.md, else null. Tolerant: the file is prose for Xuan to read. */
function quoted(md: string, key: string): string | null {
  const m = md.match(new RegExp(`^${key}\\b[^\\n]*\\n([\\s\\S]*?)(?=^\\w[\\w ,]*\\(|$(?![\\s\\S]))`, 'm'));
  if (!m) return null;
  const q = m[1].match(/"([^"]+)"/);
  return q ? q[1] : null;
}

export async function loadScripted(prompts: PromptSource): Promise<ScriptedLines> {
  let md = '';
  try { md = await prompts.get('scripted'); } catch { return { ...DEFAULT_LINES }; }
  const pick = (key: string, fallback: string) => quoted(md, key) ?? fallback;
  const sens = md.match(/medical:\s*"([^"]+)"/)?.[1] ?? DEFAULT_LINES.sensitive_medical;
  const edClose = md.match(/eating disorder, closing:\s*"([^"]+)"/)?.[1] ?? DEFAULT_LINES.sensitive_ed_close;
  const raceLine = md.match(/a race receipt adds\s*"([^"]+)"/)?.[1] ?? DEFAULT_LINES.receipt_race;
  return {
    off_flow: pick('off_flow', DEFAULT_LINES.off_flow),
    feedback_ack: DEFAULT_LINES.feedback_ack,
    wrap: pick('wrap', DEFAULT_LINES.wrap),
    receipt: (quoted(md, 'receipt') ?? DEFAULT_LINES.receipt).replace('{what was saved}', '{what}').replace('{when / how long}', '{when}'),
    receipt_race: raceLine,
    sensitive_medical: sens,
    sensitive_ed_close: edClose,
    safe: DEFAULT_LINES.safe,
  };
}

export const fill = (template: string, vars: Record<string, string>): string =>
  template.replace(/\{(\w+)\}/g, (_, k: string) => vars[k] ?? '').replace(/\s+,/g, ',').replace(/,\s*\./g, '.').replace(/\s{2,}/g, ' ').trim();

/** The off-flow line: the coming-soon sentence, plus the steer unless offers ended this visit. */
export const offFlowLine = (lines: ScriptedLines, steer: string | null): string => [lines.off_flow, steer].filter(Boolean).join(' ');
/** The feedback acknowledgement, then the steer as above. No question mark after the ack itself. */
export const feedbackLine = (lines: ScriptedLines, steer: string | null): string => [lines.feedback_ack, steer].filter(Boolean).join(' ');
/** "{what}, {when}." A race adds where it lives. */
export const receiptLine = (lines: ScriptedLines, what: string, when: string | null, race = false): string =>
  [fill(lines.receipt, { what, when: when ?? '' }), race ? lines.receipt_race : ''].filter(Boolean).join(' ');
