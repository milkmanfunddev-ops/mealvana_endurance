import type { CSSProperties } from 'react';
import { Icon } from './Icon';
import { V, F, resetBtn } from './_shared';

export interface DateHeaderProps {
  /** "Today, September 7" on today; the weekday form ("Tuesday, September 1") elsewhere. */
  title: string;
  onPrevDay?: () => void;
  onNextDay?: () => void;
  /** Tapping the title cluster summons the calendar sheet. */
  onSummonCalendar?: () => void;
  onSettings?: () => void;
  style?: CSSProperties;
}

/**
 * The home shell's date header — `date-header.md` v1 (home-shell@v1), REST
 * variant: ‹ title ˅ › day-stepping chevrons around the title cluster (the
 * cluster summons the calendar sheet), and the settings gear at the trailing
 * edge. Sits directly on the page ground; the content dissolve beneath it is
 * the page's top-fade (see `--me-top-fade`), not a bar.
 */
export function DateHeader({ title, onPrevDay, onNextDay, onSummonCalendar, onSettings, style }: DateHeaderProps) {
  const chev = (name: 'chevronLeft' | 'chevronRight', onClick?: () => void, label?: string) => (
    <button type="button" aria-label={label} onClick={onClick}
      style={{ ...resetBtn, width: 28, height: 32, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'rgba(248,246,235,0.75)' }}>
      <Icon name={name} size={13} />
    </button>
  );
  return (
    <div style={{ display: 'flex', alignItems: 'center', padding: '10px 10px 10px 4px', color: V.cream, ...style }}>
      <div style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'center' }}>
        {chev('chevronLeft', onPrevDay, 'Previous day')}
        <button type="button" aria-label={`${title} ˅`} onClick={onSummonCalendar}
          style={{ ...resetBtn, minWidth: 0, display: 'flex', alignItems: 'baseline', gap: 7 }}>
          <span style={{ fontFamily: F.display, fontWeight: 700, fontSize: 22, lineHeight: 1.15, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{title}</span>
          <Icon name="chevronDown" size={11} color="rgba(248,246,235,0.65)" />
        </button>
        {chev('chevronRight', onNextDay, 'Next day')}
      </div>
      <button type="button" aria-label="Settings" onClick={onSettings}
        style={{ ...resetBtn, width: 36, height: 36, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'rgba(248,246,235,0.8)' }}>
        <Icon name="gear" size={18} />
      </button>
    </div>
  );
}
