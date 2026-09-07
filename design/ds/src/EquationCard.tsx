import type { CSSProperties } from 'react';
import { InfoIcon } from './InfoIcon';
import { F, V } from './_shared';

export interface EquationCardProps {
  eaten: number;
  burned: number;
  /** Eyebrow, default "Net energy balance". */
  label?: string;
  onInfo?: () => void;
  style?: CSSProperties;
}

const mono: CSSProperties = { fontFamily: F.mono, fontVariantNumeric: 'tabular-nums' };

/**
 * The energy-sheet hero: `1,107 eaten − 1,522 burned` on one line, then `= −415 kcal` in Sansita 64
 * orange. Eaten is orange (intake), burned is electrolyte (burn side) — the meaning contract.
 */
export function EquationCard({ eaten, burned, label = 'Net energy balance', onInfo, style }: EquationCardProps) {
  const net = eaten - burned;
  const netText = (net < 0 ? '−' : net > 0 ? '+' : '') + Math.abs(net).toLocaleString();
  return (
    <div style={{ borderRadius: 18, border: '1px solid rgba(248,246,235,0.18)', background: 'rgba(248,246,235,0.04)', padding: '20px 22px 22px', color: V.cream, ...style }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, fontFamily: F.body, fontWeight: 500, fontSize: 12, letterSpacing: '0.12em', textTransform: 'uppercase', color: 'rgba(248,246,235,0.55)' }}>
        {label} <InfoIcon label={label} onClick={onInfo} />
      </div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 10, marginTop: 16, fontSize: 16, flexWrap: 'wrap' }}>
        <span style={{ ...mono, fontSize: 22, color: V.orange }}>{eaten.toLocaleString()}</span><span style={{ fontFamily: F.body, color: 'rgba(248,246,235,0.55)' }}>eaten</span>
        <span style={{ fontFamily: F.body, color: 'rgba(248,246,235,0.55)', margin: '0 6px' }}>−</span>
        <span style={{ ...mono, fontSize: 22, color: V.electrolyte }}>{burned.toLocaleString()}</span><span style={{ fontFamily: F.body, color: 'rgba(248,246,235,0.55)' }}>burned</span>
      </div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 16, marginTop: 14 }}>
        <span style={{ fontFamily: F.body, fontSize: 22, color: 'rgba(248,246,235,0.5)' }}>=</span>
        <span style={{ fontFamily: F.display, fontWeight: 700, fontSize: 56, lineHeight: 1, color: V.orange, fontVariantNumeric: 'tabular-nums' }}>{netText}</span>
        <span style={{ fontFamily: F.display, fontWeight: 700, fontSize: 22, color: V.orange }}>kcal</span>
      </div>
    </div>
  );
}
