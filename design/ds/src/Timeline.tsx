import type { CSSProperties, ReactNode } from 'react';
import { F, V } from './_shared';

export type TimelineDot = 'done' | 'planned' | 'food' | 'skipped' | 'start';

export interface TimelineEntry {
  /** "5:57 AM"; omit for the rail head. */
  time?: string;
  dot: TimelineDot;
  /** The card (WorkoutCard, FoodRow) or an action row. */
  children: ReactNode;
}

export interface TimelineProps {
  entries: TimelineEntry[];
  style?: CSSProperties;
}

const dotStyle = (d: TimelineDot): CSSProperties => {
  const base: CSSProperties = { width: 14, height: 14, borderRadius: '50%', boxSizing: 'border-box', flex: '0 0 auto' };
  switch (d) {
    case 'done': return { ...base, background: V.electrolyte };
    case 'food': return { ...base, background: V.orange };
    case 'planned': return { ...base, border: '2px dashed rgba(28,249,207,0.8)' };
    case 'skipped': return { ...base, border: '2px dashed rgba(248,246,235,0.3)' };
    default: return { ...base, border: '2px solid rgba(248,246,235,0.35)' };
  }
};

/**
 * The day's rail: a 1 px line, a time label and a state dot per entry, cards to the right.
 * Dot colour is the entry's state — electrolyte done, dashed electrolyte planned, orange food,
 * dashed muted skipped. Each entry is 20 px apart; the rail runs the full height.
 */
export function Timeline({ entries, style }: TimelineProps) {
  return (
    <div style={{ position: 'relative', display: 'grid', gap: 20, ...style }}>
      <div aria-hidden style={{ position: 'absolute', left: 76, top: 8, bottom: 0, width: 1, background: 'rgb(79,49,73)' }} />
      {entries.map((e, i) => (
        <div key={i} style={{ display: 'grid', gridTemplateColumns: '64px 24px minmax(0, 1fr)', alignItems: 'start', columnGap: 4 }}>
          <div style={{ fontFamily: F.body, fontSize: 12, color: 'rgba(248,246,235,0.55)', textAlign: 'right', paddingTop: 6, whiteSpace: 'nowrap' }}>{e.time ?? ''}</div>
          <div style={{ display: 'flex', justifyContent: 'center', paddingTop: 6 }}><span style={dotStyle(e.dot)} /></div>
          <div style={{ minWidth: 0 }}>{e.children}</div>
        </div>
      ))}
    </div>
  );
}
