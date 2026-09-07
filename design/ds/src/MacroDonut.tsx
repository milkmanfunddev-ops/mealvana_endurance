import type { CSSProperties } from 'react';
import { F, V } from './_shared';

export interface MacroDonutProps {
  /** "Carbs", "Protein", "Fat". */
  label: string;
  value: number;
  target: number;
  unit?: string;
  /** Ring colour — the surface's data colour for this macro. */
  color: string;
  /** Planned-but-not-logged amount rendered as a dimmer arc after the logged one. */
  planned?: number;
  /** Line under the label — "70 g left". */
  caption?: string;
  size?: number;
  style?: CSSProperties;
}

/**
 * A macro progress ring: value in Sansita with a small coloured unit, "of target" beneath, the
 * logged arc in the macro colour and a dim planned arc after it. Carbs · Protein · Fat sit in a row.
 */
export function MacroDonut({ label, value, target, unit = 'g', color, planned = 0, caption, size = 200, style }: MacroDonutProps) {
  const r = 44; const c = 2 * Math.PI * r; const stroke = 9;
  const pct = target > 0 ? Math.min(1, value / target) : 0;
  const pPct = target > 0 ? Math.min(1 - pct, planned / target) : 0;
  return (
    <div style={{ display: 'grid', justifyItems: 'center', gap: 6, width: size, color: V.cream, ...style }}>
      <div style={{ position: 'relative', width: size, height: size }}>
        <svg width={size} height={size} viewBox="0 0 100 100" style={{ transform: 'rotate(-90deg)' }}>
          <circle cx="50" cy="50" r={r} fill="none" stroke="rgba(248,246,235,0.12)" strokeWidth={stroke} />
          {pPct > 0 ? <circle cx="50" cy="50" r={r} fill="none" stroke={color} strokeOpacity="0.35" strokeWidth={stroke} strokeDasharray={`${pPct * c} ${c}`} strokeDashoffset={-pct * c} strokeLinecap="round" /> : null}
          <circle cx="50" cy="50" r={r} fill="none" stroke={color} strokeWidth={stroke} strokeDasharray={`${pct * c} ${c}`} strokeLinecap="round" />
        </svg>
        <div style={{ position: 'absolute', inset: 0, display: 'grid', placeContent: 'center', textAlign: 'center' }}>
          <div style={{ fontFamily: F.display, fontWeight: 700, fontSize: size * 0.2, lineHeight: 1, fontVariantNumeric: 'tabular-nums' }}>{value}<span style={{ fontSize: size * 0.09, color }}>{unit}</span></div>
          <div style={{ fontFamily: F.body, fontSize: size * 0.085, color: 'rgba(248,246,235,0.5)', marginTop: 6 }}>of {target}</div>
        </div>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontFamily: F.body, fontWeight: 500, fontSize: 16, marginTop: 4 }}><span style={{ width: 10, height: 10, borderRadius: '50%', background: color }} /> {label}</div>
      {caption ? <div style={{ fontFamily: F.body, fontSize: 13, color: 'rgba(248,246,235,0.5)' }}>{caption}</div> : null}
    </div>
  );
}
