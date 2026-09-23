/** Chips with one fixed meaning act at once, with no model turn (mp-464 clauses 1, 3, 4, 5 and 7; ai-cost ticket 11).
 *
 *  "Draft my whole week", "Same as last time", the batch-cooking and coverage answers, "Open shopping list", "Lay it
 *  across the week", "Use what I have" and the pantry card's "Use these" used to go to Vana as a message, and she
 *  called a deterministic tool and wrote a line about it: a full planning turn (about 21,000 tokens on the 09-20 audit)
 *  for a step whose outcome was already fixed. Now the app runs the step on `vana-action` with the chip's label on the
 *  payload, and this module does the three things the decision asks of the server:
 *
 *    - the tap and what it produced are STORED in the conversation (clause 4): a user row holding the label, and an
 *      assistant row with no text whose parts are the result, typed as the tool the chip stands in for — so the next
 *      turn replays it exactly as if Vana had called the tool, in the tool's compact form (mp-471), and the prefix
 *      before it stays the bytes it was (ticket 07);
 *    - Vana writes NO line (clause 3): the assistant row has no text part, and the app draws nothing in her voice;
 *    - the tap is LOGGED as a tap that drew nothing (clauses 5 and 7): one `vana_calls` row with no model and zero
 *      cost, `input_mode` 'tap', not debited, so the saving is measured against the chip taps that still cost a turn.
 *
 *  The labels Vana must use for the chips she names herself are in chip-labels.ts; the app's copy is
 *  `lib/features/meal_planning/domain/vana_fixed_chip.dart`. */
import type { ConversationKind, MealType, VanaPart } from './contracts.ts';
import type { VanaCtx } from './env.ts';
import { conversationKind } from './chat.ts';
import { snapshotPlan } from './plan.ts';
import { logCall } from './log.ts';
import { subscriberState } from './subscriber.ts';

/** The `model` of a tap's call row: no model ran. A string rather than null so the row reads the same way everywhere
 *  the log is cut by model. */
export const NO_MODEL = 'none';

/** The tool each at-once action stands in for. A stored tap replays as that tool's call, so the next turn reads it in
 *  the tool's compact form and Vana sees what she would have seen had she called it. `set_pantry` and
 *  `open_shopping_list` have no tool: the model reads their JSON as it is (the app did the thing). */
export const TAP_TOOLS: Record<string, string> = {
  draft_week: 'draftWeek',
  same_as_last_time: 'sameAsLastTime',
  set_setting: 'setSetting',
  plan_week: 'planWeek',
  ask_pantry: 'askPantry',
  set_pantry: 'setPantry',
  open_shopping_list: 'openShoppingList',
  next_picker: 'suggestMeals',
};
export const isTapAction = (type: string): boolean => Object.prototype.hasOwnProperty.call(TAP_TOOLS, type);

export interface TapInput {
  conversationId: string;
  /** What the athlete tapped, as the app drew it. The athlete's turn in the transcript. */
  label: string;
  /** The action that ran. */
  type: string;
  /** The tool's own input shape (`{ key, value }` for a setting, `{ items }` for the pantry): never the wire payload. */
  input: Record<string, unknown>;
  /** What the action produced, as the app got it. Empty when the app did the thing itself. */
  parts: VanaPart[];
}
export interface TapIds { tapMessageId: string; messageId: string }

/** Store the tap and what it produced, and log it. Throws when a row cannot be written: the action already ran, and a
 *  tap the conversation does not hold would surface as Vana forgetting it, which the app must not report as done. */
export async function recordTap(v: VanaCtx, t: TapInput): Promise<TapIds> {
  const tool = TAP_TOOLS[t.type] ?? t.type;
  const kind: ConversationKind = await conversationKind(v, t.conversationId);
  const { data: user, error: userError } = await v.db.from('vana_messages')
    .insert({ conversation_id: t.conversationId, user_id: v.userId, role: 'user', content: t.label, parts: [{ type: 'text', text: t.label }], metadata: { input_mode: 'tap', tap: t.type } })
    .select('id').single();
  if (userError) throw new Error(userError.message);
  // A tap with no part still tells the next turn what happened: the output names the action, and the app skips a kind
  // it does not draw.
  const outputs: unknown[] = t.parts.length ? t.parts : [{ kind: 'done', action: t.type }];
  const stamp = Date.now();
  const parts = outputs.map((output, i) => ({ type: `tool-${tool}`, toolCallId: `tap-${stamp}-${i}`, state: 'output-available', input: t.input, output }));
  // The draft after this tap, so an edit-rewind can restore it (plan Phase 6.1) — the same key a chat turn stores.
  const planSnapshot = kind === 'meal_planning' ? await snapshotPlan(v, { conversationId: t.conversationId }) : null;
  const { data: assistant, error: assistantError } = await v.db.from('vana_messages')
    .insert({ conversation_id: t.conversationId, user_id: v.userId, role: 'assistant', content: '', parts, metadata: { tool_calls: [tool], tap: t.type, kind, opener: false, duration_ms: 0, plan_snapshot: planSnapshot ?? undefined } })
    .select('id').single();
  if (assistantError) throw new Error(assistantError.message);
  const now = new Date().toISOString();
  await v.db.from('vana_conversations').update({ last_message_at: now, updated_at: now }).eq('id', t.conversationId);
  // One row, the shape of a chat row so the weekly view cuts it the same way: no model, nothing spent, a tap.
  const sub = await subscriberState(v.admin, v.userId);
  await logCall(v.admin, { userId: v.userId, conversationId: t.conversationId, functionName: `vana.tap.${t.type}.${kind}`, model: NO_MODEL, inputTokens: 0, outputTokens: 0, cacheReadTokens: null, cacheWriteTokens: null, steps: 0, gatewayCostUsd: 0, debited: false, inputMode: 'tap', subscriberPeriodType: sub.periodType, subscriberActiveUntil: sub.activeUntil });
  return { tapMessageId: String(user.id), messageId: String(assistant.id) };
}

