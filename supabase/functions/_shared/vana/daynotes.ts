/** Per-day "message from Vana" for the Plan tab — precomputed, never generated on read.
 *
 *  One Haiku call writes all seven days from the athlete context + the plan; the result lives on
 *  meal_plans.day_notes ({date → text}). It is (re)generated when a plan is confirmed and, lazily, the first time the
 *  Plan tab loads after an edit (every plan mutation flips day_notes_stale via refreshShopping). The numbers in the
 *  notes come from the context (daily_macro_targets + activities), not the model.
 *
 *  Edge-function shape: the eager/background regenerations are not in-process promises (an isolate may be torn down
 *  after the response) — they are a `vana-day-notes` invocation handed to EdgeRuntime.waitUntil with the caller's JWT. */
import { generateObject } from 'npm:ai@6';
import { z } from 'npm:zod@3';
import { TOOL_MODEL, SUPABASE_URL, addDays, waitUntil } from './env.ts';
import type { VanaCtx } from './env.ts';
import { buildAthleteContext, contextBlock } from './context.ts';
import { getPlan } from './plan.ts';
import { logCall } from './log.ts';
import { checkRateLimit } from './rate-limit.ts';
import type { MealPlan } from './contracts.ts';

const NotesZ = z.object({ notes: z.array(z.object({ date: z.string(), text: z.string() })).min(1).max(8) });
const inflight = new Map<string, Promise<Record<string, string>>>();

export async function generateDayNotes(v: VanaCtx, plan: MealPlan, anchorDate: string): Promise<Record<string, string>> {
  const key = `${v.userId}:${plan.id}`;
  const running = inflight.get(key); if (running) return running;
  const job = (async () => {
    // Over the bucket → keep whatever notes exist (the Plan tab shows the last good ones); never queue a burst of Haiku calls.
    const rl = await checkRateLimit(v.admin, v.userId, 'vana.daynotes');
    if (!rl.allowed) { console.warn(`[vana] day notes rate-limited for ${v.userId}`); return plan.dayNotes; }
    const ctx = await buildAthleteContext(v, undefined, anchorDate);
    const days = Array.from({ length: 7 }, (_, i) => addDays(anchorDate, i));
    const meals = plan.meals.map((m) => `- ${m.name} (${m.mealType}, ×${m.servings}, ${m.servingsLeft} left${m.session ? `, ${m.session}` : ''})`).join('\n') || '- (no meals in the plan yet)';
    const started = Date.now();
    const { object, usage } = await generateObject({
      model: TOOL_MODEL, schema: NotesZ, maxOutputTokens: 900,
      system: `You are Vana, an endurance-nutrition assistant. Write ONE short message (max 2 sentences, ≤ 30 words) for EACH of the dates listed, telling the athlete how to use their meal plan that day given their training. Be concrete: name a plan meal when it fits (e.g. "long ride → the rice bowl at lunch, extra serving at dinner"), mention the carb target only if it matters that day, keep rest days light. Minimums framing, never weight or calorie-restriction language, no greetings, no emoji. Only use numbers that appear in the context.`,
      prompt: `--- CONTEXT ---\n${contextBlock(ctx)}\n--- PLAN (${plan.status}, batch cooking ${plan.batchCooking ? 'on' : 'off'}) ---\n${meals}\n--- DATES ---\n${days.join(', ')}\nReturn one note per date, in order.`,
    });
    const notes: Record<string, string> = {};
    for (const n of object.notes) if (days.includes(n.date) && n.text.trim()) notes[n.date] = n.text.trim();
    await v.db.from('meal_plans').update({ day_notes: { ...plan.dayNotes, ...notes }, day_notes_stale: false, day_notes_at: new Date().toISOString() }).eq('id', plan.id);
    await logCall(v.admin, { userId: v.userId, functionName: 'vana.daynotes', model: TOOL_MODEL, inputTokens: usage?.inputTokens, outputTokens: usage?.outputTokens });
    console.log(`[vana] day notes for ${plan.id} in ${Date.now() - started}ms`);
    return { ...plan.dayNotes, ...notes };
  })().finally(() => inflight.delete(key));
  inflight.set(key, job);
  return job;
}

/** Notes for the plan. Fresh → stored. Stale but a note exists for the day → return it now, regenerate in the background
 *  (`stale: true` tells the client to refetch shortly). No note at all → wait for one. Never throws. */
export async function ensureDayNotes(v: VanaCtx, plan: MealPlan | null, anchorDate: string): Promise<{ notes: Record<string, string>; stale: boolean }> {
  if (!plan) return { notes: {}, stale: false };
  const have = !!plan.dayNotes[anchorDate];
  if (!plan.dayNotesStale && have) return { notes: plan.dayNotes, stale: false };
  if (have) { refreshDayNotesSoon(v, anchorDate, plan.id); return { notes: plan.dayNotes, stale: true }; }
  try { return { notes: await generateDayNotes(v, plan, anchorDate), stale: false }; } catch (e) { console.error('[vana] day notes failed:', (e as Error).message); return { notes: plan.dayNotes, stale: false }; }
}
/** After Confirm / an edit: regenerate eagerly without holding the response — one `vana-day-notes` call under waitUntil. */
export function refreshDayNotesSoon(v: VanaCtx, anchorDate: string, planId?: string | null) {
  const run = (async () => {
    const id = planId ?? (await getPlan(v))?.id; if (!id) return;
    const res = await fetch(`${SUPABASE_URL}/functions/v1/vana-day-notes`, { method: 'POST', signal: AbortSignal.timeout(60_000), headers: { Authorization: `Bearer ${v.token}`, 'content-type': 'application/json' }, body: JSON.stringify({ plan_id: id, anchor_date: anchorDate }) });
    if (!res.ok) console.error(`[vana] vana-day-notes ${res.status}: ${(await res.text()).slice(0, 200)}`);
  })().catch((e) => console.error('[vana] day notes refresh failed:', (e as Error).message));
  waitUntil(run);
}
