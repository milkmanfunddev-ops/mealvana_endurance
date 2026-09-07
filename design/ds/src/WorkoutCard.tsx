import type { CSSProperties } from 'react';
import { Icon } from './Icon';
import type { IconName } from './Icon';
import { StatusPill } from './StatusPill';
import type { WorkoutStatus } from './StatusPill';
import { F, V, resetBtn } from './_shared';

export interface WorkoutCardProps {
  /** Compadre Wide caps, one line, ellipsized ("12 mi Run", "Drills Day"). */
  title: string;
  /** "3 mi · 43 min", "other". */
  detail: string;
  status: WorkoutStatus;
  source?: string;
  sport?: 'run' | 'bike' | 'swim' | 'walk' | 'hike' | 'strength' | 'other';
  /** Orange fuel line; omit to hide. Default "Pre · During · Recovery fuel >". */
  fuelLine?: string | null;
  /**
   * Static render of the swipe gesture mid-reveal (G1 done / G5 skip in the spec):
   * `done` shows the teal "✓ Mark done" panel on the left, `skip` the "⊘ Skip" panel on the right.
   */
  reveal?: 'none' | 'done' | 'skip';
  onClick?: () => void;
  style?: CSSProperties;
}

const sportIcon: Record<NonNullable<WorkoutCardProps['sport']>, IconName> = {
  run: 'personRunning', bike: 'personBiking', swim: 'personSwimming', walk: 'personWalking', hike: 'personHiking', strength: 'dumbbell', other: 'personRunning',
};

/**
 * The workout card on the fuel timeline, in its three states. Planned: dashed electrolyte border,
 * dashed-ring chip, `Planned` pill. Verified/done: electrolyte-tinted fill, filled chip, verified
 * pill. Skipped: dashed muted border, muted chip. The card only *emits* — a swipe changes the
 * whole dashboard (surface contract S-1).
 */
export function WorkoutCard({ title, detail, status, source = 'Garmin', sport = 'run', fuelLine = 'Pre · During · Recovery fuel >', reveal = 'none', onClick, style }: WorkoutCardProps) {
  const planned = status === 'planned';
  const skipped = status === 'skipped';
  const verified = status === 'verified' || status === 'done';
  // values from lib/features/macro_dashboard/presentation/widgets/workout_card.dart (MeTokens alphas)
  const border = planned ? '1.5px dashed rgba(28,249,207,0.55)' : skipped ? '1.5px dashed rgba(248,246,235,0.26)' : '1px solid rgba(28,249,207,0.3)';
  const fill = verified ? 'rgba(28,249,207,0.08)' : 'rgba(248,246,235,0.05)';
  const chipRing = planned ? '1.5px dashed rgba(28,249,207,0.6)' : skipped ? '1.5px dashed rgba(248,246,235,0.3)' : 'none';
  const ink = skipped ? 'rgba(248,246,235,0.55)' : V.cream;

  const card = (
    <div
      role={onClick ? 'button' : undefined}
      onClick={onClick}
      style={{
        display: 'flex', alignItems: 'center', gap: 12, padding: 14, minWidth: 0, width: '100%', boxSizing: 'border-box',
        borderRadius: 14, background: fill, border, color: ink, cursor: onClick ? 'pointer' : 'default',
        flex: '0 0 100%',
      }}
    >
      <div style={{ width: 40, height: 40, borderRadius: '50%', flex: '0 0 auto', display: 'flex', alignItems: 'center', justifyContent: 'center',
        background: verified ? V.electrolyte : 'transparent', border: chipRing, color: verified ? V.blackberry : skipped ? 'rgba(248,246,235,0.42)' : 'rgba(28,249,207,0.85)' }}>
        <Icon name={sportIcon[sport]} size={18} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, minWidth: 0 }}>
          <span style={{ fontFamily: F.uiWide, fontSize: 17, lineHeight: 1.1, letterSpacing: '0.06em', textTransform: 'uppercase', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', flex: '1 1 auto', minWidth: 0 }}>{title}</span>
          <StatusPill status={status} source={verified ? source : undefined} />
        </div>
        <div style={{ fontFamily: F.body, fontSize: 11, color: skipped ? 'rgba(248,246,235,0.4)' : 'rgba(248,246,235,0.55)', marginTop: 3 }}>{detail}</div>
        {fuelLine ? <div style={{ fontFamily: F.body, fontSize: 10.5, color: V.orange, marginTop: 5, opacity: skipped ? 0.5 : 1 }}>{fuelLine}</div> : null}
      </div>
    </div>
  );

  if (reveal === 'none') return <div style={{ minWidth: 0, ...style }}>{card}</div>;

  const panel = (kind: 'done' | 'skip') => (
    <button type="button" style={{ ...resetBtn, flex: '0 0 auto', width: kind === 'done' ? 260 : 210, display: 'flex', flexDirection: kind === 'done' ? 'row' : 'column', alignItems: 'center', justifyContent: 'center', gap: kind === 'done' ? 12 : 6,
      borderRadius: 14, background: kind === 'done' ? 'rgba(28,249,207,0.22)' : 'rgba(248,246,235,0.13)', color: kind === 'done' ? V.electrolyte : 'rgba(248,246,235,0.75)', fontFamily: F.body, fontWeight: 500, fontSize: 12.5 }}>
      <Icon name={kind === 'done' ? 'check' : 'xmark'} size={kind === 'done' ? 22 : 24} /> {kind === 'done' ? 'Mark done' : 'Skip'}
    </button>
  );
  // done: card pushed right, panel on the left. skip: card pushed left, panel on the right.
  return (
    <div style={{ display: 'flex', gap: 12, overflow: 'hidden', minWidth: 0, ...style }}>
      {reveal === 'done' ? panel('done') : null}
      <div style={{ flex: '0 0 100%', minWidth: 0, marginLeft: reveal === 'skip' ? -230 : 0 }}>{card}</div>
      {reveal === 'skip' ? panel('skip') : null}
    </div>
  );
}
