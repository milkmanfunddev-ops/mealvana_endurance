import type { CSSProperties } from 'react';
import { Icon } from './Icon';
import { F, V, resetBtn } from './_shared';

export interface NetBalanceCardProps {
  /** Signed kcal, e.g. -415. Rendered with a true minus sign. */
  value: number;
  /** Band copy from the spec — "slight deficit", "on track", "surplus". */
  status: string;
  /** Band tone. Default cream; the rendering uses electrolyte for "on track". */
  statusColor?: string;
  onExpand?: () => void;
  style?: CSSProperties;
}

/**
 * The dashboard's net-balance summary. Eyebrow `NET BALANCE`, the number in Sansita 40 orange
 * with `kcal` and the band copy inline, a chevron at the trailing edge that opens the energy sheet.
 */
export function NetBalanceCard({ value, status, statusColor = V.cream, onExpand, style }: NetBalanceCardProps) {
  const text = (value < 0 ? '−' : value > 0 ? '+' : '') + Math.abs(value).toLocaleString();
  return (
    <button type="button" onClick={onExpand} style={{ ...resetBtn, width: '100%', textAlign: 'left', display: 'flex', alignItems: 'center', gap: 12, padding: '18px 20px 16px 20px',
      borderRadius: 18, background: 'rgba(248,246,235,0.06)', border: '1px solid rgba(248,246,235,0.12)', color: V.cream, boxSizing: 'border-box', ...style }}>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontFamily: F.body, fontWeight: 500, fontSize: 11.5, letterSpacing: '0.12em', textTransform: 'uppercase', color: 'rgba(248,246,235,0.5)' }}>Net Balance</div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 10, marginTop: 6 }}>
          <span style={{ fontFamily: F.display, fontWeight: 700, fontSize: 27, lineHeight: 1, color: V.orange, fontVariantNumeric: 'tabular-nums' }}>{text}</span>
          <span style={{ fontFamily: F.body, fontSize: 11, color: 'rgba(248,246,235,0.5)' }}>kcal</span>
          <span style={{ fontFamily: F.body, fontWeight: 500, fontSize: 11, color: statusColor }}>{status}</span>
        </div>
      </div>
      <Icon name="chevronDown" size={16} color="rgba(248,246,235,0.7)" />
    </button>
  );
}
