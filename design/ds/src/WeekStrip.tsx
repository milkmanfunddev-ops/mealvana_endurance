import type { CSSProperties } from 'react';
import { F, V, resetBtn } from './_shared';

export interface WeekDay {
  /** Day-of-month number. */
  day: number;
  /** Single letter column head: S M T W T F S. */
  letter: string;
  /** Electrolyte dot under the number — the day has entries. */
  hasEntries?: boolean;
}

export interface WeekStripProps {
  days: WeekDay[];
  /** Index into `days`. */
  selected: number;
  onSelect?: (index: number) => void;
  style?: CSSProperties;
}

/**
 * The seven-day header strip. Day letters in muted Apercu 14, numbers in Compadre Wide 28 caps
 * with wide tracking; the selected day sits in a cream rounded square with blackberry ink;
 * an electrolyte dot marks days with entries. A hairline closes the strip.
 */
export function WeekStrip({ days, selected, onSelect, style }: WeekStripProps) {
  return (
    <div style={{ display: 'grid', gridTemplateColumns: `repeat(${days.length}, 1fr)`, justifyItems: 'center', rowGap: 14, paddingBottom: 18, borderBottom: '1px solid rgba(248,246,235,0.12)', ...style }}>
      {days.map((d) => <div key={'l' + d.letter + d.day} style={{ fontFamily: F.body, fontSize: 12, color: 'rgba(248,246,235,0.5)' }}>{d.letter}</div>)}
      {days.map((d, i) => {
        const on = i === selected;
        return (
          <button key={'n' + d.day} type="button" onClick={() => onSelect?.(i)} aria-pressed={on}
            style={{ ...resetBtn, display: 'grid', justifyItems: 'center', gap: 10 }}>
            <span style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', minWidth: 50, height: 44, padding: '0 6px', borderRadius: 15,
              background: on ? V.cream : 'transparent', color: on ? V.blackberry : V.cream,
              fontFamily: F.uiWide, fontSize: 24, lineHeight: 1, letterSpacing: '0.04em' }}>{d.day}</span>
            <span style={{ width: 8, height: 8, borderRadius: '50%', background: d.hasEntries ? V.electrolyte : 'transparent' }} />
          </button>
        );
      })}
    </div>
  );
}
