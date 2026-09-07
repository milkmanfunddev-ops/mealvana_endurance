/** UiActions — structured edits that never need the model. POST vana-action { type, payload }.
 *  Payload keys are accepted in camelCase (the contract) and snake_case (what an older client might send). */
import type { UiAction, VanaPart, DaySlot, DayPlan, ShoppingItem } from './contracts.ts';
import type { VanaCtx } from './env.ts';
import { today } from './env.ts';
import * as plan from './plan.ts';
import { setSetting, forgetMemory, listMemories, isCoverageScope, type CoverageScope } from './memory.ts';
import { detectPantryFromPhoto, persistAssistantPart } from './pantry.ts';
import { diagnoseStaples, dayGuidance, planDayPart } from './tools.ts';
import { buildAthleteContext } from './context.ts';
import { getMeal, saveLibraryMeal, getMealDetail, recentMeals, setSavedMealNotes, setMealFeedback } from './meals.ts';
import { ensureDayNotes, refreshDayNotesSoon } from './daynotes.ts';

const shop = (items: ShoppingItem[]): VanaPart => ({ kind: 'shopping_list', items, itemCount: items.filter((x) => !x.have).length, skipped: items.filter((x) => x.have).map((x) => x.name) });

export type ActionResult = { parts: VanaPart[] } & Record<string, unknown>;

/** payload.planMealId or payload.plan_meal_id → one accessor for both spellings. */
// deno-lint-ignore no-explicit-any
const pick = (p: Record<string, any>, camel: string, snake: string) => p[camel] ?? p[snake];

