/**
 * What an athlete does becomes a Score in Langfuse (langfuse ticket 13): confirming a plan, and telling Vana what they
 * think. Each is written by the server against the Conversation's Session, and a Score that cannot be written changes
 * nothing the athlete sees.
 *
 * Confirm runs through `confirmPlan` (what the Confirm button's action and Vana's tool both call) and feedback through
 * the `saveFeedback` tool's own `execute`, over the fake database. A recorder stands in for the sender; the sender
 * itself is driven against a stub of Langfuse's API behind `fetch`, answering in the shape Langfuse answers.
 */
import { assert, assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { confirmPlan, newPlan, scoreDraftLeftBehind } from '../../_shared/vana/plan.ts';
import { deletePlan } from '../../_shared/vana/writes.ts';
import { makeVanaTools } from '../../_shared/vana/tools.ts';
import { today, weekStartFor } from '../../_shared/vana/env.ts';
import { langfuseScoreSender, setScoreSender, type Score } from '../../_shared/langfuse/scores.ts';
import { testCtx, TEST_USER_ID } from './support/vana_ctx.ts';

const U = TEST_USER_ID;
const WEEK = weekStartFor(today());
const DRAFT = '54a02440-0000-4000-8000-000000000002';
const CONV = 'd8efbdb3-0000-4000-8000-000000000002';

const planRow = (conversationId: string | null) => ({
  id: DRAFT, user_id: U, week_start: WEEK, status: 'draft', batch_cooking: true, conversation_id: conversationId, brief: null, rules: [], shopping: [], days: {}, day_notes: {}, day_notes_stale: false, is_deleted: false,
  created_at: '2026-09-24T09:23:00Z', updated_at: '2026-09-24T09:23:00Z',
});
const mealRow = { id: 'm3', plan_id: DRAFT, user_id: U, source: 'library', library_meal_id: 'D-100', saved_meal_id: null, name: 'D-100', meal_type: 'dinner', session: null, servings: 4, servings_left: 4, kcal: 700, carbs_g: 70, protein_g: 35, fat_g: 18, swaps_applied: [], comments: [], position: 0, icon: null, created_at: '2026-09-24T12:00:00Z' };

/** A Draft with one meal, owned by `conversationId`, and the confirm transaction as the SQL function performs it. */
function draftOf(conversationId: string | null) {
  const v = testCtx({ meal_plans: [planRow(conversationId)], plan_meals: [mealRow] }, {
    defaults: {
      shopping_lists: { name: '', plan_id: null, confirmed_at: null, updated_at: new Date().toISOString() },
      shopping_items: { qty: '', aisle: 'Other', checked: false, have: false, source: 'manual', from_meal_ids: [], edited: false, position: 0 },
    },
    rpc: {
      confirm_meal_plan: (args: { p_plan_id: string; p_shopping: unknown }) => {
        const target = v.fake.rows('meal_plans').find((r) => r.id === args.p_plan_id)!;
        target.status = 'confirmed'; target.shopping = args.p_shopping;
        return target;
      },
    },
  });
  return v;
}

/** Records every Score in place of the sender; `down` is Langfuse refusing each one. */
async function recording<T>(body: (sent: Score[]) => Promise<T>, down = false): Promise<T> {
  const sent: Score[] = [];
  setScoreSender((score) => { sent.push(score); return down ? Promise.reject(new Error('langfuse is down')) : Promise.resolve(); });
  try { return await body(sent); } finally { setScoreSender(null); }
}

// deno-lint-ignore no-explicit-any
const planningTools = (v: any) => makeVanaTools(v, {} as never, 'meal_planning', { scope: { conversationId: CONV }, conversationId: CONV }) as Record<string, any>;
const feedback = (sentiment: 'positive' | 'negative' | 'neutral') => ({ message: 'you keep suggesting fish', sentiment, about: 'vana' });

Deno.test('confirming a plan writes plan_confirmed = yes against the planning Conversation', async () => {
  const v = draftOf(CONV);
  await recording(async (sent) => {
    const plan = await confirmPlan(v, { conversationId: CONV });
    assertEquals(plan.status, 'confirmed');
    assertEquals(sent, [{ name: 'plan_confirmed', value: 1, dataType: 'BOOLEAN', sessionId: CONV, environment: undefined }]);
  });
});

Deno.test('a confirm made in an Experiment is scored in the experiment environment', async () => {
  const v = { ...draftOf(CONV), environment: 'experiment' as const };
  await recording(async (sent) => {
    await confirmPlan(v, { conversationId: CONV });
    assertEquals(sent.map((s) => s.environment), ['experiment']);
  });
});

Deno.test('a plan confirmed outside any Conversation writes no Score: there is no Session to put it on', async () => {
  const v = draftOf(null);
  await recording(async (sent) => {
    assertEquals((await confirmPlan(v, { planId: DRAFT })).status, 'confirmed');
    assertEquals(sent, []);
  });
});

Deno.test('a Score that cannot be written leaves the confirm as it was', async () => {
  const v = draftOf(CONV);
  await recording(async (sent) => {
    const plan = await confirmPlan(v, { conversationId: CONV });
    assertEquals(plan.status, 'confirmed', 'the athlete gets their confirmed plan');
    assertEquals(v.fake.rows('meal_plans')[0].status, 'confirmed');
    assertEquals(sent.length, 1, 'the write was tried');
  }, true);
});

Deno.test("the feedback tool writes athlete_feedback with the athlete's rating against its Conversation", async () => {
  for (const [sentiment, value] of [['positive', 1], ['negative', -1]] as const) {
    const v = testCtx({ user_feedback: [] });
    await recording(async (sent) => {
      const out = await planningTools(v).saveFeedback.execute(feedback(sentiment), {});
      assertEquals(out.kind, 'feedback_saved');
      assertEquals(sent, [{ name: 'athlete_feedback', value, dataType: 'NUMERIC', sessionId: CONV, comment: 'vana: you keep suggesting fish', environment: undefined }], sentiment);
      // The same rating the feedback row holds.
      assertEquals(v.fake.rows('user_feedback')[0].rating, value);
    });
  }
});

Deno.test('feedback that is neither positive nor negative has no rating, so it writes no Score', async () => {
  const v = testCtx({ user_feedback: [] });
  await recording(async (sent) => {
    assertEquals((await planningTools(v).saveFeedback.execute(feedback('neutral'), {})).kind, 'feedback_saved');
    assertEquals(v.fake.rows('user_feedback')[0].rating, null);
    assertEquals(sent, []);
  });
});

Deno.test('a Score that cannot be written leaves the feedback saved and acknowledged', async () => {
  const v = testCtx({ user_feedback: [] });
  await recording(async () => {
    const out = await planningTools(v).saveFeedback.execute(feedback('negative'), {});
    assertEquals(out, { kind: 'feedback_saved', message: 'you keep suggesting fish', sentiment: 'negative', about: 'vana' });
    assertEquals(v.fake.rows('user_feedback').length, 1);
  }, true);
});

// ---------------------------------------------------------------- an abandoned Draft (Lee, 2026-09-30)
// A Draft holding at least one meal is abandoned when it is archived or deleted unconfirmed, or when the athlete opens
// a new planning conversation while it sits unconfirmed.

const NO = (sessionId: string): Score => ({ name: 'plan_confirmed', value: 0, dataType: 'BOOLEAN', sessionId, environment: undefined });
const OTHER = '99999999-0000-4000-8000-000000000009';
const OTHER_CONV = 'aaaaaaaa-0000-4000-8000-000000000009';
const NEW_CONV = 'bbbbbbbb-0000-4000-8000-00000000000b';
const conversationRow = (id: string, createdAt: string, kind = 'meal_planning') => ({ id, user_id: U, kind, is_deleted: false, created_at: createdAt });

Deno.test('New plan in a conversation whose Draft holds a meal writes plan_confirmed = no', async () => {
  const v = draftOf(CONV);
  await recording(async (sent) => {
    await newPlan(v, { conversationId: CONV });
    assertEquals(sent, [NO(CONV)]);
  });
});

Deno.test('a Draft with no meals in it is never abandoned: nothing was being planned', async () => {
  const v = draftOf(CONV);
  v.fake.tables.plan_meals = [];
  await recording(async (sent) => {
    await newPlan(v, { conversationId: CONV });
    assertEquals(sent, []);
  });
});

Deno.test('deleting an unconfirmed Draft writes plan_confirmed = no; deleting a confirmed plan writes nothing', async () => {
  const draft = draftOf(CONV);
  await recording(async (sent) => {
    await deletePlan(draft, DRAFT, null, true);
    assertEquals(sent, [NO(CONV)]);
  });
  const confirmed = draftOf(CONV);
  confirmed.fake.rows('meal_plans')[0].status = 'confirmed';
  await recording(async (sent) => {
    await deletePlan(confirmed, DRAFT, null, true);
    assertEquals(sent, []);
  });
});

Deno.test("confirming one plan writes no for another conversation's Draft the confirm archives", async () => {
  const v = draftOf(CONV);
  v.fake.tables.meal_plans.push({ ...planRow(OTHER_CONV), id: OTHER });
  v.fake.tables.plan_meals.push({ ...mealRow, id: 'm9', plan_id: OTHER });
  await recording(async (sent) => {
    await confirmPlan(v, { conversationId: CONV });
    assertEquals(sent.map((s) => [s.sessionId, s.value]).sort(), [[OTHER_CONV, 0], [CONV, 1]].sort());
  });
});

Deno.test('opening a new planning conversation writes no for the Draft the one before it left unconfirmed, once', async () => {
  const v = draftOf(CONV);
  v.fake.tables.vana_conversations = [conversationRow(CONV, '2026-09-24T09:00:00Z'), conversationRow(NEW_CONV, '2026-09-25T09:00:00Z')];
  await recording(async (sent) => {
    await scoreDraftLeftBehind(v, NEW_CONV);
    assertEquals(sent, [NO(CONV)]);
    // A third conversation looks at the one before it, not at the first again.
    const THIRD = 'cccccccc-0000-4000-8000-00000000000c';
    v.fake.tables.vana_conversations.push(conversationRow(THIRD, '2026-09-26T09:00:00Z'));
    await scoreDraftLeftBehind(v, THIRD);
    assertEquals(sent.length, 1, 'the first Draft is not scored a second time');
  });
});

Deno.test('a new planning conversation after a confirmed plan writes nothing', async () => {
  const v = draftOf(CONV);
  v.fake.rows('meal_plans')[0].status = 'confirmed';
  v.fake.tables.vana_conversations = [conversationRow(CONV, '2026-09-24T09:00:00Z'), conversationRow(NEW_CONV, '2026-09-25T09:00:00Z')];
  await recording(async (sent) => {
    await scoreDraftLeftBehind(v, NEW_CONV);
    assertEquals(sent, []);
  });
});

// ---------------------------------------------------------------- the sender, against Langfuse's API

/** Langfuse's public API behind `fetch`: the score configs as it lists them, and every Score it is sent. */
async function withLangfuse<T>(body: (seen: { scores: Record<string, unknown>[]; configReads: number; authorization: string[] }) => Promise<T>): Promise<T> {
  const seen = { scores: [] as Record<string, unknown>[], configReads: 0, authorization: [] as string[] };
  const realFetch = globalThis.fetch;
  globalThis.fetch = (async (input: Request | URL | string, init?: RequestInit) => {
    const req = input instanceof Request ? input : new Request(input, init);
    const url = new URL(req.url);
    seen.authorization.push(req.headers.get('authorization') ?? '');
    if (url.pathname === '/api/public/score-configs') {
      seen.configReads++;
      return new Response(JSON.stringify({ data: [
        { id: 'cfg-feedback', name: 'athlete_feedback', dataType: 'NUMERIC', isArchived: false, minValue: -1, maxValue: 1 },
        { id: 'cfg-confirmed', name: 'plan_confirmed', dataType: 'BOOLEAN', isArchived: false },
        { id: 'cfg-old', name: 'plan_confirmed', dataType: 'BOOLEAN', isArchived: true },
      ], meta: { page: 1, limit: 100, totalItems: 3, totalPages: 1 } }), { headers: { 'content-type': 'application/json' } });
    }
    if (url.pathname === '/api/public/scores' && req.method === 'POST') { seen.scores.push(await req.json()); return new Response(JSON.stringify({ id: 'score-1' }), { headers: { 'content-type': 'application/json' } }); }
    return new Response('not found', { status: 404 });
  }) as typeof fetch;
  try { return await body(seen); } finally { globalThis.fetch = realFetch; }
}

Deno.test('each Score is sent under the score config of its name, in the project\'s environment unless it names another', async () => {
  await withLangfuse(async (seen) => {
    const send = langfuseScoreSender({ publicKey: 'pk-test', secretKey: 'sk-test', baseUrl: 'http://langfuse.invalid', environment: 'dev' });
    await send({ name: 'plan_confirmed', value: 1, dataType: 'BOOLEAN', sessionId: CONV });
    await send({ name: 'athlete_feedback', value: -1, dataType: 'NUMERIC', sessionId: CONV, comment: 'vana: you keep suggesting fish', environment: 'experiment' });
    assertEquals(seen.scores, [
      { name: 'plan_confirmed', value: 1, dataType: 'BOOLEAN', sessionId: CONV, configId: 'cfg-confirmed', environment: 'dev' },
      { name: 'athlete_feedback', value: -1, dataType: 'NUMERIC', sessionId: CONV, configId: 'cfg-feedback', comment: 'vana: you keep suggesting fish', environment: 'experiment' },
    ]);
    assertEquals(seen.configReads, 1, 'the configs are read once and kept for the instance');
    assert(seen.authorization.every((a) => a === `Basic ${btoa('pk-test:sk-test')}`));
  });
});
