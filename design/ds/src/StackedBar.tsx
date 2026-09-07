import type { CSSProperties } from 'react';
import { F, V } from './_shared';

export interface StackedBarSegment {
  value: number;
  /** `done` = filled electrolyte, `planned` = outlined, `remaining` = faint outline. */
  kind: 'done' | 'planned' | 'remaining';
  label?: string;
}

export interface StackedBarProps {
  segments: StackedBarSegment[];
  /** Total the widths are proportioned to; defaults to the sum. */
  total?: number;
  style?: CSSProperties;
}

/** Done / planned / remaining energy as three pill segments with an 8 px gap; labels below the ends. */
export function StackedBar({ segments, total, style }: StackedBarProps) {
  const sum = total ?? segments.reduce((a, s) => a + s.value, 0);
  const first = segments[0]; const last = segments[segments.length - 1];
  return (
    <div style={style}>
      <div style={{ display: 'flex', gap: 6, height: 22 }}>
        {segments.map((s, i) => (
          <div key={i} style={{ flex: `${Math.max(s.value, 0.0001)} 1 0`, borderRadius: 8, boxSizing: 'border-box',
            background: s.kind === 'done' ? V.electrolyte : 'transparent',
            border: s.kind === 'done' ? 'none' : `2px solid ${s.kind === 'planned' ? 'rgba(28,249,207,0.7)' : 'rgba(28,249,207,0.35)'}` }} />
        ))}
      </div>
      {(first?.label || last?.label) ? (
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 10, fontFamily: F.body, fontSize: 13 }}>
          <span style={{ color: V.electrolyte }}>{first?.label}</span>
          <span style={{ color: 'rgba(248,246,235,0.55)' }}>{last?.label}</span>
        </div>
      ) : null}
      <span style={{ display: 'none' }}>{sum}</span>
    </div>
  );
}