export async function runAction(v: VanaCtx, a: UiAction): Promise<ActionResult> {
  // deno-lint-ignore no-explicit-any
  const p = (a.payload ?? {}) as Record<string, any>;
  const planMealId = () => String(pick(p, 'planMealId', 'plan_meal_id'));
  // Chat actions carry the conversation (→ its own draft plan); Plan-tab actions carry nothing (→ the week's active plan).
  const planId = pick(p, 'planId', 'plan_id'); const conversationId = pick(p, 'conversationId', 'conversation_id');
  const scope: plan.PlanScope | null = planId ? { planId: String(planId) } : conversationId ? { conversationId: String(conversationId) } : null;
  switch (a.type) {
    case 'pick_meals': { // { meals: [{source,id}], servings?: number, session?: Session, conversationId? }
      let out = null; for (const m of (p.meals ?? []) as { source: 'library' | 'saved'; id: string }[]) out = await plan.addMealById(v, m.source, m.id, Number(p.servings ?? 4), p.session, scope);
      return { parts: [{ kind: 'batch', plan: out ?? (await plan.resolvePlan(v, scope, true))! }] };
    }
    case 'unpick_meal': return { parts: [{ kind: 'batch', plan: await plan.removeMealByRef(v, p.source, String(p.id), scope) }] };
    case 'swap_meal': return { parts: [{ kind: 'batch', plan: await plan.swapMeal(v, planMealId(), p.source, String(p.id)) }] };
    case 'remove_meal': return { parts: [{ kind: 'batch', plan: await plan.setServings(v, planMealId(), 0) }] };
    case 'set_servings': return { parts: [{ kind: 'batch', plan: await plan.setServings(v, planMealId(), Number(p.servings)) }] };
    case 'confirm_plan': { const pl = await plan.confirmPlan(v, scope); refreshDayNotesSoon(v, String(p.date ?? today()), pl.id); return { parts: [{ kind: 'batch', plan: pl }, shop(pl.shopping)] }; }
    case 'toggle_shopping': { const items = await plan.toggleShopping(v, String(p.name), p.field === 'have' ? 'have' : 'checked', !!p.value); return { parts: [shop(items)] }; }
    case 'log_from_plan': { const id = planMealId(); const r = await plan.logFromPlan(v, id, pick(p, 'mealType', 'meal_type'), p.date ? String(p.date) : undefined); return { parts: [{ kind: 'logged', planMealId: id, name: r.name, servingsLeft: r.servingsLeft }, { kind: 'batch', plan: (await plan.getPlan(v))! }], logId: r.logId }; }
    case 'set_setting': { if (p.key !== 'batch_cooking' && p.key !== 'show_macros' && p.key !== 'coverage_scope') throw new Error(`unknown setting ${String(p.key)}`); if (p.key === 'coverage_scope' && !isCoverageScope(p.value)) throw new Error('coverage_scope must be dinners | dinners_lunches | all'); const m = await setSetting(v, p.key, p.key === 'coverage_scope' ? (p.value as CoverageScope) : !!p.value, 'settings'); if (p.key === 'batch_cooking') { const pl = await plan.setBatchCooking(v, !!p.value, scope); return { parts: [{ kind: 'memory_saved', memory: m }, { kind: 'batch', plan: pl }] }; } return { parts: [{ kind: 'memory_saved', memory: m }] }; }
    case 'delete_memory': { await forgetMemory(v, String(p.id)); return { parts: [], memories: await listMemories(v) }; }
    // ---- day planner
    case 'set_day_slot': { // { date?, slot, source: 'plan'|'saved'|'library', id }
      const date = String(p.date ?? today()); const slot = p.slot as DaySlot;
      let name = String(p.name ?? ''); let kcal: number | null = null; let carbsG: number | null = null;
      if (p.source === 'plan') { const pl = await plan.getOrCreatePlan(v); const m = pl.meals.find((x) => x.id === p.id); if (m) { name = m.name; kcal = m.kcal; carbsG = m.carbsG; } }
      else { const m = await getMeal(v, p.source, String(p.id)); if (m) { name = m.name; kcal = m.kcal; carbsG = m.carbsG; } }
      const slots = await plan.setDaySlot(v, date, slot, { source: p.source, id: String(p.id), name, kcal, carbsG });
      return { parts: [{ kind: 'day', date, label: '', slots, filled: [slot] }] };
    }
    case 'clear_day_slot': { const date = String(p.date ?? today()); const slots = await plan.setDaySlot(v, date, p.slot as DaySlot, null); return { parts: [{ kind: 'day', date, label: '', slots, filled: [] }] }; }
    case 'plan_day': { const ctx = await buildAthleteContext(v); return { parts: [await planDayPart(v, ctx, String(p.date ?? today()))] }; }
    // ---- plans
    case 'new_plan': return { parts: [{ kind: 'batch', plan: await plan.newPlan(v, scope) }] };   // declared in contracts.ts, never implemented in the prototype
    case 'get_plan': { const pl = p.id ? await plan.getPlanById(v, String(p.id)) : await plan.resolvePlan(v, scope, false); return { parts: pl ? [{ kind: 'batch', plan: pl }] : [] }; }
    case 'list_plans': return { parts: [], plans: await plan.listPlans(v) };
    // ---- app-only (the Flutter client's read/write channel for what the web does through server fns)
    case 'get_home': { const home = await homePayload(v, p.date ? String(p.date) : undefined); return { parts: home.batch ? [home.batch] : [], home }; }
    case 'get_meal': { const meal = await getMealDetail(v, String(p.id)); if (!meal) throw new Error(`meal not found: ${p.id}`); return { parts: [], meal }; }
    case 'recent_meals': return { parts: [], meals: await recentMeals(v, Math.min(Number(p.limit ?? 20), 200)) };
    case 'set_saved_meal_notes': { const r = await setSavedMealNotes(v, String(pick(p, 'savedMealId', 'saved_meal_id')), String(p.notes ?? '')); if (!r.ok) throw new Error(r.error ?? 'update failed'); return { parts: [], notes: r.notes }; }
    case 'set_meal_feedback': { const vote = await setMealFeedback(v, { libraryMealId: pick(p, 'libraryMealId', 'library_meal_id') ?? null, savedMealId: pick(p, 'savedMealId', 'saved_meal_id') ?? null }, Number(p.vote) as -1 | 0 | 1, p.reason ?? null); return { parts: [], vote }; }
    default: throw new Error(`unknown action ${a.type}`);
  }
}

