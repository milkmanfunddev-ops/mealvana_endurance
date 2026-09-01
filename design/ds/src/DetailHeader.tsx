import type { CSSProperties } from 'react';
import { Icon } from './Icon';
import type { IconName } from './Icon';
import { F, V, resetBtn } from './_shared';

export interface DetailHeaderAction {
  icon: IconName;
  label: string;
  onClick?: () => void;
  /** `destructive` renders dragonfruit (delete). */
  tone?: 'default' | 'destructive';
}

export interface DetailHeaderProps {
  /** Sansita 26 title ("12 mi Run"). */
  title: string;
  onBack?: () => void;
  /** Trailing actions — typically edit (pen) and delete (trash, destructive). */
  actions?: DetailHeaderAction[];
  style?: CSSProperties;
}

/** Pushed-screen chrome: a translucent back circle with an arrow, the title beside it, action glyphs at the trailing edge. */
export function DetailHeader({ title, onBack, actions = [], style }: DetailHeaderProps) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 14, minWidth: 0, ...style }}>
      <button type="button" aria-label="Back" onClick={onBack} style={{ ...resetBtn, width: 44, height: 44, borderRadius: '50%', background: 'rgba(248,246,235,0.14)', color: V.cream, display: 'flex', alignItems: 'center', justifyContent: 'center', flex: '0 0 auto' }}>
        <Icon name="arrowLeft" size={18} />
      </button>
      <div style={{ flex: 1, minWidth: 0, fontFamily: F.display, fontWeight: 700, fontSize: 24, lineHeight: 1.1, color: V.cream, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{title}</div>
      {actions.map((a) => (
        <button key={a.label} type="button" aria-label={a.label} onClick={a.onClick} style={{ ...resetBtn, color: a.tone === 'destructive' ? V.dragonfruit : V.cream, display: 'flex', padding: 6 }}>
          <Icon name={a.icon} size={24} />
        </button>
      ))}
    </div>
  );
}
