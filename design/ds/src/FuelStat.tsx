import type { CSSProperties } from 'react';
import { F, V } from './_shared';

// Twin of lib/shared/widgets/kyle_design/fueling/fuel_stat.dart —
// spec docs/ssot/spec/design/components/fuel-stat.md v1, figure typography per
// the phase-card visual parity ruling (surface pre-workout-before-card.md,
// 2026-09-01): dataNumber 16 px bold, not the rendering's Sansita 30 hero.

export type FuelQuantity = 'carbs' | 'fluids' | 'sodium';

export interface FuelStatProps {
  quantity: FuelQuantity;
  /** Whole units already (M-5): oz / g / mg — the assembler's job. */
  delivered: number;
  unit: string;
  /** Uppercase label — "CARBS", "FLUIDS", "SODIUM". */
  label: string;
  /** F-1: false renders no figure (the fluid gate); pair with absentLine. */
  showFigure?: boolean;
  /** F-1: "No fluid target for this session" — the gate, not a zero. */
  absentLine?: string;
  /** Band ends; both present (and a target, and not sodium — F-2) shows the band. */
  bandLow?: number;
  bandHigh?: number;
  /** The engine target — the suggested triangle (M-1). */
  target?: number;
  /** M-2/Q-D9: recolours only the delivered diamond to dragonfruit. */
  deliveredOutOfBand?: boolean;
  style?: CSSProperties;
}

const EASE = 'cubic-bezier(0.2, 0.8, 0.2, 1)';

const frac = (v: number, low: number, high: number) =>
  high > low ? Math.min(1, Math.max(0, (v - low) / (high - low))) : 0;

/** One summary quantity (carbs · fluids · sodium) with its optional band: delivered diamond (electrolyte, dragonfruit out-of-band) + suggested triangle (orange) on a cream rail. Three compose the BEFORE summary row. */
export function FuelStat({ quantity, delivered, unit, label, showFigure = true, absentLine, bandLow, bandHigh, target, deliveredOutOfBand = false, style }: FuelStatProps) {
  const isSodium = quantity === 'sodium';
  const showBand = !isSodium && bandLow != null && bandHigh != null && target != null;
  const endLabel: CSSProperties = { fontFamily: F.body, fontSize: 11, color: 'rgba(248,246,235,0.6)' };
  return (
    <div style={{ display: 'grid', justifyItems: 'center', color: V.cream, minWidth: 0, ...style }}>
      {showFigure && (
        <span style={{ fontFamily: F.body, fontWeight: 700, fontSize: 16, lineHeight: 1.2, color: isSodium ? 'rgba(248,246,235,0.8)' : V.electrolyte }}>
          {delivered}{unit}
        </span>
      )}
      <span style={{ fontFamily: F.body, fontSize: 11, letterSpacing: '0.1em', color: 'rgba(248,246,235,0.65)', marginTop: 6 }}>{label}</span>
      {absentLine && (
        <span style={{ fontFamily: F.body, fontSize: 11, lineHeight: 1.4, color: 'rgba(248,246,235,0.5)', marginTop: 8, textAlign: 'center' }}>{absentLine}</span>
      )}
      {showBand && (
        <div style={{ alignSelf: 'stretch', padding: '0 4px', marginTop: 14 }}>
          {/* Rail 3 px cream .45; suggested triangle 8×5 below; delivered diamond 9×9 above. */}
          <div style={{ position: 'relative', height: 3, borderRadius: 2, background: 'rgba(248,246,235,0.45)' }}>
            <span style={{ position: 'absolute', left: `calc(${(frac(target!, bandLow!, bandHigh!) * 100).toFixed(2)}% - 4px)`, top: 8, width: 0, height: 0, borderLeft: '4px solid transparent', borderRight: '4px solid transparent', borderBottom: `5px solid ${V.orange}`, transition: `left 220ms ${EASE}` }} />
            <span style={{ position: 'absolute', left: `calc(${(frac(delivered, bandLow!, bandHigh!) * 100).toFixed(2)}% - 4.5px)`, top: -3, width: 9, height: 9, transform: 'rotate(45deg)', background: deliveredOutOfBand ? V.dragonfruit : V.electrolyte, transition: `left 220ms ${EASE}, background 220ms ${EASE}` }} />
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 12 }}>
            <span style={endLabel}>{bandLow}{unit}</span>
            <span style={endLabel}>{bandHigh}{unit}</span>
          </div>
        </div>
      )}
    </div>
  );
}
