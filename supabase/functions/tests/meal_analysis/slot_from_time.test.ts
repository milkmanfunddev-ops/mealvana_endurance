/**
 * mp-672: a logged meal's type comes from the time it was eaten; the model's food-based guess only breaks a tie within
 * 30 minutes of a boundary. No time on the request → the model's guess, else snack (mp-525).
 *
 * Run: deno test --allow-env --allow-read --allow-sys --node-modules-dir=none supabase/functions/tests/meal_analysis/slot_from_time.test.ts
 */
import { assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { minuteOfDay, slotForMeal } from '../../_shared/meal_analysis/slot_from_time.ts';
import { finalizeAnalysis } from '../../_shared/meal_analysis/finalize.ts';
import type { MealAnalysisRequest } from '../../_shared/meal_analysis/schema.ts';

Deno.test('minuteOfDay reads the wall clock of every form the app may send and ignores any offset', () => {
  assertEquals(minuteOfDay('2026-09-24T15:18'), 15 * 60 + 18);
  assertEquals(minuteOfDay('2026-09-24T15:18:42.123'), 15 * 60 + 18);
  assertEquals(minuteOfDay('2026-09-24 07:05:00'), 7 * 60 + 5);
  assertEquals(minuteOfDay('2026-09-24T21:40:00Z'), 21 * 60 + 40);
  assertEquals(minuteOfDay('2026-09-24T21:40:00-05:00'), 21 * 60 + 40);
  assertEquals(minuteOfDay('08:30'), 8 * 60 + 30);
  assertEquals(minuteOfDay('2026-09-24'), null);
  assertEquals(minuteOfDay('25:00'), null);
  assertEquals(minuteOfDay(''), null);
  assertEquals(minuteOfDay(1530), null);
  assertEquals(minuteOfDay(undefined), null);
});

Deno.test('the clock decides away from a boundary, whatever the food says (Finding 24-005)', () => {
  // Spaghetti bolognese at 3:18 PM came back as Dinner; the afternoon is not dinner.
  assertEquals(slotForMeal('2026-09-24T15:18', 'dinner'), 'snack');
  assertEquals(slotForMeal('2026-09-24T07:30', 'dinner'), 'breakfast');
  assertEquals(slotForMeal('2026-09-24T12:30', 'breakfast'), 'lunch');
  assertEquals(slotForMeal('2026-09-24T19:00', 'breakfast'), 'dinner');
  assertEquals(slotForMeal('2026-09-24T23:15', 'dinner'), 'snack');
  assertEquals(slotForMeal('2026-09-24T02:00', 'breakfast'), 'snack');
  assertEquals(slotForMeal('2026-09-24T12:30', undefined), 'lunch');
});

Deno.test('near a boundary the food breaks the tie between the two types that meet there', () => {
  // A bowl of oats at 11 AM stays breakfast (30 minutes past the 10:30 lunch boundary).
  assertEquals(slotForMeal('2026-09-24T11:00', 'breakfast'), 'breakfast');
  assertEquals(slotForMeal('2026-09-24T10:10', 'lunch'), 'lunch');
  assertEquals(slotForMeal('2026-09-24T16:45', 'dinner'), 'dinner');
  assertEquals(slotForMeal('2026-09-24T17:20', 'snack'), 'snack');
  assertEquals(slotForMeal('2026-09-24T14:45', 'lunch'), 'lunch');
  assertEquals(slotForMeal('2026-09-24T21:45', 'dinner'), 'dinner');
  // Across midnight's side: 03:45 is 15 minutes before breakfast opens.
  assertEquals(slotForMeal('2026-09-24T03:45', 'breakfast'), 'breakfast');
  assertEquals(slotForMeal('2026-09-24T04:10', 'snack'), 'snack');
});

Deno.test('near a boundary a guess that is neither side does not move the clock', () => {
  assertEquals(slotForMeal('2026-09-24T11:00', 'dinner'), 'lunch');
  assertEquals(slotForMeal('2026-09-24T11:00', 'snack'), 'lunch');
  assertEquals(slotForMeal('2026-09-24T17:10', 'breakfast'), 'dinner');
});

Deno.test('just outside the tie window the clock wins again', () => {
  assertEquals(slotForMeal('2026-09-24T11:01', 'breakfast'), 'lunch');
  assertEquals(slotForMeal('2026-09-24T16:29', 'dinner'), 'snack');
});

Deno.test('no usable time keeps the model guess, else snack', () => {
  assertEquals(slotForMeal(undefined, 'dinner'), 'dinner');
  assertEquals(slotForMeal('not a time', 'breakfast'), 'breakfast');
  assertEquals(slotForMeal(null, undefined), 'snack');
});

const pasta: MealAnalysisRequest = {
  name: 'Spaghetti bolognese',
  suggested_slot: 'dinner',
  confidence: 'high',
  items: [{ name: 'spaghetti bolognese', portion: '1 plate', calories: 780, carb_g: 95, protein_g: 35, fat_g: 24, sodium_mg: 900 }],
} as MealAnalysisRequest;

Deno.test('finalizeAnalysis takes the meal type from eaten_at when the request carries one', () => {
  const out = finalizeAnalysis(pasta, { eatenAt: '2026-09-24T15:18' });
  assertEquals(out.notFood, false);
  if (!out.notFood) assertEquals(out.analysis.suggested_slot, 'snack');
});

Deno.test('finalizeAnalysis without eaten_at keeps the model guess (older app builds)', () => {
  const out = finalizeAnalysis(pasta);
  if (!out.notFood) assertEquals(out.analysis.suggested_slot, 'dinner');
  const noGuess = finalizeAnalysis({ ...pasta, suggested_slot: undefined });
  if (!noGuess.notFood) assertEquals(noGuess.analysis.suggested_slot, 'snack');
});
