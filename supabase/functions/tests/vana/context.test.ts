/** Port of the prototype's context.test.ts — week character + the deterministic plan math. */
import { assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { deriveWeekCharacter } from '../../_shared/vana/derive-week-character.ts';
import { coverageOf, defaultSession } from '../../_shared/vana/plan-math.ts';

const d = (n: number) => new Date(Date.now() + n * 86400_000).toISOString().slice(0, 10) + 'T07:00:00';

Deno.test('week character: flags race week from a title and picks the longest session as anchor', () => {
  const w = deriveWeekCharacter([{ scheduled_date_time: d(1), title: 'Easy run', activity_type: 'run', duration_minutes: 40, intensity_level: 'low' }, { scheduled_date_time: d(5), title: 'Ironman Florida', activity_type: 'triathlon', duration_minutes: 600, intensity_level: 'race' }]);
  assertEquals(w.isRaceWeek, true); assertEquals(w.weekCharacter, 'race week'); assertEquals(w.anchor?.title, 'Ironman Florida');
});

Deno.test('week character: scores load and rest days', () => {
  const w = deriveWeekCharacter([{ scheduled_date_time: d(1), title: 'Intervals', activity_type: 'run', duration_minutes: 60, intensity_level: 'high' }]);
  assertEquals(w.totalLoad, 180); assertEquals(w.restDays, 6); assertEquals(w.weekCharacter, 'easy / recovery');
});

const meal = (over: object) => ({ id: 'x', planId: 'p', source: 'library' as const, libraryMealId: 'D-001', savedMealId: null, name: 'n', mealType: 'dinner' as const, session: null, servings: 5, servingsLeft: 5, kcal: 650, carbsG: 90, proteinG: 45, fatG: 12, swapsApplied: [], comments: [], position: 0, ...over });

Deno.test('plan math: coverage caps at 14 lunch+dinner slots and averages per day', () => {
  const c = coverageOf([meal({}), meal({ servings: 4, kcal: 620, carbsG: 75, proteinG: 40 }), meal({ servings: 4, kcal: 700, carbsG: 95, proteinG: 36 }), meal({ servings: 1, kcal: 600, carbsG: 85, proteinG: 42 })]);
  assertEquals(c.covered, 14); assertEquals(c.perDay.carbsG, 174); assertEquals(c.perDay.kcal, 1304);
});

Deno.test('plan math: sessions — none when batch off; Sunday then Wednesday top-up; fresh Friday for non-batch meals', () => {
  assertEquals(defaultSession(false, { batch: true }, []), null);
  assertEquals(defaultSession(true, { batch: true }, []), 'cook-sun');
  assertEquals(defaultSession(true, { batch: true }, [meal({ session: 'cook-sun' }), meal({ session: 'cook-sun' })]), 'topup-wed');
  assertEquals(defaultSession(true, { batch: false }, []), 'fresh-fri');
});
