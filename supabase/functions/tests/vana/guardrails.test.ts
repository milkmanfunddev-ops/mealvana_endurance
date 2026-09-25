/**
 * Guardrails: no free turn, and a limiter that cannot be raced (mp-469, from mp-430 clause 9).
 *
 * Three claims, at the seams that carry them:
 *
 *  1. A turn nobody asked for is never run. An empty message on a conversation that already holds
 *     turns used to replay the whole history to the model and store an answer — a full-price turn
 *     for a request that said nothing. It is a 400 now, before the model and before any row.
 *  2. The bucket is the row, and the row is written first. `checkRateLimit` counted rows that only
 *     appeared in `onFinish`, so five requests fired at once all read an empty bucket and all five
 *     ran. `reserveCall` inserts the row, then lets the database decide who is early enough: a call
 *     is counted when it starts (mp-430 clause 9), and the loser's row is withdrawn.
 *  3. A turn stops on tokens as well as steps. Six steps of a runaway tool loop are six billed
 *     calls even when each one is short.
 *
 * The limiter stays server-side (spec `.scratch/ai-cost/spec.md`, Lee's rulings 2026-09-21): the
 * photo and description paths call this module, and nothing counts on the phone.
 */
import { assert, assertEquals, assertRejects } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { RATE_LIMIT_WINDOWS, RateLimitedError, completeCall, reserveCall, reserveCallOrThrow } from '../../_shared/vana/rate-limit.ts';
import { TURN_TOKEN_CEILING, chatStopWhen, runChat, tokenBudgetIs } from '../../_shared/vana/chat.ts';
import { extraAction } from '../../_shared/vana/actions.ts';
import { testCtx, TEST_USER_ID } from './support/vana_ctx.ts';
import type { Row, Tables } from './support/fake_db.ts';

const U = TEST_USER_ID;
const CONV = 'conv-guardrails';

const conversation = (over: Partial<Row> = {}): Row => ({ id: CONV, user_id: U, kind: 'general', title: null, summary: null, summary_index: null, is_deleted: false, read_back_at: null, last_message_at: '2026-09-21T09:30:00Z', created_at: '2026-09-21T09:00:00Z', ...over });
/** Two stored turns: the athlete asked something and Vana answered. */
const storedTurns = (): Row[] => [
  { id: 'm000', conversation_id: CONV, user_id: U, role: 'user', content: 'what should I eat tonight?', parts: null, metadata: null, created_at: '2026-09-21T09:00:10Z' },
  { id: 'm001', conversation_id: CONV, user_id: U, role: 'assistant', content: 'The lentil bolognese is ready to go.', parts: [{ type: 'text', text: 'The lentil bolognese is ready to go.' }], metadata: null, created_at: '2026-09-21T09:00:20Z' },
];
const world = (over: Partial<Tables> = {}): Tables => ({ vana_conversations: [conversation()], vana_messages: storedTurns(), user_memories: [], vana_calls: [], ...over });
/** A call row as the table holds it, `seconds` ago. */
const callRow = (fn: string, secondsAgo: number, i: number): Row => ({ id: `call-${i}`, user_id: U, conversation_id: CONV, function_name: fn, model: 'anthropic/claude-haiku-4.5', input_tokens: 800, output_tokens: 120, cache_read_tokens: 0, created_at: new Date(Date.now() - secondsAgo * 1000).toISOString() });

// ---------------------------------------------------------------- 1. no free turn

Deno.test('an empty message on a conversation with turns is a 400 — no model, no row', async () => {
  const v = testCtx(world());
  const out = await runChat(v, { kind: 'general', conversation_id: CONV, message: '   ' }, { functionName: 'vana-chat' });
  assertEquals(out, { ok: false, status: 400, body: { error: 'message_required' } });
  assertEquals(v.fake.writes, []); // nothing stored: no user row, no reservation, no conversation
});

Deno.test('a missing message is the same refusal as an empty one', async () => {
  const v = testCtx(world());
  const out = await runChat(v, { kind: 'meal_planning', conversation_id: CONV }, { functionName: 'vana-chat' });
  assertEquals(out, { ok: false, status: 400, body: { error: 'message_required' } });
  assertEquals(v.fake.writes, []);
});

