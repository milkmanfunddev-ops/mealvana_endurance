import type { CSSProperties } from 'react';
import { Icon } from './Icon';
import type { IconName } from './Icon';
import { IconChip } from './IconChip';
import { F, V, resetBtn } from './_shared';

export interface FuelItemProps {
  /** "1.5 servings Enervit Carbo Gel C2:1 Mango", "4.5 cups Water". */
  text: string;
  /** Glyph in the electrolyte chip — droplet (gel), bottle-like (drink), bag (salt). */
  icon?: IconName;
  expanded?: boolean;
  onToggle?: () => void;
  style?: CSSProperties;
}

/** An expandable fueling item row: 56 px electrolyte chip, bold Apercu text (wraps to two lines), chevron. Raised fill. */
export function FuelItem({ text, icon = 'droplet', expanded, onToggle, style }: FuelItemProps) {
  return (
    <button type="button" aria-expanded={expanded} onClick={onToggle} style={{ ...resetBtn, width: '100%', textAlign: 'left', display: 'flex', alignItems: 'center', gap: 16, padding: '12px 16px 12px 12px', borderRadius: 14, background: V.blackberryLight, border: '1px solid rgba(248,246,235,0.08)', color: V.cream, boxSizing: 'border-box', minWidth: 0, ...style }}>
      <IconChip size={52}><Icon name={icon} size={22} /></IconChip>
      <span style={{ flex: 1, minWidth: 0, fontFamily: F.body, fontWeight: 700, fontSize: 18, lineHeight: 1.3 }}>{text}</span>
      <Icon name={expanded ? 'chevronUp' : 'chevronDown'} size={16} color="rgba(248,246,235,0.75)" />
    </button>
  );
}
