// Fetching the pictures the judge has to look at, tested with no network.
//
// Every assertion here is a way the 2026-09-10 sweep failed: Wikimedia started
// returning 429 at meal 30 and pass 8 skipped 41 of the next 44 meals in a few
// seconds, because a skip was cheap and a wait was not implemented. A skipped
// meal costs nothing in correctness — it stays unjudged and the next run picks
// it up — but a run that skips half the library measures half the library.
//
// Run with:  node --test scripts/meal-images/lib/fetch-tile.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';

import { createTileFetcher } from './fetch-tile.mjs';

const bytes = new Uint8Array([1, 2, 3]);
const ok = () => ({ ok: true, status: 200, arrayBuffer: async () => bytes.buffer });
const status = (code, headers = {}) => () => ({
  ok: false,
  status: code,
  headers: { get: (h) => headers[h.toLowerCase()] ?? null },
  arrayBuffer: async () => new ArrayBuffer(0),
});

/** A fetch that plays a script of responses, and a clock that records sleeps. */
function harness(script, opts = {}) {
  const calls = [];
  const slept = [];
  const fetcher = createTileFetcher({
    minGapMs: 0,
    fetchImpl: async (url) => {
      calls.push(url);
      const next = script.shift() ?? ok;
      return next(url);
    },
    sleep: async (ms) => { slept.push(ms); },
    ...opts,
  });
  return { fetcher, calls, slept };
}

test('a 429 is waited out and the picture is fetched, not skipped', async () => {
  const { fetcher, calls } = harness([status(429), status(429), ok]);

  const got = await fetcher('https://upload.wikimedia.org/a.jpg');

  assert.deepEqual(got, bytes);
  assert.equal(calls.length, 3, 'it kept asking');
});

test('the wait honours the host\'s own Retry-After', async () => {
  const { fetcher, slept } = harness([status(429, { 'retry-after': '30' }), ok]);

  await fetcher('https://upload.wikimedia.org/a.jpg');

  assert.ok(slept.includes(30_000), `expected a 30s wait, got ${slept}`);
});

test('after a 429 the host is asked more slowly, so the next meal does not trip it too', async () => {
  const { fetcher, slept } = harness([status(429), ok, ok], { minGapMs: 100 });

  await fetcher('https://upload.wikimedia.org/a.jpg');
  slept.length = 0;
  await fetcher('https://upload.wikimedia.org/b.jpg');

  assert.ok(slept.some((ms) => ms > 100), `expected a widened gap, got ${slept}`);
});

test('one slow host does not hold up the others', async () => {
  const { fetcher, slept } = harness([status(429), ok, ok], { minGapMs: 100 });

  await fetcher('https://upload.wikimedia.org/a.jpg');
  slept.length = 0;
  await fetcher('https://images.unsplash.com/b.jpg');

  assert.ok(!slept.some((ms) => ms > 100), `unsplash inherited wikimedia's backoff: ${slept}`);
});

test('a missing picture fails at once — retrying a 404 only wastes the run', async () => {
  const { fetcher, calls } = harness([status(404)]);

  await assert.rejects(() => fetcher('https://upload.wikimedia.org/gone.jpg'), /404/);
  assert.equal(calls.length, 1);
});

test('a host that never yields gives up, and says what it was told', async () => {
  const { fetcher, calls } = harness([], {
    fetchImpl: async () => status(429)(),
    maxAttempts: 4,
  });

  await assert.rejects(() => fetcher('https://upload.wikimedia.org/a.jpg'), /429/);
  assert.equal(calls.length, 0, 'the scripted counter is unused here');
});

test('a dropped connection is retried rather than counted as a bad picture', async () => {
  let n = 0;
  const { fetcher } = harness([], {
    fetchImpl: async () => {
      if (++n === 1) throw new Error('fetch failed');
      return ok();
    },
  });

  assert.deepEqual(await fetcher('https://upload.wikimedia.org/a.jpg'), bytes);
  assert.equal(n, 2);
});
