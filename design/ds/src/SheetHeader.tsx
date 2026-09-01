import type { CSSProperties } from 'react';
import { Icon } from './Icon';
import { F, V, resetBtn } from './_shared';

export interface SheetHeaderProps {
  /** Sansita 26 title ("Today's Energy", "Active Energy", "Today's Fuel"). */
  title: string;
  /** Muted line under the title — "6:14 PM · 76% of the day done". */
  subtitle?: string;
  onClose?: () => void;
  style?: CSSProperties;
}

/** Top of every bottom sheet: a cream close circle at the leading edge, centred title, muted subtitle. */
export function SheetHeader({ title, subtitle, onClose, style }: SheetHeaderProps) {
  return (
    <div style={{ position: 'relative', textAlign: 'center', padding: '8px 52px 0', minHeight: 56, minWidth: 0, ...style }}>
      <button type="button" aria-label="Close" onClick={onClose}
        style={{ ...resetBtn, position: 'absolute', left: 0, top: 0, width: 48, height: 48, borderRadius: '50%', background: V.cream, color: V.blackberry, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <Icon name="xmark" size={16} />
      </button>
      <div style={{ fontFamily: F.display, fontWeight: 700, fontSize: 22, lineHeight: 1.1, color: V.cream, paddingTop: 10 }}>{title}</div>
      {subtitle ? <div style={{ fontFamily: F.body, fontSize: 14, color: 'rgba(248,246,235,0.5)', marginTop: 10 }}>{subtitle}</div> : null}
    </div>
  );
}
