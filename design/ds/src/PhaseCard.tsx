import type { CSSProperties, ReactNode } from 'react';
import { Icon } from './Icon';
import type { IconName } from './Icon';
import { InfoIcon } from './InfoIcon';
import { F, V } from './_shared';

export type FuelPhase = 'before' | 'during' | 'after';

export interface PhaseCardProps {
  phase: FuelPhase;
  /** Override the title; defaults to the phase in caps. */
  title?: string;
  /** Optional glyph before the title (the `during` phase shows the runner). */
  icon?: IconName;
  onInfo?: () => void;
  /** The MacroStat trio, then the step sub-cards and item rows. */
  children: ReactNode;
  style?: CSSProperties;
}

const phaseColor: Record<FuelPhase, string> = { before: V.orange, during: V.electrolyte, after: V.dragonfruit };

/**
 * A fueling-phase section: outlined in the phase colour (orange before, electrolyte during,
 * dragonfruit after), Sansita caps title with a `?` info ring, then whatever the phase holds.
 */
export function PhaseCard({ phase, title, icon, onInfo, children, style }: PhaseCardProps) {
  const color = phaseColor[phase];
  return (
    <section style={{ borderRadius: 14, border: `1.5px solid ${color}`, background: 'rgba(248,246,235,0.03)', padding: '22px 18px 18px', color: V.cream, display: 'grid', gap: 22, ...style }}>
      <header style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 12, fontFamily: F.display, fontWeight: 700, fontSize: 22, letterSpacing: '0.05em', textTransform: 'uppercase', color }}>
          {icon ? <Icon name={icon} size={24} /> : null}{title ?? phase}
        </span>
        <InfoIcon label={`${phase} fueling`} onClick={onInfo} size={24} />
      </header>
      {children}
    </section>
  );
}
