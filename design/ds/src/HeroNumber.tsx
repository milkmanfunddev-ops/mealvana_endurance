import type { CSSProperties, ReactNode } from 'react';
import { F, V } from './_shared';

export interface HeroNumberProps {
  /** Electrolyte eyebrow — "Done so far". */
  label: string;
  value: string;
  unit?: string;
  /** Line beneath, e.g. "+519 planned → 930 projected" (use `<b>` for the electrolyte figure). */
  caption?: ReactNode;
  /** Eyebrow colour; default electrolyte (burn side). */
  color?: string;
  align?: 'left' | 'center';
  style?: CSSProperties;
}

/** The sheet's hero figure: Sansita 96 number with a 30 px unit, coloured eyebrow above, caption below. */
export function HeroNumber({ label, value, unit, caption, color = V.electrolyte, align = 'left', style }: HeroNumberProps) {
  return (
    <div style={{ textAlign: align, color: V.cream, ...style }}>
      <div style={{ fontFamily: F.body, fontWeight: 500, fontSize: 13, letterSpacing: '0.14em', textTransform: 'uppercase', color }}>{label}</div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 14, justifyContent: align === 'center' ? 'center' : 'flex-start', marginTop: 10 }}>
        <span style={{ fontFamily: F.display, fontWeight: 700, fontSize: 72, lineHeight: 1, letterSpacing: '-0.01em', fontVariantNumeric: 'tabular-nums' }}>{value}</span>
        {unit ? <span style={{ fontFamily: F.display, fontWeight: 700, fontSize: 24, color: 'rgba(248,246,235,0.6)' }}>{unit}</span> : null}
      </div>
      {caption ? <div style={{ fontFamily: F.body, fontSize: 15, color: 'rgba(248,246,235,0.55)', marginTop: 10 }}>{caption}</div> : null}
    </div>
  );
}
