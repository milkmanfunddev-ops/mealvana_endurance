import type { CSSProperties } from 'react';
import { F, V } from './_shared';

export interface MacroStatProps {
  /** Big figure with unit run together — "68g", "11oz", "378mg". */
  value: string;
  /** Uppercase label — "Carbs", "Fluids", "Sodium". */
  label: string;
  /** Figure colour; electrolyte for burn/verified figures, cream otherwise. */
  color?: string;
  /** Optional range rail: where the value sits between min and max, with end labels. */
  range?: { min: string; max: string; position: number };
  style?: CSSProperties;
}

/** A phase-card stat: Sansita 30 figure, uppercase label, and an optional range rail with a diamond marker. */
export function MacroStat({ value, label, color = V.cream, range, style }: MacroStatProps) {
  return (
    <div style={{ display: 'grid', justifyItems: 'center', gap: 6, color: V.cream, ...style }}>
      <span style={{ fontFamily: F.display, fontWeight: 700, fontSize: 30, lineHeight: 1, color, fontVariantNumeric: 'tabular-nums' }}>{value}</span>
      <span style={{ fontFamily: F.body, fontWeight: 500, fontSize: 12, letterSpacing: '0.1em', textTransform: 'uppercase', color: 'rgba(248,246,235,0.75)' }}>{label}</span>
      {range ? (
        <div style={{ width: '100%', marginTop: 8 }}>
          <div style={{ position: 'relative', height: 14 }}>
            <div style={{ position: 'absolute', left: 4, right: 4, top: 6, height: 2, background: 'rgba(248,246,235,0.3)' }} />
            <div style={{ position: 'absolute', left: 4, top: 2, width: 2, height: 10, background: 'rgba(248,246,235,0.3)' }} />
            <div style={{ position: 'absolute', right: 4, top: 2, width: 2, height: 10, background: 'rgba(248,246,235,0.3)' }} />
            <div style={{ position: 'absolute', left: `calc(4px + (100% - 8px) * ${Math.min(1, Math.max(0, range.position))})`, top: 1, width: 12, height: 12, transform: 'translateX(-50%) rotate(45deg)', background: V.electrolyte, borderRadius: 2 }} />
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', fontFamily: F.body, fontSize: 12, color: 'rgba(248,246,235,0.6)', marginTop: 4 }}><span>{range.min}</span><span>{range.max}</span></div>
        </div>
      ) : null}
    </div>
  );
}