/** What `vana-action` does after an action ran: with a `chip` on the payload of an at-once action and a conversation
 *  to store into, the turn is stored and logged and the row ids ride back on the result (`tapMessageId`, `messageId`).
 *  Anything else — no chip, no conversation, an action that is not a chip — passes the result through untouched, and so
 *  does an action that handed the tap back to Vana (`toVana`, ticket 12): nothing ran, so there is nothing to store.
 *  An action whose tool input is not its wire payload names it as `toolInput` (the picker's resolved arguments). */
// deno-lint-ignore no-explicit-any
export async function runTapped<R extends { parts: VanaPart[]; toVana?: unknown; toolInput?: unknown }>(v: VanaCtx, type: string, payload: Record<string, any>, result: R): Promise<R & Partial<TapIds>> {
  // `toolInput` is for the stored call only; the app never sees it.
  const { toolInput, ...others } = result;
  const rest = others as R;
  const chip = typeof payload.chip === 'string' ? payload.chip.trim() : '';
  const conversationId = payload.conversationId ?? payload.conversation_id;
  if (!chip || !conversationId || !isTapAction(type) || rest.toVana) return rest;
  const { chip: _chip, conversationId: _a, conversation_id: _b, planId: _c, plan_id: _d, ...wire } = payload;
  const input = toolInput && typeof toolInput === 'object' ? (toolInput as Record<string, unknown>) : wire;
  const ids = await recordTap(v, { conversationId: String(conversationId), label: chip, type, input, parts: result.parts });
  return { ...rest, ...ids };
}

// ---------------------------------------------------------------- the picker's own chips (mp-464, ai-cost ticket 12)

/** The picker chips that fetch another picker with no model turn, as the app names them on `next_picker`'s `chip_kind`.
 *  `more` is "Other options"; `no_recipe` and `under_20` are the two filters; `next` is "I like these" / "Next: <type>".
 *  "Different protein" is not here: which protein is a choice only Vana can make, so it stays hers. */
export type PickerChipKind = 'more' | 'no_recipe' | 'under_20' | 'next';
export const isPickerChipKind = (x: unknown): x is PickerChipKind => x === 'more' || x === 'no_recipe' || x === 'under_20' || x === 'next';

/** The fixed picker arguments each "same type again" chip lays over the last picker's own. The ONE table: "No recipe
 *  only" is what Vana passed for it (kind assembly), "Under 20 min" likewise (maxPrepMinutes 20), and "Other options"
 *  changes nothing — the same search again, which never repeats a meal already shown. */
export const PICKER_CHIP_ARGS: Record<Exclude<PickerChipKind, 'next'>, { kind?: 'assembly'; maxPrepMinutes?: number }> = {
  more: {},
  no_recipe: { kind: 'assembly' },
  under_20: { maxPrepMinutes: 20 },
};

/** What follows "I like these" / "Next: <type>" (persona rule 4): the next meal type's picker, a question, or the wrap-up.
 *  Only the first is fixed; the other two are Vana's to say. */
export type PickerNextStep = { step: 'picker'; mealType: MealType } | { step: 'ask' } | { step: 'wrap_up' } | { step: 'mismatch' };
export interface PickerNextInput {
  /** The meal type of the picker the chip sits under. */
  lastType: MealType;
  /** The athlete's walk (walkFor): the types they plan, in their order. */
  walk: readonly MealType[];
  /** The meal types the conversation's draft already holds. */
  covered: ReadonlySet<MealType>;
  /** Whether batch cooking was ever chosen, and the coverage scope (null = never chosen): the rule-4 forks. */
  batchKnown: boolean;
  coverageScope: string | null;
  /** The type the chip named ("Next: Lunch"), when it named one. */
  named?: MealType | null;
}

/** The step after "I like these" / "Next", decided the way the persona's rule 4 decides it. A fork still never chosen
 *  means Vana asks it; no type left on the walk means she wraps up; otherwise the next uncovered type on the walk after
 *  the picker's own (wrapping round to one skipped earlier). A chip that named a type gets that type when it is open, and
 *  otherwise goes to Vana (`mismatch`). */
export function pickerNextStep(i: PickerNextInput): PickerNextStep {
  if (!i.batchKnown || i.coverageScope == null) return { step: 'ask' };
  const open = i.walk.filter((t) => t !== i.lastType && !i.covered.has(t));
  if (!open.length) return { step: 'wrap_up' };
  // A chip that named a type is followed or handed to Vana, never answered with a different type's picker (mp-464).
  if (i.named) return open.includes(i.named) ? { step: 'picker', mealType: i.named } : { step: 'mismatch' };
  const at = i.walk.indexOf(i.lastType);
  const after = at < 0 ? [] : open.filter((t) => i.walk.indexOf(t) > at);
  return { step: 'picker', mealType: (after[0] ?? open[0]) };
}
