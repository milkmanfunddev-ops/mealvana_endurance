/** Ingredients on hand (plan Phase 7): a suggested pantry seeded from what the athlete actually logs, saves and buys — never a
 *  generic list — and fridge-photo detection through the same vision path the meal-logging photo surface uses.
 *  Photo detection is an AI surface: metered in ai_usage, never disabled to save cost (standing AI-surfaces rule). */
import { generateObject } from 'npm:ai@6.0.277';
import { z } from 'npm:zod@3';
import type { VanaCtx } from './env.ts';
import { TOOL_MODEL } from './env.ts';
import type { VanaPart } from './contracts.ts';
import { getPlan } from './plan.ts';
import { gatewayCostUsd, logAiUsage } from '../ai/usage.ts';
import { cacheReadTokens, cacheWriteTokens } from './stream.ts';
import { defaultTracing } from '../langfuse/tracing.ts';
import { callPrompt, instancePrompts, type CallPrompt } from '../langfuse/prompts.ts';

export type PantryPart = Extract<VanaPart, { kind: 'pantry' }>;
const norm = (s: string) => s.toLowerCase().replace(/[^a-z0-9 ]/g, ' ').replace(/\s+/g, ' ').trim();

/** Likely on-hand items: logged items (30d, by count), saved-meal components, and last plan's shopping items marked have/checked. */
export async function suggestedPantry(v: VanaCtx, title = "What's in the house?"): Promise<PantryPart> {
  const since = new Date(Date.now() - 30 * 86400_000).toISOString().slice(0, 10);
  const [{ data: logs }, { data: saved }, plan] = await Promise.all([
    v.db.from('meal_logs').select('items').eq('user_id', v.userId).eq('is_deleted', false).gte('log_date', since).limit(200),
    v.db.from('saved_meals').select('items').eq('user_id', v.userId).eq('is_deleted', false).limit(30),
    getPlan(v),
  ]);
  const counts = new Map<string, { name: string; n: number }>();
  const bump = (raw: string | undefined, n = 1) => { const name = String(raw ?? '').trim(); const k = norm(name); if (!k || k.length < 3) return; const c = counts.get(k); counts.set(k, { name: c?.name ?? name, n: (c?.n ?? 0) + n }); };
  for (const r of logs ?? []) for (const i of (r.items ?? []) as { name?: string; food_name?: string }[]) bump(i.name ?? i.food_name);
  for (const r of saved ?? []) for (const i of (r.items ?? []) as { name?: string; food_name?: string }[]) bump(i.name ?? i.food_name, 0.5);
  for (const s of plan?.shopping ?? []) if (s.have || s.checked) bump(s.name, 2);
  const items = [...counts.values()].sort((a, b) => b.n - a.n).slice(0, 8).map((c) => ({ name: c.name, selected: c.n >= 2 }));
  return { kind: 'pantry', title, items, allowCustom: true, origin: 'suggested' };
}

const PantryVisionZ = z.object({ isFoodStorage: z.boolean().describe('true when the photo shows a fridge, pantry, shelf or counter with food'), items: z.array(z.string().max(40)).max(30).describe('plain ingredient names, singular, no brands, no quantities') });

/** What the vision call is told, after the photo. */
export const PANTRY_PHOTO_INSTRUCTIONS = 'List the food ingredients visible in this fridge/pantry photo as plain names (e.g. "eggs", "spinach", "greek yogurt"). Skip condiments you cannot identify, packaging text and non-food. If it is not a food-storage photo, set isFoodStorage=false and return no items.';
/** The prompt by its name in Langfuse (langfuse ticket 12). The text above is the bundled copy: what runs when
 *  Langfuse cannot be reached, and what the prompt was created from. Its config names the model; `VANA_TOOL_MODEL` is
 *  what runs when it names none. */
export const PANTRY_PHOTO_PROMPT = 'vana/background/pantry-photo';
export const PANTRY_PROMPT_TEMPLATES = { [PANTRY_PHOTO_PROMPT]: PANTRY_PHOTO_INSTRUCTIONS } as const;
const prompts = instancePrompts(PANTRY_PROMPT_TEMPLATES);
/** The pantry photo's instructions and model. Resolved by the caller, which names the model on the Call log row it
 *  reserves before the model runs. */
export const pantryPhotoWording = (): Promise<CallPrompt> => callPrompt(prompts, PANTRY_PHOTO_PROMPT, TOOL_MODEL);

