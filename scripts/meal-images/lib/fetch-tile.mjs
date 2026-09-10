// Fetching the pictures a pass has to look at, at a pace the host will tolerate.
//
// Pass 8 has to download every tile of every meal before it can compose and
// judge it. On 2026-09-10 that meant asking upload.wikimedia.org for five
// pictures at a time, and it started returning 429 about thirty meals in. The
// pass treated that as "this meal is unfetchable", skipped it after three quick
// retries, and skipped 41 of the next 44 meals in a few seconds — a run that
// spent an hour and measured a fifth of the library.
//
// A 429 is not a broken picture. It is the host saying "slower", and the only
// correct response is to go slower — for that host, for the rest of the run.
//
//   * requests to one host are serialized behind a minimum gap;
//   * a 429 or 503 widens that host's gap and waits, honouring Retry-After;
//   * a success narrows it back, so one blip does not cripple the whole run;
//   * a 404 fails immediately, because no amount of waiting will produce it.
//
// Injectable clock and fetch, so all of that is testable without a network
// (`fetch-tile.test.mjs`).

const HOUR = 3_600_000;

export function createTileFetcher({
  fetchImpl = fetch,
  sleep = (ms) => new Promise((r) => setTimeout(r, ms)),
  minGapMs = 150,
  maxGapMs = 20_000,
  maxAttempts = 6,
  timeoutMs = 25_000,
  userAgent = 'MealvanaBot/1.0 (https://mealvana.com)',
} = {}) {
  /** Per host: the current gap, and when the next request may go out. */
  const hosts = new Map();
  const stateFor = (host) => {
    if (!hosts.has(host)) hosts.set(host, { gap: minGapMs, next: 0, chain: Promise.resolve() });
    return hosts.get(host);
  };

  /** Wait our turn at this host, then mark when the next turn is. */
  async function turn(state) {
    const now = Date.now();
    const at = Math.max(now, state.next);
    state.next = at + state.gap;
    if (at > now) await sleep(at - now);
  }

  return async function fetchTile(url) {
    const host = new URL(url).host;
    const state = stateFor(host);
    let last;

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      await turn(state);
      try {
        const res = await fetchImpl(url, {
          headers: { 'User-Agent': userAgent },
          signal: AbortSignal.timeout(timeoutMs),
        });
        if (res.ok) {
          // Recover slowly. A host that told us to slow down once will do it
          // again if we snap straight back to full speed.
          state.gap = Math.max(minGapMs, state.gap * 0.8);
          return new Uint8Array(await res.arrayBuffer());
        }
        if (res.status !== 429 && res.status !== 503) {
          throw new Error(`${host} -> ${res.status}`);
        }
        last = new Error(`${host} -> ${res.status}`);
        state.gap = Math.min(maxGapMs, Math.max(state.gap * 2, 1000));
        await sleep(retryAfterMs(res) ?? state.gap * attempt);
      } catch (e) {
        if (/-> \d\d\d$/.test(e.message) && !/-> (429|503)$/.test(e.message)) throw e;
        last = e;
        if (attempt < maxAttempts) await sleep(Math.min(maxGapMs, 1000 * 2 ** (attempt - 1)));
      }
    }
    throw last ?? new Error(`${host} -> gave up`);
  };
}

/** What the host asked for, in ms — seconds or an HTTP date, capped at an hour. */
function retryAfterMs(res) {
  const raw = res.headers?.get?.('retry-after');
  if (!raw) return null;
  const secs = Number(raw);
  const ms = Number.isFinite(secs) ? secs * 1000 : Date.parse(raw) - Date.now();
  return Number.isFinite(ms) && ms > 0 ? Math.min(ms, HOUR) : null;
}
