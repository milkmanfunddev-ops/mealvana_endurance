import { CalendarSheet } from '@mealvana/endurance-ds';
import type { CalendarDay } from '@mealvana/endurance-ds';

// September: all three channels — warm tint (logged days), done dots, planned
// rings, today (filled) and a selected day (cream ring). Sheet floats over the
// page ground with the blackberry-60% scrim between them.
const days: CalendarDay[] = Array.from({ length: 30 }, (_, i) => {
  const day = i + 1;
  const d: CalendarDay = { day };
  if ([2, 3, 5, 6].includes(day)) { d.dot = 'done'; d.tinted = true; }
  if ([8, 10, 11, 13].includes(day)) d.dot = 'planned';
  if (day === 7) { d.isToday = true; d.dot = 'done'; d.tinted = true; }
  if (day === 15) d.isSelected = true;
  return d;
});

export const Month = () => (
  <div style={{ width: 396, borderRadius: 20, overflow: 'hidden', background: 'var(--me-blackberry)' }}>
    <div style={{ position: 'relative', padding: '28px 0 0' }}>
      <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(160deg, rgba(28,249,207,0.25), transparent 45%, rgba(247,139,20,0.3))' }} />
      <div style={{ position: 'absolute', inset: 0, background: 'var(--me-scrim)' }} />
      <CalendarSheet monthLabel="September 2026" days={days} firstWeekday={2} />
    </div>
  </div>
);