/** What the vision call cost, in the shape the call log and the budget read (ticket 05, ticket 09). */
export interface PantryUsage { inputTokens: number; outputTokens: number; cacheReadTokens: number | null; cacheWriteTokens: number | null; gatewayCostUsd: number | null; model: string }
/** Fridge / pantry photo → ingredient names. `photoPath` is a `meal-photos` object the caller owns ({userId}/…).
 *  `onUsage` reports what the vision call cost, so the caller can finish the `vana_calls` row that reserved its
 *  place in the limiter (mp-469) and settle the budget reservation to the real cost (mp-436). `conversationId` is the
 *  Conversation the photo was taken in: the Session its Trace carries (langfuse ticket 10). */
export async function detectPantryFromPhoto(v: VanaCtx, photoPath: string, opts: { onUsage?: (t: PantryUsage) => Promise<void>; conversationId?: string | null; wording?: CallPrompt } = {}): Promise<PantryPart> {
  if (!photoPath.startsWith(`${v.userId}/`)) throw new Error('photo does not belong to this user');
  const { data: blob, error } = await v.admin.storage.from('meal-photos').download(photoPath);
  if (error || !blob) throw new Error(`could not read photo: ${error?.message ?? 'unknown'}`);
  const bytes = new Uint8Array(await blob.arrayBuffer()); let bin = ''; for (let i = 0; i < bytes.length; i += 8192) bin += String.fromCharCode(...bytes.subarray(i, i + 8192));
  const ext = photoPath.split('.').pop()?.toLowerCase(); const mediaType = ext === 'png' ? 'image/png' : ext === 'webp' ? 'image/webp' : 'image/jpeg';
  const wording = opts.wording ?? await pantryPhotoWording(); const model = wording.model;
  // The call is a Trace of its own. The photo goes as image data, which Langfuse stores; no signed URL is sent.
  const tracing = defaultTracing(); const image = btoa(bin);
  const r = await tracing.call({ name: 'vana-pantry-photo', userId: v.userId, sessionId: opts.conversationId, environment: v.environment, tags: ['pantry-photo'], metadata: { promptSource: wording.origin }, prompt: wording.prompt, input: { photo: `data:${mediaType};base64,${image}` } }, () => generateObject({
    model: model as Parameters<typeof generateObject>[0]['model'], experimental_telemetry: tracing.telemetry('vana-pantry-photo'), schema: PantryVisionZ, maxOutputTokens: 400,
    messages: [{ role: 'user', content: [{ type: 'image', image, mediaType }, { type: 'text', text: wording.text }] }],
  }), (out) => out.object);
  const u = r.usage; const costUsd = gatewayCostUsd(r.providerMetadata);
  await logAiUsage(v.admin, { userId: v.userId, functionName: 'vana-pantry-photo', model, inputTokens: u?.inputTokens ?? 0, outputTokens: u?.outputTokens ?? 0, costUsd });
  await opts.onUsage?.({ inputTokens: u?.inputTokens ?? 0, outputTokens: u?.outputTokens ?? 0, cacheReadTokens: cacheReadTokens(u), cacheWriteTokens: cacheWriteTokens(u), gatewayCostUsd: costUsd, model });
  const seen = new Set<string>(); const items = r.object.isFoodStorage ? r.object.items.map((x) => x.trim()).filter((x) => { const k = norm(x); if (!k || seen.has(k)) return false; seen.add(k); return true; }).map((name) => ({ name, selected: true })) : [];
  return { kind: 'pantry', title: items.length ? 'Here is what I could see' : 'I could not spot food in that photo — add what you have', items, allowCustom: true, origin: 'photo' };
}

/** Persist a part as an assistant turn so the transcript keeps it (same row shape chat.ts writes). Returns the message id. */
export async function persistAssistantPart(v: VanaCtx, conversationId: string, part: VanaPart, content: string): Promise<string> {
  const toolCallId = `action-${Date.now()}`;
  const { data, error } = await v.db.from('vana_messages').insert({ conversation_id: conversationId, user_id: v.userId, role: 'assistant', content, parts: [{ type: 'text', text: content }, { type: 'tool-pantryPhoto', toolCallId, state: 'output-available', input: {}, output: part }], metadata: { ui_parts: [part], tool_calls: ['pantryPhoto'], kind: 'meal_planning', opener: false } }).select('id').single();
  if (error) throw new Error(error.message);
  await v.db.from('vana_conversations').update({ last_message_at: new Date().toISOString(), updated_at: new Date().toISOString() }).eq('id', conversationId);
  return data.id as string;
}
