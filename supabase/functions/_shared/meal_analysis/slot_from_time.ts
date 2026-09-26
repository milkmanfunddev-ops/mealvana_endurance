/**
 * A logged meal's type comes from the time it was eaten (mp-672, answer C).
 *
 * The clock picks the type from the windows below; the model's food-based
 * guess only breaks a tie within {@link TIE_MINUTES} of a boundary, and only
 * when it names one of the two types that meet there (a bowl of oats at 11 AM
 * stays breakfast; a 3 PM pasta stays in the afternoon). With no time on the
 * request the model's guess stands, as before (mp-525 makes a missing one a
 * snack).
 *
 * The windows are the app's own day, not a new one: the four-type logging
 * slots have no clock anywhere in the app, so they are drawn from the ruled
 * carb-loading grid (CL-5, `docs/ssot/spec/fueling/carb-loading.md`:
 * breakfast 6:00, lunch 12:00, dinner 18:00, last window closing 22:00) with
 * the snack slots between them folded to "snack", and with each main meal
 * given the hour or so either side an athlete actually eats it in.
 */

export type LoggedSlot = 'breakfast' | 'lunch' | 'dinner' | 'snack';

/** Minutes after midnight where each window starts, in order; the last wraps past midnight to the first. */
export const SLOT_WINDOWS: ReadonlyArray<{ startMin: number; slot: LoggedSlot }> = [
  { startMin: 4 * 60, slot: 'breakfast' }, // 04:00 – 10:30
  { startMin: 10 * 60 + 30, slot: 'lunch' }, // 10:30 – 14:30
  { startMin: 14 * 60 + 30, slot: 'snack' }, // 14:30 – 17:00
  { startMin: 17 * 60, slot: 'dinner' }, // 17:00 – 21:30
  { startMin: 21 * 60 + 30, slot: 'snack' }, // 21:30 – 04:00
];

/** How close to a boundary the food may decide instead of the clock. */
export const TIE_MINUTES = 30;

const DAY = 24 * 60;

/**
 * The wall-clock minute of a local-naive time the app sends: `HH:mm`,
 * `yyyy-MM-ddTHH:mm[:ss[.fff]]` or the same with a space. Any offset or `Z`
 * is ignored: the value is the athlete's own clock (like
 * `scheduled_date_time`), never converted. Null when it does not parse.
 */
export function minuteOfDay(eatenAt: unknown): number | null {
  if (typeof eatenAt !== 'string') return null;
  const m = /(?:^|[T ])(\d{1,2}):(\d{2})(?::\d{2}(?:\.\d+)?)?(?:Z|[+-]\d{2}:?\d{2})?$/.exec(eatenAt.trim());
  if (!m) return null;
  const h = Number(m[1]), min = Number(m[2]);
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
}

/** The window a minute falls in, and the windows either side of it. */
function windowAt(minute: number) {
  const n = SLOT_WINDOWS.length;
  let i = n - 1;
  for (let k = 0; k < n; k++) if (minute >= SLOT_WINDOWS[k].startMin) i = k;
  const start = SLOT_WINDOWS[i].startMin;
  const end = SLOT_WINDOWS[(i + 1) % n].startMin;
  const sinceStart = (minute - start + DAY) % DAY;
  const untilEnd = (end - minute + DAY) % DAY;
  return { slot: SLOT_WINDOWS[i].slot, prev: SLOT_WINDOWS[(i - 1 + n) % n].slot, next: SLOT_WINDOWS[(i + 1) % n].slot, sinceStart, untilEnd };
}

/**
 * The meal type for a meal eaten at [eatenAt], given the model's food-based
 * [modelGuess]. No parsable time → the model's guess, else snack.
 */
export function slotForMeal(eatenAt: unknown, modelGuess: LoggedSlot | null | undefined): LoggedSlot {
  const minute = minuteOfDay(eatenAt);
  if (minute == null) return modelGuess ?? 'snack';
  const w = windowAt(minute);
  if (modelGuess && modelGuess !== w.slot) {
    if (w.sinceStart <= TIE_MINUTES && modelGuess === w.prev) return modelGuess;
    if (w.untilEnd <= TIE_MINUTES && modelGuess === w.next) return modelGuess;
  }
  return w.slot;
}
