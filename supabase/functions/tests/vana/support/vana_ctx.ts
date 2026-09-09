/** A VanaCtx backed by the fake database, plus offline stand-ins for the collaborators that
 *  would otherwise leave the process. Import this, not fake_db, from a test. */
import { FakeDb, fakeDb } from './fake_db.ts';
import type { Tables, FakeDbOptions } from './fake_db.ts';
import type { VanaCtx } from '../../../_shared/vana/env.ts';
import type { ContextDeps } from '../../../_shared/vana/context.ts';
import type { Memory } from '../../../_shared/vana/contracts.ts';

export const TEST_USER_ID = '11111111-1111-4111-8111-111111111111';

export interface TestCtx extends VanaCtx {
  fake: FakeDb;
}

/** The caller's client and the service-role client are the same fake — RLS is not what these
 *  tests are about, and a test that wants them apart can build two. */
export function testCtx(tables: Tables = {}, opts: FakeDbOptions = {}, userId = TEST_USER_ID): TestCtx {
  const fake = fakeDb(tables, opts);
  // deno-lint-ignore no-explicit-any
  const db = fake as any;
  return { db, admin: db, userId, token: 'test-token', fake };
}

/** Context deps that touch nothing: no macro fill, no weather, recall falls back to the list. */
export function offlineDeps(over: Partial<ContextDeps> = {}): ContextDeps {
  return {
    ensureWeekTargets: () => Promise.resolve(),
    weatherLine: () => Promise.resolve(null),
    recallMemories: () => Promise.resolve([] as Memory[]),
    ...over,
  };
}

/** A weather stand-in that answers one line per place, so a fixture race reads deterministically. */
export const fixedWeather = (byPlace: Record<string, string>) => (place: string | null) => Promise.resolve(place ? byPlace[place] ?? null : null);
