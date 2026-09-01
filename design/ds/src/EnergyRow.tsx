import type { CSSProperties } from 'react';
import { Icon } from './Icon';
import type { IconName } from './Icon';
import { SourceDot } from './SourceDot';
import type { DataSource } from './SourceDot';
import { F, V, resetBtn } from './_shared';

export interface EnergyRowProps {
  /** Compadre Wide caps title. */
  title: string;
  /** "5:57 AM · 3 mi · 43 min". */
  detail: string;
  kcal: number;
  status: 'planned' | 'verified' | 'done';
  source: DataSource;
  /** Provenance line — "verified · Garmin · as planned", "planned (estimate)". */
  sourceLabel: string;
  sport?: 'run' | 'bike' | 'swim' | 'walk' | 'hike' | 'strength' | 'other';
  onClick?: () => void;
  style?: CSSProperties;
}

const sportIcon: Record<NonNullable<EnergyRowProps['sport']>, IconName> = {
  run: 'personRunning', bike: 'personBiking', swim: 'personSwimming', walk: 'personWalking', hike: 'personHiking', strength: 'dumbbell', other: 'personRunning',
};

/**
 * A workout in the Active Energy sheet: chip (filled when done, ringed when planned), title with a
 * `PLANNED` tag, detail, kcal + chevron at the trailing edge, and a provenance line under a hairline.
 */
export function EnergyRow({ title, detail, kcal, status, source, sourceLabel, sport = 'run', onClick, style }: EnergyRowProps) {
  const done = status !== 'planned';
  return (
    <button type="button" onClick={onClick} style={{ ...resetBtn, width: '100%', minWidth: 0, textAlign: 'left', borderRadius: 14, border: `1px solid ${done ? 'rgba(28,249,207,0.35)' : 'rgba(248,246,235,0.15)'}`, background: done ? 'rgba(28,249,207,0.05)' : 'rgba(248,246,235,0.03)', color: V.cream, padding: '14px 16px 0', boxSizing: 'border-box', ...style }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, paddingBottom: 12, borderBottom: '1px solid rgba(248,246,235,0.12)' }}>
        <span style={{ width: 52, height: 52, borderRadius: '50%', flex: '0 0 auto', display: 'flex', alignItems: 'center', justifyContent: 'center', background: done ? V.electrolyte : 'transparent', border: done ? 'none' : '2px solid rgba(28,249,207,0.5)', color: done ? V.blackberry : V.electrolyte }}>
          <Icon name={sportIcon[sport]} size={22} />
        </span>
        <span style={{ flex: 1, minWidth: 0 }}>
          <span style={{ display: 'flex', alignItems: 'center', gap: 10, minWidth: 0 }}>
            <span style={{ fontFamily: F.uiWide, fontSize: 19, letterSpacing: '0.06em', minWidth: 0, flex: '0 1 auto', textTransform: 'uppercase', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', color: done ? V.cream : 'rgba(248,246,235,0.7)' }}>{title}</span>
            {!done ? <span style={{ fontFamily: F.body, fontWeight: 500, fontSize: 10, letterSpacing: '0.12em', textTransform: 'uppercase', color: 'rgba(248,246,235,0.55)', border: '1px solid rgba(248,246,235,0.3)', borderRadius: 100, padding: '3px 9px', whiteSpace: 'nowrap' }}>Planned</span> : null}
          </span>
          <span style={{ display: 'block', fontFamily: F.body, fontSize: 13, color: 'rgba(248,246,235,0.5)', marginTop: 4 }}>{detail}</span>
        </span>
        <span style={{ display: 'inline-flex', alignItems: 'baseline', gap: 6, whiteSpace: 'nowrap', flex: '0 0 auto' }}>
          <span style={{ fontFamily: F.mono, fontSize: 20, color: done ? V.cream : 'rgba(248,246,235,0.55)', fontVariantNumeric: 'tabular-nums' }}>{kcal}</span>
          <span style={{ fontFamily: F.body, fontSize: 12, color: 'rgba(248,246,235,0.5)' }}>kcal</span>
          <Icon name="chevronRight" size={10} color="rgba(248,246,235,0.5)" />
        </span>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 0 14px', fontFamily: F.body, fontSize: 13, color: 'rgba(248,246,235,0.65)' }}>
        <SourceDot source={source} size={13} /> {sourceLabel}
      </div>
    </button>
  );
}
