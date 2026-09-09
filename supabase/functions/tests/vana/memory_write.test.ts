/**
 * The deduped Memory writer.
 *
 * The fake `recall_memories` here scores the same way the SQL function does — cosine similarity,
 * 0.3 for a row with no embedding — so the test exercises the real threshold rather than a stub
 * that answers yes or no.
 */
import { assert, assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { rememberFact, listMemories, forgetMemory, episodeFor, MEMORY_DUPLICATE_SIMILARITY } from '../../_shared/vana/memory.ts';
import { buildAthleteContext, contextBlock } from '../../_shared/vana/context.ts';
import { offlineDeps } from './support/vana_ctx.ts';
import { testCtx, TEST_USER_ID } from './support/vana_ctx.ts';
import type { Row } from './support/fake_db.ts';
import type { VanaCtx } from '../../_shared/vana/env.ts';

const U = TEST_USER_ID;

/** A toy embedder: one dimension per word, so two sentences sharing words sit close together. */
const VOCAB = ['skips', 'fish', 'weeknights', 'avoids', 'on', 'a', 'school', 'night', 'wednesdays', 'are', 'chaos', 'partner', 'is', 'vegetarian'];
const embed = (text: string): number[] => {
  const words = text.toLowerCase().replace(/[^a-z ]/g, '').split(/\s+/).filter(Boolean);
  const v = VOCAB.map((w) => (words.includes(w) ? 1 : 0));
  const n = Math.hypot(...v) || 1;
  return v.map((x) => x / n);
};
const cosine = (a: number[], b: number[]) => a.reduce((s, x, i) => s + x * (b[i] ?? 0), 0);

/** A context whose recall_memories scores against the rows the fake database currently holds —
 *  including rows this test just wrote, which is what makes the second write a duplicate. */
function ctxWith(memories: Row[]) {
  // deno-lint-ignore no-explicit-any
  let live: any;
  const ctx = testCtx({ user_memories: memories }, {
    rpc: {
      recall_memories: (args: { p_embedding: string; p_limit: number }) => {
        const q = JSON.parse(args.p_embedding) as number[];
        return (live.rows('user_memories') as Row[])
          .filter((r) => r.user_id === U && !r.is_deleted)
          .map((r) => ({ ...r, score: r.embedding ? cosine(q, JSON.parse(r.embedding) as number[]) : 0.3 }))
          .sort((a, b) => b.score - a.score)
          .slice(0, args.p_limit);
      },
    },
  });
  live = ctx.fake;
  return ctx;
}
const deps = { embed: (_v: VanaCtx, text: string) => Promise.resolve(embed(text)) };

const row = (over: Partial<Row>): Row => ({
  id: crypto.randomUUID(), user_id: U, kind: 'pattern', key: null, value: null, confidence: 0.8,
  last_confirmed_at: '2026-09-01T10:00:00Z', source: 'debrief', is_deleted: false, ...over,
  embedding: over.embedding ?? JSON.stringify(embed(String(over.fact ?? ''))),
} as Row);

Deno.test('a sentence near-identical to one on file is not written twice; the existing row is refreshed', async () => {
  const existing = row({ fact: 'Skips fish on weeknights' });
  const v = ctxWith([existing]);

  const out = await rememberFact(v, { kind: 'pattern', fact: 'Skips fish on weeknights', source: 'conversation' }, deps);

  assertEquals(v.fake.writesTo('user_memories', 'insert').length, 0, 'nothing was inserted');
  assertEquals(out.id, existing.id, 'the write returned the row already on file');
  const refreshed = v.fake.rows('user_memories').find((r) => r.id === existing.id)!;
  assert(refreshed.last_confirmed_at > existing.last_confirmed_at, `confirmed date moved (${refreshed.last_confirmed_at})`);
  assertEquals(v.fake.rows('user_memories').length, 1);
});

Deno.test('a distinct sentence is written', async () => {
  const v = ctxWith([row({ fact: 'Skips fish on weeknights' })]);
  await rememberFact(v, { kind: 'preference', fact: 'Partner is vegetarian', source: 'conversation' }, deps);
  assertEquals(v.fake.writesTo('user_memories', 'insert').length, 1);
  assertEquals(v.fake.rows('user_memories').length, 2);
  assertEquals((await listMemories(v)).length, 2);
});

Deno.test("the duplicated debrief learning on dev, replayed through the writer, yields one row", async () => {
  // The dev fixture: the same learning written twice by two debriefs. Replaying both must leave one.
  const v = ctxWith([]);
  const learning = 'Skips fish on weeknights';
  await rememberFact(v, { kind: 'pattern', fact: learning, source: 'debrief' }, deps);
  await rememberFact(v, { kind: 'pattern', fact: learning, source: 'debrief' }, deps);
  assertEquals(v.fake.rows('user_memories').length, 1);
  assertEquals(v.fake.writesTo('user_memories', 'insert').length, 1);
});

Deno.test('settings keep their one-row-per-key path and are never deduped against sentences', async () => {
  const v = ctxWith([row({ kind: 'setting', key: 'batch_cooking', fact: 'Cooks in batches', value: true, source: 'settings' })]);
  await rememberFact(v, { kind: 'setting', key: 'batch_cooking', fact: 'Cooks most nights — no batch cooking', value: false, source: 'settings' }, deps);
  const rows = v.fake.rows('user_memories').filter((r) => r.kind === 'setting');
  assertEquals(rows.length, 1);
  assertEquals(rows[0].fact, 'Cooks most nights — no batch cooking');
  assertEquals(rows[0].value, false);
});

Deno.test('an episode is one row per conversation, rewritten rather than piled up', async () => {
  const v = ctxWith([]);
  await rememberFact(v, { kind: 'episode', key: 'conv-1', fact: 'Planned three dinners around Saturday’s long ride.', source: 'conversation' }, deps);
  await rememberFact(v, { kind: 'episode', key: 'conv-1', fact: 'Planned three dinners and a lunch.', source: 'conversation' }, deps);
  await rememberFact(v, { kind: 'episode', key: 'conv-2', fact: 'Asked about race-week carbs.', source: 'conversation' }, deps);

  assertEquals(v.fake.rows('user_memories').filter((r) => r.kind === 'episode').length, 2);
  assertEquals(await episodeFor(v, 'conv-1'), 'Planned three dinners and a lunch.');
  assertEquals(await episodeFor(v, 'conv-2'), 'Asked about race-week carbs.');
  assertEquals(await episodeFor(v, 'conv-3'), null);
});

Deno.test('with no embedding service the note is still written — a duplicate beats a lost note', async () => {
  const v = ctxWith([row({ fact: 'Skips fish on weeknights' })]);
  const failing = { embed: () => Promise.reject(new Error('gateway down')) };
  await rememberFact(v, { kind: 'pattern', fact: 'Skips fish on weeknights', source: 'conversation' }, failing);
  assertEquals(v.fake.writesTo('user_memories', 'insert').length, 1);
});

Deno.test('the threshold is a near-identity threshold, not a topic threshold', () => {
  assert(MEMORY_DUPLICATE_SIMILARITY >= 0.9 && MEMORY_DUPLICATE_SIMILARITY <= 1, `threshold is ${MEMORY_DUPLICATE_SIMILARITY}`);
  // Same subject, different claim — must sit below the threshold and be written as its own note.
  assert(cosine(embed('Skips fish on weeknights'), embed('Avoids fish on a school night')) < MEMORY_DUPLICATE_SIMILARITY);
  assertEquals(Math.round(cosine(embed('Skips fish on weeknights'), embed('Skips fish on weeknights')) * 1000) / 1000, 1);
});

Deno.test('a deleted Memory is absent from the next turn\'s block', async () => {
  const keep = row({ fact: 'Hates cilantro', source: 'conversation' });
  const drop = row({ fact: 'Partner is vegetarian', source: 'conversation' });
  const v = ctxWith([keep, drop]);
  v.fake.tables.users = [{ id: U, first_name: 'Lee', allergies: [] }];

  const before = contextBlock(await buildAthleteContext(v, undefined, '2026-09-09', offlineDeps()));
  assert(before.includes('Partner is vegetarian'), 'it was in the block to begin with');

  await forgetMemory(v, drop.id as string);

  const after = contextBlock(await buildAthleteContext(v, undefined, '2026-09-09', offlineDeps()));
  assert(!after.includes('Partner is vegetarian'), 'the deleted Memory is gone from the block');
  assert(after.includes('Hates cilantro'), 'the one that was kept is still there');
  // A tombstone, not a hard delete — the row is still on file, flagged.
  assertEquals(v.fake.rows('user_memories').length, 2);
  assertEquals(v.fake.rows('user_memories').find((r) => r.id === drop.id)!.is_deleted, true);
});

