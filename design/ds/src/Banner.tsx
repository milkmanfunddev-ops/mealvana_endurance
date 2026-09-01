import type { CSSProperties, ReactNode } from 'react';
import { Icon } from './Icon';
import type { IconName } from './Icon';
import { F, V, resetBtn } from './_shared';

export interface BannerProps {
  title: string;
  /** Muted second line — "3 honored · 1 skipped". */
  detail?: string;
  /** Leading glyph; default thumbtack (the pin-honoring banner). */
  icon?: IconName | ReactNode;
  /** Accent colour for border + glyph; default orange. */
  color?: string;
  /** Renders a chevron and makes the banner a button. */
  onExpand?: () => void;
  expanded?: boolean;
  style?: CSSProperties;
}

/** An outlined notice card with a leading glyph, bold title, muted detail, and an expand chevron. Orange by default. */
export function Banner({ title, detail, icon = 'thumbtack', color = V.orange, onExpand, expanded, style }: BannerProps) {
  const glyph = typeof icon === 'string' ? <Icon name={icon as IconName} size={22} /> : icon;
  return (
    <button type="button" onClick={onExpand} style={{ ...resetBtn, width: '100%', textAlign: 'left', display: 'flex', alignItems: 'center', gap: 16, padding: '16px 18px', borderRadius: 14, border: `1.5px solid ${color}`, background: 'rgba(248,246,235,0.04)', color: V.cream, boxSizing: 'border-box', cursor: onExpand ? 'pointer' : 'default', ...style }}>
      <span style={{ color, display: 'flex', flex: '0 0 auto' }}>{glyph}</span>
      <span style={{ flex: 1, minWidth: 0 }}>
        <span style={{ display: 'block', fontFamily: F.body, fontWeight: 700, fontSize: 18, lineHeight: 1.25 }}>{title}</span>
        {detail ? <span style={{ display: 'block', fontFamily: F.body, fontSize: 15, color: 'rgba(248,246,235,0.55)', marginTop: 4 }}>{detail}</span> : null}
      </span>
      {onExpand ? <Icon name={expanded ? 'chevronUp' : 'chevronDown'} size={14} color="rgba(248,246,235,0.7)" /> : null}
    </button>
  );
}
