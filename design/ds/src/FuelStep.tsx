import type { CSSProperties } from 'react';
import { Icon } from './Icon';
import { F, V, resetBtn } from './_shared';

export interface FuelStepStat { value: string; label: string }

export interface FuelStepProps {
  /** Orange Sansita title — "Pre-Workout Snack", "Top-Off". */
  title: string;
  /** Uppercase timing eyebrow — "Now – 30 min out". */
  timing: string;
  /** Suggested foods — "Orange Juice + Bread / Toast". */
  foods: string;
  /** Right-aligned stats — [{value:"50g",label:"Carbs"},{value:"8oz",label:"Fluids"}]. */
  stats?: FuelStepStat[];
  onClick?: () => void;
  style?: CSSProperties;
}

/** A timed fueling step inside a PhaseCard: chevron, orange title, timing eyebrow, foods line, stat pair. Raised blackberry-light fill. */
export function FuelStep({ title, timing, foods, stats = [], onClick, style }: FuelStepProps) {
  return (
    <button type="button" onClick={onClick} style={{ ...resetBtn, width: '100%', textAlign: 'left', display: 'flex', alignItems: 'center', gap: 14, padding: '16px 14px', borderRadius: 14, background: V.blackberryLight, border: '1px solid rgba(247,139,20,0.35)', color: V.cream, boxSizing: 'border-box', minWidth: 0, ...style }}>
      <Icon name="chevronRight" size={12} color={V.orange} />
      <span style={{ flex: 1, minWidth: 0 }}>
        <span style={{ display: 'block', fontFamily: F.display, fontWeight: 700, fontSize: 20, color: V.orange }}>{title}</span>
        <span style={{ display: 'block', fontFamily: F.body, fontWeight: 500, fontSize: 11, letterSpacing: '0.12em', textTransform: 'uppercase', color: 'rgba(248,246,235,0.55)', marginTop: 4 }}>{timing}</span>
        <span style={{ display: 'block', fontFamily: F.body, fontSize: 16, color: 'rgba(248,246,235,0.85)', marginTop: 6 }}>{foods}</span>
      </span>
      {stats.length ? (
        <span style={{ display: 'flex', gap: 18, flex: '0 0 auto' }}>
          {stats.map((s) => (
            <span key={s.label} style={{ display: 'grid', justifyItems: 'center', gap: 2 }}>
              <span style={{ fontFamily: F.display, fontWeight: 700, fontSize: 22, lineHeight: 1 }}>{s.value}</span>
              <span style={{ fontFamily: F.body, fontWeight: 500, fontSize: 10, letterSpacing: '0.1em', textTransform: 'uppercase', color: 'rgba(248,246,235,0.6)' }}>{s.label}</span>
            </span>
          ))}
        </span>
      ) : null}
    </button>
  );
}
