import type { CSSProperties } from 'react';
import { DARK_DEFAULT, F, V, fg } from './_shared';

export interface MacroRingProps {
  /** Uppercase eyebrow ("Carbs", "Protein", "Fluids"). */
  label: string;
  value: number;
  target: number;
  unit: string;
  /** Bar colour. Macro encoding is not yet ratified (Q-SA3) — pass the token explicitly. */
  color: string;
  dark?: boolean;
  style?: CSSProperties;
}

/** One macro readout: `value/target unit` in Apercu Mono 22, eyebrow, 4 px progress bar. */
export function MacroRing({ label, value, target, unit, color, dark = DARK_DEFAULT, style }: MacroRingProps) {
  const pct = target > 0 ? Math.min(1, value / target) : 0;
  const ink = fg(dark);
  const track = dark ? 'rgba(248,246,235,0.12)' : 'rgba(56,22,51,0.08)';
  return (
    <div style={style}>
      <div style={{ fontFamily: F.mono, fontSize: 22, color: ink, fontVariantNumeric: 'tabular-nums', lineHeight: 1.1 }}>
        {value}<span style={{ color: V.inactive }}>/{target}{unit}</span>
      </div>
      <div style={{ fontFamily: F.body, fontWeight: 500, fontSize: 10, letterSpacing: '0.08em', textTransform: 'uppercase', color: V.inactive, marginTop: 4 }}>{label}</div>
      <div style={{ height: 4, marginTop: 6, background: track, borderRadius: 2, overflow: 'hidden' }}>
        <div style={{ height: '100%', width: `${pct * 100}%`, background: color }} />
      </div>
    </div>
  );
}
