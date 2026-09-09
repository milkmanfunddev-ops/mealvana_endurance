/**
 * Home location as a Fact: the HOME line, and today's weather answering for where the athlete
 * lives rather than for their next race venue.
 */
import { assert, assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { buildAthleteContext, contextBlock } from '../../_shared/vana/context.ts';
import { testCtx, offlineDeps, TEST_USER_ID } from './support/vana_ctx.ts';
import type { Tables } from './support/fake_db.ts';

const U = TEST_USER_ID;
const ANCHOR = '2026-09-09';

/** A weather stand-in that records which place it was asked about. */
function recordingWeather(lines: Record<string, string>) {
  const asked: (string | null)[] = [];
  return {
    asked,
    weatherLine: (place: string | null) => { asked.push(place); return Promise.resolve(place ? lines[place] ?? null : null); },
  };
}

const RACE = { user_id: U, event_name: 'Chattanooga 70.3', event_date: '2026-09-20', location: 'Chattanooga, TN', event_type: 'triathlon' };
const LINES = { 'Birmingham, Alabama': 'Birmingham, Alabama · 88°F, humid', 'Chattanooga, TN': 'Chattanooga, TN · 84°F' };

const build = async (users: Tables['users'], events: Tables['events'] = [RACE]) => {
  const w = recordingWeather(LINES);
  const v = testCtx({ users, events });
  const c = await buildAthleteContext(v, undefined, ANCHOR, offlineDeps({ weatherLine: w.weatherLine }));
  return { v, c, lines: contextBlock(c).split('\n'), asked: w.asked };
};
const line = (lines: string[], prefix: string) => lines.find((l) => l.startsWith(prefix)) ?? null;

const withHome = [{ id: U, first_name: 'Lee', allergies: [], home_city: 'Birmingham, Alabama', home_lat: 33.52, home_lon: -86.8, home_timezone: 'America/Chicago' }];
const withoutHome = [{ id: U, first_name: 'Lee', allergies: [], home_city: null, home_lat: null, home_lon: null, home_timezone: null }];

Deno.test('HOME line carries the town and its timezone when the athlete has told us', async () => {
  const { lines } = await build(withHome);
  assertEquals(line(lines, 'HOME'), 'HOME Birmingham, Alabama (America/Chicago)');
});

Deno.test('no home on file, no HOME line — the block does not invent one from the race', async () => {
  const { lines } = await build(withoutHome);
  assertEquals(line(lines, 'HOME'), null);
});

Deno.test("today's weather is where they live; the race venue is only the race-day line", async () => {
  const { lines, asked } = await build(withHome);
  assertEquals(line(lines, 'WEATHER'), 'WEATHER Birmingham, Alabama · 88°F, humid · race day Chattanooga, TN · 84°F');
  assert(asked.includes('Birmingham, Alabama'), 'today was asked about home');
  assert(asked.includes('Chattanooga, TN'), 'race day was asked about the venue');
});

Deno.test('with no home on file, today falls back to the race venue — the old behaviour', async () => {
  const { lines } = await build(withoutHome);
  assertEquals(line(lines, 'WEATHER'), 'WEATHER Chattanooga, TN · 84°F · race day Chattanooga, TN · 84°F');
});

Deno.test('home stands on its own with no race at all', async () => {
  const { lines } = await build(withHome, []);
  assertEquals(line(lines, 'HOME'), 'HOME Birmingham, Alabama (America/Chicago)');
  assertEquals(line(lines, 'WEATHER'), 'WEATHER Birmingham, Alabama · 88°F, humid');
  assertEquals(line(lines, 'RACE'), 'RACE none');
});

Deno.test('a home city with no coordinates yet still reads', async () => {
  const { lines, c } = await build([{ id: U, first_name: 'Lee', allergies: [], home_city: 'Birmingham, Alabama', home_lat: null, home_lon: null, home_timezone: null }]);
  assertEquals(line(lines, 'HOME'), 'HOME Birmingham, Alabama');
  assertEquals(c.home?.lat, null);
});
