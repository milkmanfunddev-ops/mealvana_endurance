/** US holiday calendar for Vana's week briefings — deterministic, no API.
 *  Federal holidays use their statutory rules (with Saturday→Friday / Sunday→Monday observed
 *  shifts); a handful of big cultural dates ride along because they change what people eat.
 *  The `holidays` table (public read) is the source of truth when it has rows for the window. */
import type { Db } from './env.ts';

export interface Holiday { date: string; name: string; federal: boolean }

const iso = (y: number, m: number, d: number) => new Date(Date.UTC(y, m - 1, d)).toISOString().slice(0, 10);
const dow = (isoStr: string) => new Date(isoStr + 'T00:00:00Z').getUTCDay(); // 0=Sun … 6=Sat
/** n-th <weekday> (0=Sun) of month m (1-12); n=-1 → last. */
function nthWeekday(y: number, m: number, weekday: number, n: number): string {
  if (n === -1) { const last = new Date(Date.UTC(y, m, 0)); const shift = (last.getUTCDay() - weekday + 7) % 7; return iso(y, m, last.getUTCDate() - shift); }
  const first = new Date(Date.UTC(y, m - 1, 1)).getUTCDay();
  return iso(y, m, 1 + ((weekday - first + 7) % 7) + (n - 1) * 7);
}
/** Western Easter (anonymous Gregorian algorithm) → ISO date. */
function easter(y: number): string {
  const a = y % 19, b = Math.floor(y / 100), c = y % 100, d = Math.floor(b / 4), e = b % 4;
  const f = Math.floor((b + 8) / 25), g = Math.floor((b - f + 1) / 3), h = (19 * a + b - d - g + 15) % 30;
  const i = Math.floor(c / 4), k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7;
  const mth = Math.floor((a + 11 * h + 22 * l) / 451), month = Math.floor((h + l - 7 * mth + 114) / 31), day = ((h + l - 7 * mth + 114) % 31) + 1;
  return iso(y, month, day);
}
const add = (isoStr: string, n: number) => new Date(new Date(isoStr + 'T00:00:00Z').getTime() + n * 86400_000).toISOString().slice(0, 10);

/** Federal dates get the observed-day shift (Sat→Fri, Sun→Mon); cultural dates don't. */
function federal(y: number, m: number, d: number, name: string): Holiday {
  let date = iso(y, m, d);
  const w = dow(date);
  if (w === 6) date = add(date, -1); else if (w === 0) date = add(date, 1);
  return { date, name, federal: true };
}
const fixed = (y: number, m: number, d: number, name: string): Holiday => ({ date: iso(y, m, d), name, federal: false });

export function usHolidays(year: number): Holiday[] {
  const e = easter(year);
  return [
    federal(year, 1, 1, "New Year's Day"),
    fixed(year, 2, 14, "Valentine's Day"),
    { date: nthWeekday(year, 1, 1, 3), name: 'MLK Day', federal: true },
    { date: nthWeekday(year, 2, 1, 3), name: "Presidents' Day", federal: true },
    fixed(year, 3, 17, "St. Patrick's Day"),
    { date: add(e, -2), name: 'Good Friday', federal: false },
    { date: e, name: 'Easter Sunday', federal: false },
    { date: nthWeekday(year, 5, 0, 2), name: "Mother's Day", federal: false },
    { date: nthWeekday(year, 5, 1, -1), name: 'Memorial Day', federal: true },
    { date: nthWeekday(year, 6, 0, 3), name: "Father's Day", federal: false },
    federal(year, 6, 19, 'Juneteenth'),
    federal(year, 7, 4, 'Independence Day'),
    { date: nthWeekday(year, 9, 1, 1), name: 'Labor Day', federal: true },
    { date: nthWeekday(year, 10, 1, 2), name: 'Columbus Day', federal: true },
    federal(year, 11, 11, 'Veterans Day'),
    fixed(year, 10, 31, 'Halloween'),
    { date: nthWeekday(year, 11, 4, 4), name: 'Thanksgiving', federal: true },
    federal(year, 12, 25, 'Christmas Day'),
    fixed(year, 12, 31, "New Year's Eve"),
  ].sort((a, b) => a.date.localeCompare(b.date));
}

const cache = new Map<number, Holiday[]>();
/** Holidays whose observed date falls in [startIso, endIso] inclusive (computed — also the DB fallback). */
export function holidaysBetween(startIso: string, endIso: string): Holiday[] {
  const years = new Set<number>();
  for (const y of [Number(startIso.slice(0, 4)), Number(endIso.slice(0, 4))]) years.add(y);
  const all = [...years].flatMap((y) => (cache.get(y) ?? (cache.set(y, usHolidays(y)), cache.get(y)!)));
  return all.filter((h) => h.date >= startIso && h.date <= endIso);
}

/** Source of truth: the `holidays` table (extendable per country_code). Falls back to the computed calendar when the
 *  table is empty/unreadable — e.g. dates beyond the seeded window. */
export async function holidaysInRange(db: Db, startIso: string, endIso: string): Promise<Holiday[]> {
  try {
    const { data, error } = await db.from('holidays').select('holiday_date, name, federal').eq('country_code', 'US').gte('holiday_date', startIso).lte('holiday_date', endIso).order('holiday_date');
    if (error) throw new Error(error.message);
    if (data && data.length) return data.map((r: { holiday_date: string; name: string; federal: boolean }) => ({ date: String(r.holiday_date), name: r.name, federal: !!r.federal }));
  } catch { /* fall through to computation */ }
  return holidaysBetween(startIso, endIso);
}
