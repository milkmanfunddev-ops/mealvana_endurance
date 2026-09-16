// Per-provider token buckets.
// Unsplash demo keys allow 50 req/hour and Pexels 200 req/hour; exceeding
// either gets the key throttled, so the budget is enforced here rather than
// discovered in production. Wikimedia/Openverse are unmetered but kept polite.
const BUDGET = {           // requests per hour
  unsplash: 45,
  pexels: 180,
  wikimedia: 6000,
  openverse: 2400,
};

const state = new Map();

export function budgetFor(p) { return BUDGET[p] ?? 600; }

export async function take(provider) {
  const perHour = budgetFor(provider);
  const minGap = 3600_000 / perHour;
  const now = Date.now();
  const next = Math.max(now, (state.get(provider) ?? 0) + minGap);
  state.set(provider, next);
  if (next > now) await new Promise((r) => setTimeout(r, next - now));
}
