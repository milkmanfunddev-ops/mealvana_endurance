import type { CSSProperties } from 'react';
import { Icon } from './Icon';
import { V, F, resetBtn } from './_shared';
import { GlassSurface } from './GlassSurface';

/** Dot slot: PLANNED = hollow orange ring; DONE = solid electrolyte dot. */
export type CalendarDotState = 'none' | 'planned' | 'done';

export interface CalendarDay {
  day: number;
  /** Workout channel for the day (best state wins: done beats planned). */
  dot?: CalendarDotState;
  /** Tint channel, BINARY v1: ≥1 athlete food log → the warm glow. */
  tinted?: boolean;
  isToday?: boolean;
  isSelected?: boolean;
}

export interface CalendarSheetProps {
  /** "September 2026" */
  monthLabel: string;
  /** Days 1..N in order; weekday of the 1st sets the leading offset. */
  days: CalendarDay[];
  /** 0 = the month starts on Sunday (grid is Sunday-first). */
  firstWeekday?: number;
  onPrevMonth?: () => void;
  onNextMonth?: () => void;
  onSelectDay?: (day: number) => void;
  onToday?: () => void;
  style?: CSSProperties;
}

const WEEKDAYS = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

/**
 * The summoned month calendar — `calendar-sheet.md` v1 (home-shell@v1), on the
 * glass-sheet material (blur 18 · saturate 1.2 · blackberry-30% veil; the
 * scrim behind it is `--me-scrim`). Each cell carries three independent
 * channels: the warm TINT (a day with athlete food logs), the workout DOT
 * (hollow `orange` ring = planned, solid `electrolyte` = done), and
 * today/selected (today = filled cream square; selected elsewhere = 2px cream
 * ring). Selecting a day navigates home AND dismisses (CS-4); the Today pill
 * selects today and keeps the sheet open (CS-6).
 */
export function CalendarSheet({ monthLabel, days, firstWeekday = 0, onPrevMonth, onNextMonth, onSelectDay, onToday, style }: CalendarSheetProps) {
  const circleBtn = (name: 'chevronLeft' | 'chevronRight', onClick?: () => void, label?: string) => (
    <button type="button" aria-label={label} onClick={onClick}
      style={{ ...resetBtn, width: 34, height: 34, borderRadius: '50%', border: '1px solid rgba(248,246,235,0.25)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: V.cream }}>
      <Icon name={name} size={12} />
    </button>
  );

  return (
    <GlassSurface variant="sheet" style={{ padding: '22px 18px 18px', color: V.cream, position: 'relative', ...style }}>
      <div aria-hidden style={{ position: 'absolute', top: 8, left: '50%', transform: 'translateX(-50%)', width: 36, height: 4, borderRadius: 2, background: 'rgba(248,246,235,0.28)' }} />
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 }}>
        <span style={{ fontFamily: F.display, fontWeight: 700, fontSize: 24, lineHeight: 1.1, display: 'inline-flex', alignItems: 'baseline', gap: 7 }}>
          {monthLabel}
          <Icon name="chevronDown" size={11} color="rgba(248,246,235,0.6)" />
        </span>
        <span style={{ display: 'inline-flex', gap: 10 }}>
          {circleBtn('chevronLeft', onPrevMonth, 'Previous month')}
          {circleBtn('chevronRight', onNextMonth, 'Next month')}
        </span>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', rowGap: 6 }}>
        {WEEKDAYS.map((w) => (
          <span key={w} style={{ fontFamily: F.body, fontWeight: 500, fontSize: 9.5, letterSpacing: '0.1em', color: 'rgba(248,246,235,0.45)', textAlign: 'center', paddingBottom: 6 }}>{w}</span>
        ))}
        {Array.from({ length: firstWeekday }, (_, i) => <span key={`b${i}`} />)}
        {days.map((d) => {
          const done = d.dot === 'done';
          const planned = d.dot === 'planned';
          return (
            <button key={d.day} type="button" aria-label={`Day ${d.day}`} onClick={() => onSelectDay?.(d.day)}
              style={{ ...resetBtn, height: 52, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'flex-start', gap: 4, paddingTop: 4 }}>
              <span style={{
                width: 32, height: 32, borderRadius: 9,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontFamily: F.body, fontSize: 13.5, fontVariantNumeric: 'tabular-nums',
                color: d.isToday ? V.blackberry : V.cream,
                background: d.isToday ? V.cream : d.tinted ? 'var(--me-cal-tint-fill)' : 'transparent',
                boxShadow: d.isSelected && !d.isToday
                  ? 'inset 0 0 0 2px var(--me-cream)'
                  : d.tinted && !d.isToday
                    ? 'inset 0 0 0 1px var(--me-cal-tint-ring)'
                    : undefined,
              }}>{d.day}</span>
              <span aria-hidden style={{
                width: done ? 6 : planned ? 8 : 6,
                height: done ? 6 : planned ? 8 : 6,
                borderRadius: '50%',
                background: done ? V.electrolyte : 'transparent',
                border: planned ? `2px solid ${V.orange}` : undefined,
                visibility: d.dot && d.dot !== 'none' ? 'visible' : 'hidden',
              }} />
            </button>
          );
        })}
      </div>
      <div style={{ marginTop: 22 }}>
        <button type="button" onClick={onToday}
          style={{ ...resetBtn, display: 'inline-flex', alignItems: 'center', gap: 8, padding: '9px 16px', borderRadius: 'var(--me-radius-pill)', background: 'rgba(248,246,235,0.08)', border: '1px solid rgba(248,246,235,0.14)', color: V.cream, fontFamily: F.body, fontSize: 12.5, fontWeight: 500 }}>
          <span aria-hidden style={{ width: 7, height: 7, borderRadius: '50%', border: '1.5px solid rgba(248,246,235,0.7)' }} />
          Today
        </button>
      </div>
    </GlassSurface>
  );
}