Deno.test('the scripted opener still asks for no message', async () => {
  // opener:true on a conversation with turns is a moment's opener (VM-1) — it must not hit the guard.
  const v = testCtx(world(), { errors: { vana_conversations: 'stop here' } });
  const out = await runChat(v, { kind: 'general', conversation_id: CONV, opener: true }, { functionName: 'vana-chat' }).catch((e) => e as Error);
  assert(out instanceof Error, 'the opener ran past the empty-message guard and reached the conversation read');
});

// ---------------------------------------------------------------- 2. a limiter that cannot be raced

Deno.test('five calls fired at once against a limit of four let four through', async () => {
  const w = RATE_LIMIT_WINDOWS['vana.chat'];
  assertEquals(w.max, 4);
  const v = testCtx(world());
  const results = await Promise.all(Array.from({ length: 5 }, () => reserveCall(v.admin, U, 'vana.chat', { functionName: 'vana.chat.general', model: 'm' })));
  assertEquals(results.filter((r) => r.allowed).length, 4);
  const refused = results.find((r) => !r.allowed) as { allowed: false; retryAfterSeconds: number };
  assertEquals(refused.retryAfterSeconds, w.seconds);
  // The bucket holds exactly the four that ran: the loser's reservation is withdrawn, not left to block the next minute.
  assertEquals(v.fake.rows('vana_calls').length, 4);
});

Deno.test('the row is written before the decision, so a call is counted when it starts', async () => {
  const v = testCtx(world());
  const r = await reserveCall(v.admin, U, 'vana.chat', { functionName: 'vana.chat.general', model: 'anthropic/claude-haiku-4.5' });
  assert(r.allowed);
  const [write] = v.fake.writesTo('vana_calls', 'insert');
  assertEquals(write.values.function_name, 'vana.chat.general');
  assertEquals(write.values.user_id, U);
  assertEquals(write.values.model, 'anthropic/claude-haiku-4.5');
  // Tokens land on the same row when the turn finishes — one row per call, not two.
  await completeCall(v.admin, r.callId, { inputTokens: 1200, outputTokens: 90, cacheReadTokens: 1000 });
  const row = v.fake.rows('vana_calls')[0];
  assertEquals([row.input_tokens, row.output_tokens, row.cache_read_tokens], [1200, 90, 1000]);
});

Deno.test('where the database has vana_reserve_call, it decides: its id is the reservation, its null is the refusal', async () => {
  // deno-lint-ignore no-explicit-any
  const seen: any[] = [];
  const room = testCtx(world(), { rpc: { vana_reserve_call: (a: unknown) => { seen.push(a); return 'call-from-db'; } } });
  assertEquals(await reserveCall(room.admin, U, 'vana.chat', { functionName: 'vana.chat.general', model: 'm' }), { allowed: true, callId: 'call-from-db' });
  assertEquals(seen[0], { p_user_id: U, p_bucket: 'vana.chat', p_function_name: 'vana.chat.general', p_model: 'm', p_window_seconds: RATE_LIMIT_WINDOWS['vana.chat'].seconds, p_max: RATE_LIMIT_WINDOWS['vana.chat'].max });
  assertEquals(room.fake.writes, [], 'the function wrote the row; the module writes nothing beside it');

  const full = testCtx(world(), { rpc: { vana_reserve_call: () => null } });
  assertEquals(await reserveCall(full.admin, U, 'vana.chat', { model: 'm' }), { allowed: false, retryAfterSeconds: RATE_LIMIT_WINDOWS['vana.chat'].seconds });
  assertEquals(full.fake.writes, []);
});

Deno.test("the caller's conversation id never reaches the reservation: a malformed one cannot fail it open", async () => {
  const v = testCtx(world(), { errors: { vana_conversations: 'stop here' } });
  await runChat(v, { kind: 'general', conversation_id: 'not-a-uuid', message: 'hello' }, { functionName: 'vana-chat' }).catch(() => null);
  const [reserved] = v.fake.writesTo('vana_calls', 'insert');
  assert(reserved, 'the call was counted');
  assertEquals('conversation_id' in reserved.values, false);
});

