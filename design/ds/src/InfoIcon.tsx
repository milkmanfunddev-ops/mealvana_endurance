import type { CSSProperties } from 'react';
import { resetBtn } from './_shared';

export interface InfoIconProps {
  /** Accessible label — what the explanation is about. */
  label: string;
  onClick?: () => void;
  size?: number;
  /** Ring colour; default muted cream. */
  color?: string;
  style?: CSSProperties;
}

/** The small outlined `i` that opens a number's explanation. Sits inline after a label. */
export function InfoIcon({ label, onClick, size = 20, color = 'rgba(248,246,235,0.45)', style }: InfoIconProps) {
  return (
    <button type="button" aria-label={`About ${label}`} onClick={onClick}
      style={{ ...resetBtn, width: size, height: size, borderRadius: '50%', border: `1.5px solid ${color}`, color, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', fontFamily: 'Georgia, serif', fontStyle: 'italic', fontSize: size * 0.62, lineHeight: 1, verticalAlign: 'middle', flex: '0 0 auto', ...style }}>
      i
    </button>
  );
}
