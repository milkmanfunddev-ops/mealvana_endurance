import type { CSSProperties } from 'react';
import { Icon } from './Icon';
import { F, V } from './_shared';

export type WorkoutStatus = 'planned' | 'verified' | 'skipped' | 'done';

export interface StatusPillProps {
  status: WorkoutStatus;
  /** Source for verified/done ("Garmin", "self-reported"). */
  source?: string;
  style?: CSSProperties;
}

/**
 * The small status pill on a workout card. Planned = electrolyte outline on a teal tint;
 * verified = dark-teal fill with a check + source; skipped = muted outline. Apercu 500 12.
 */
export function StatusPill({ status, source, style }: StatusPillProps) {
  const base: CSSProperties = {
    display: 'inline-flex', alignItems: 'center', gap: 3, padding: '3px 9px',
    borderRadius: 'var(--me-radius-pill)', fontFamily: F.body, fontWeight: 500, fontSize: 9.5, letterSpacing: 0.4, lineHeight: 1.2, whiteSpace: 'nowrap', ...style,
  };
  if (status === 'planned') return <span style={{ ...base, color: 'rgba(28,249,207,0.9)', border: '1px solid rgba(28,249,207,0.35)', background: 'rgba(28,249,207,0.1)' }}>Planned</span>;
  if (status === 'skipped') return <span style={{ ...base, color: 'rgba(248,246,235,0.6)', border: '1px solid rgba(248,246,235,0.22)', background: 'rgba(248,246,235,0.07)' }}>Skipped</span>;
  return (
    <span style={{ ...base, color: V.electrolyte, background: 'rgba(28,249,207,0.16)' }}>
      <Icon name="check" size={8} /> {status === 'verified' ? 'verified' : 'done'}{source ? ` · ${source}` : ''}
    </span>
  );
}
