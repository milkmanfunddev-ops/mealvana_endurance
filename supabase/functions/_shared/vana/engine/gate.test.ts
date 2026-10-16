/** Box 1: the long workout code binds (E2, 2026-10-15): never today, the soonest 90+ min session, sport order only within a day. */
import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { longTarget, nextLong } from './gate.ts';
import { snapshot } from './fakes.ts';

const today = { id: 't', date: '2026-10-06', title: 'Long run today', type: 'run' as const, minutes: 120 };
const ride = { id: 'r', date: '2026-10-07', title: 'Long ride', type: 'ride' as const, minutes: 100 };
const satRun = { id: 's', date: '2026-10-10', title: 'Long run', type: 'run' as const, minutes: 150 };
const satRide = { id: 'sr', date: '2026-10-10', title: 'Long ride', type: 'ride' as const, minutes: 180 };

Deno.test('nextLong: never today; the soonest 90+ min session wins across days; run > ride > swim breaks a same-day tie only', () => {
  assertEquals(nextLong(snapshot({ workouts: [today] })), null);
  assertEquals(longTarget(snapshot({ workouts: [today] })), null);
  assertEquals(nextLong(snapshot({ workouts: [today, satRun, ride] }))?.id, 'r');          // tomorrow's ride beats Saturday's run
  assertEquals(nextLong(snapshot({ workouts: [satRide, satRun] }))?.id, 's');              // same day: the run
  assertEquals(nextLong(snapshot({ workouts: [satRide, { ...satRun, date: '2026-10-11' }] }))?.id, 'sr');   // a day apart: the sooner one
  // the in-app fallback (nothing 90+ ahead) starts tomorrow too
  const shortToday = { ...today, minutes: 80, source: 'calendar' as const };
  const shortSun = { id: 'c', date: '2026-10-11', title: 'Sunday run', type: 'run' as const, minutes: 80, source: 'calendar' as const };
  assertEquals(nextLong(snapshot({ workouts: [shortToday, shortSun] }))?.id, 'c');
});