Deno.test('a full bucket refuses, and rows outside the window do not count', async () => {
  const full = testCtx(world({ vana_calls: [0, 1, 2, 3].map((i) => callRow('vana.chat.general', 2, i)) }));
  const refused = await reserveCall(full.admin, U, 'vana.chat', { functionName: 'vana.chat.general', model: 'm' });
  assertEquals(refused.allowed, false);
  assertEquals(full.fake.rows('vana_calls').length, 4); // the refused reservation is gone again

  const stale = testCtx(world({ vana_calls: [0, 1, 2, 3].map((i) => callRow('vana.chat.general', 600, i)) }));
  const allowed = await reserveCall(stale.admin, U, 'vana.chat', { functionName: 'vana.chat.general', model: 'm' });
  assertEquals(allowed.allowed, true);
});

Deno.test('another athlete and another bucket are not this one', async () => {
  const v = testCtx(world({ vana_calls: [0, 1, 2, 3].map((i) => ({ ...callRow('vana.chat.general', 2, i), user_id: 'someone-else' })) }));
  assertEquals((await reserveCall(v.admin, U, 'vana.chat', { functionName: 'vana.chat.general', model: 'm' })).allowed, true);
  const other = testCtx(world({ vana_calls: [0, 1, 2, 3].map((i) => callRow('vana.opener.general', 2, i)) }));
  assertEquals((await reserveCall(other.admin, U, 'vana.chat', { functionName: 'vana.chat.general', model: 'm' })).allowed, true);
});

Deno.test('a database that will not answer fails open, and logs no reservation', async () => {
  const v = testCtx(world(), { errors: { vana_calls: 'vana_calls is down' } });
  const r = await reserveCall(v.admin, U, 'vana.chat', { functionName: 'vana.chat.general', model: 'm' });
  assertEquals(r, { allowed: true, callId: null });
});

Deno.test('runChat reserves before it touches the model or the conversation', async () => {
  // The conversation write is the first thing after the reservation; forcing it to fail proves the order:
  // the call row exists, and nothing downstream (model included) ever ran.
  const v = testCtx(world(), { errors: { vana_conversations: 'boom' } });
  await assertRejects(() => runChat(v, { kind: 'general', conversation_id: CONV, message: 'and tomorrow?' }, { functionName: 'vana-chat' }));
  assertEquals(v.fake.writesTo('vana_calls', 'insert').length, 1);
  assertEquals(v.fake.rows('vana_messages').length, 2); // the user turn is stored after the reservation, and never got there
});

Deno.test('a chat turn over the limit is a 429 from runChat, with no model call', async () => {
  const v = testCtx(world({ vana_calls: [0, 1, 2, 3].map((i) => callRow('vana.chat.general', 1, i)) }));
  const out = await runChat(v, { kind: 'general', conversation_id: CONV, message: 'and tomorrow?' }, { functionName: 'vana-chat' });
  assert(!out.ok);
  assertEquals(out.status, 429);
  assertEquals(out.body.error, 'rate_limited');
  assertEquals(v.fake.rows('vana_messages').length, 2);
});

// ---------------------------------------------------------------- the shared module is the only limiter

Deno.test('the pantry photo goes through the same module', async () => {
  // The budget (ticket 09) is reserved ahead of the limiter; a wallet with room lets the limiter be the one that refuses.
  const settled: unknown[] = [];
  const v = testCtx(world({ vana_calls: [0, 1, 2].map((i) => callRow('vana.pantry_photo', 5, i)) }), {
    rpc: {
      ai_budget_reserve: () => ({ allowed: true, reservation_id: 'hold-1', share_used: 0, refill_at: null, bought_extra_share: 0 }),
      ai_budget_settle: (a: unknown) => { settled.push(a); return null; },
    },
  });
  await assertRejects(
    () => extraAction(v, 'pantry_photo', { conversationId: CONV, photoPath: `${U}/fridge.jpg` }),
    RateLimitedError,
  );
  // Refused before the download and before the model: no assistant row, no reservation left behind, the budget hold refunded.
  assertEquals(v.fake.rows('vana_messages').length, 2);
  assertEquals(v.fake.rows('vana_calls').length, 3);
  assertEquals(settled, [{ p_id: 'hold-1', p_real_cost: 0 }]);
});