/** Extra actions the UI needs that aren't in the UiAction switch above (additive). Null when `type` is not one of them. */
// deno-lint-ignore no-explicit-any
export async function extraAction(v: VanaCtx, type: string, p: Record<string, any>): Promise<ActionResult | null> {
  const planMealId = () => String(pick(p, 'planMealId', 'plan_meal_id'));
  switch (type) {
    case 'remove_meal': return { parts: [{ kind: 'batch', plan: await plan.setServings(v, planMealId(), 0) }] };
    case 'set_session': return { parts: [{ kind: 'batch', plan: await plan.setSession(v, planMealId(), p.session ?? null) }] };
    case 'apply_swap': return { parts: [{ kind: 'batch', plan: await plan.applySwap(v, planMealId(), { from: String(p.from), to: String(p.to), effect: p.effect }) }] };
    case 'add_comment': return { parts: [{ kind: 'batch', plan: await plan.addComment(v, planMealId(), p.role === 'vana' ? 'vana' : 'user', String(p.text)) }] };
    case 'accept_rule': { const pl = await plan.setRule(v, { day: p.day, rule: String(p.rule), mealId: pick(p, 'mealId', 'meal_id'), accepted: !!p.accepted }); return { parts: [{ kind: 'batch', plan: pl }] }; }
    case 'list_memories': return { parts: [], memories: await listMemories(v) };
    case 'save_meal': return { parts: [], meal: await saveLibraryMeal(v, String(pick(p, 'libraryMealId', 'library_meal_id'))) };   // heart on the detail page
    // ---- additive 2026-09-03 (plan Phases 6, 7)
    case 'swap_ingredient': return { parts: [{ kind: 'batch', plan: await plan.swapIngredient(v, planMealId(), String(p.from), String(p.to)) }] };
    case 'set_pantry': { const conversationId = pick(p, 'conversationId', 'conversation_id'); const items = (Array.isArray(p.items) ? p.items : []).map((x: unknown) => String(x).trim()).filter(Boolean).slice(0, 40); const m = await setSetting(v, 'pantry_items', items, 'conversation'); const scope: plan.PlanScope | null = conversationId ? { conversationId: String(conversationId) } : null; const cur = await plan.resolvePlan(v, scope, false); if (cur && cur.meals.length) await plan.refreshShopping(v, cur.id); return { parts: [{ kind: 'memory_saved', memory: m }] }; }
    case 'pantry_photo': { const conversationId = String(pick(p, 'conversationId', 'conversation_id') ?? ''); if (!conversationId) throw new Error('conversationId required'); const part = await detectPantryFromPhoto(v, String(pick(p, 'photoPath', 'photo_path'))); const messageId = await persistAssistantPart(v, conversationId, part, part.items.length ? 'Here is what I could see — untick anything that is wrong, add what I missed, then tap Use these.' : 'I could not spot food in that photo. Add what you have and tap Use these.'); return { parts: [part], messageId }; }
    case 'rewind': {
      // Drop the edited user turn and everything after it, then put the draft back to the snapshot the previous assistant turn stored.
      const conversationId = String(pick(p, 'conversationId', 'conversation_id') ?? ''); const messageId = String(pick(p, 'messageId', 'message_id') ?? '');
      const { data: target } = await v.db.from('vana_messages').select('id, created_at, role').eq('id', messageId).eq('conversation_id', conversationId).eq('user_id', v.userId).maybeSingle();
      if (!target) throw new Error('message not found');
      const { data: prior } = await v.db.from('vana_messages').select('metadata').eq('conversation_id', conversationId).eq('user_id', v.userId).eq('role', 'assistant').lt('created_at', target.created_at).order('created_at', { ascending: false }).limit(1).maybeSingle();
      const snap = (prior?.metadata?.plan_snapshot ?? []) as plan.MealSnapshot;
      const { data: gone } = await v.db.from('vana_messages').delete().eq('conversation_id', conversationId).eq('user_id', v.userId).gte('created_at', target.created_at).select('id');
      const restored = await plan.restorePlan(v, { conversationId }, snap);
      return { parts: [{ kind: 'batch', plan: restored }], removed: (gone ?? []).length };
    }
    default: return null;
  }
}

/** get_home {date?} — what the Food → Plan screen needs: the plan, the day planner, a small day card, staples when there is no plan. No model call. */
export async function homePayload(v: VanaCtx, date = today()) {
  const ctx = await buildAthleteContext(v, undefined, date);
  const [day, pl] = await Promise.all([dayGuidance(v, ctx, date), plan.getPlan(v)]);
  const staples = pl && pl.meals.length ? null : await diagnoseStaples(v);
  const slots = (pl?.days?.[date] ?? {}) as DayPlan;
  const target = ctx.budget.week.find((t) => t.date === date) ?? (date === today() ? ctx.budget.today : null);
  // Vana's message for the day: precomputed on the plan (regenerated here only when an edit made it stale).
  const { notes: dayNotes, stale } = await ensureDayNotes(v, pl, date);
  const vana = { date, stale, text: dayNotes[date] ?? (pl && pl.meals.length ? null : (day.note ? `${day.label}. At least ${day.minCarbsG}g carbs — ${day.note}.` : null)) };
  return { context: ctx, brief: null, day, target, weekTargets: ctx.budget.week, staples, batch: pl ? ({ kind: 'batch', plan: pl ? { ...pl, dayNotes } : pl } as VanaPart) : null, shopping: pl ? shop(pl.shopping) : null, days: { date, slots }, vana, memories: await listMemories(v) };
}
