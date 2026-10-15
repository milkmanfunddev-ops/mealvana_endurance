/** Date helpers the engine shares. Vana never works a weekday out; these do, in code, once. */
import type { Weekday } from './types.ts';

const DAYS: Weekday[] = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

export const weekdayOf = (iso: string): Weekday => DAYS[new Date(`${iso}T12:00:00Z`).getUTCDay()];
export const addDays = (iso: string, n: number): string => new Date(Date.parse(`${iso}T12:00:00Z`) + n * 86400e3).toISOString().slice(0, 10);
/** "Saturday, Oct 10" */
export const fmtDate = (iso: string): string => { const d = new Date(`${iso}T12:00:00Z`); return `${weekdayOf(iso)}, ${MONTHS[d.getUTCMonth()]} ${d.getUTCDate()}`; };
/** `getDurationBracket` in the app's during-template solver. */
export const bracketOf = (m: number): string => (m < 90 ? '< 90 min' : m <= 150 ? '90-150 min' : m <= 240 ? '150-240 min' : '> 240 min');
/** The 3-letter stem a weekday regex matches on ("satur" for Saturday). */
export const dayStem = (d: Weekday): string => d.toLowerCase().replace(/day$/, '');