Deno.test('the described meal and the meal photo call the shared module, on the server', async () => {
  const describe = await Deno.readTextFile(new URL('../../describe-meal/index.ts', import.meta.url));
  const photo = await Deno.readTextFile(new URL('../../analyze-meal-photo/index.ts', import.meta.url));
  for (const [name, src] of [['describe-meal', describe], ['analyze-meal-photo', photo]] as const) {
    assert(src.includes("_shared/vana/rate-limit.ts"), `${name} does not import the shared limiter`);
    assert(/reserveCall\(/.test(src), `${name} does not reserve a call`);
    assert(/completeCall\(|finishMealCall\(/.test(src), `${name} does not complete its reservation`);
    assert(/rate_limited/.test(src), `${name} does not answer 429 rate_limited`);
  }
});

// ---------------------------------------------------------------- 3. a ceiling on the turn, and nothing more

Deno.test('a turn stops on tokens as well as steps', () => {
  const step = (total: number) => ({ usage: { inputTokens: total, outputTokens: 0, totalTokens: total } });
  const over = tokenBudgetIs(1000);
  assertEquals(over({ steps: [step(400), step(400)] as never }), false);
  assertEquals(over({ steps: [step(400), step(400), step(400)] as never }), true);
  // A usage the provider did not report cannot stop the turn on its own.
  assertEquals(over({ steps: [{ usage: {} }] as never }), false);
  // input + output when there is no total.
  assertEquals(tokenBudgetIs(10)({ steps: [{ usage: { inputTokens: 6, outputTokens: 6 } }] as never }), true);
  assert(TURN_TOKEN_CEILING > 0);
  // the step limit AND the token ceiling, then the terminal tools (mp-471: askChoice, handOff; saveFeedback only when silenced)
  assertEquals(chatStopWhen(false).length, 4);
  assertEquals(chatStopWhen(true).length, 4);
  assertEquals(chatStopWhen(true, true).length, 5);
});

Deno.test('the step limits are what the cost posture says', () => {
  const steps = (general: boolean) => chatStopWhen(general)[0]({ steps: Array.from({ length: general ? 8 : 6 }, () => ({})) as never });
  assertEquals(steps(false), true);
  assertEquals(steps(true), true);
});

Deno.test('no daily cap and no turn counter (mp-430 clause 9)', () => {
  for (const [fn, w] of Object.entries(RATE_LIMIT_WINDOWS)) {
    assert(w.seconds <= 60, `${fn} is a ${w.seconds}s window — the only ceiling above a minute is the monthly budget`);
    assert(w.max >= 1, `${fn} has no room at all`);
  }
  // No bucket is a day, a month or a count of turns — `vana.daynotes` is the day-notes call, not a daily cap.
  assert(!Object.keys(RATE_LIMIT_WINDOWS).some((k) => /\.(daily|day|month|monthly|turns?)$/.test(k)));
});

Deno.test('the photo and description paths have their own per-minute windows', () => {
  for (const fn of ['vana.pantry_photo', 'vana.describe_meal', 'vana.meal_photo'] as const) {
    assertEquals(RATE_LIMIT_WINDOWS[fn].seconds, 60);
  }
});

Deno.test('nothing counts on the phone', async () => {
  // A client-side limiter would be a second, weaker gate the server could not see (Lee, 2026-09-21).
  const dart = await Deno.readTextFile(new URL('../../../../lib/features/meal_planning/data/vana_chat_repository.dart', import.meta.url));
  assert(!/rateLimit|_bucket|retryAfter\s*=/.test(dart) || !/DateTime\.now\(\)\.difference/.test(dart));
});

Deno.test('reserveCallOrThrow carries the bucket and the wait', async () => {
  const v = testCtx(world({ vana_calls: [0, 1, 2].map((i) => callRow('vana.pantry_photo', 5, i)) }));
  const e = await reserveCallOrThrow(v.admin, U, 'vana.pantry_photo', { model: 'm' }).catch((x) => x as RateLimitedError);
  assert(e instanceof RateLimitedError);
  assertEquals(e.fn, 'vana.pantry_photo');
  assertEquals(e.retryAfterSeconds, 60);
});
