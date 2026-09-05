import { useState, type CSSProperties, type ReactNode } from 'react';
import { Icon, type IconName } from './Icon';
import { F, V, resetBtn } from './_shared';

// Twin of lib/shared/widgets/kyle_design/fueling/feeding_card.dart —
// spec docs/ssot/spec/design/components/feeding-card.md v1. Food-row icons
// follow the phase-card visual parity ruling as amended (per-food colour disc
// + white glyph); the dashed "+ Add Food" pill stays as FC-7 specifies.

export interface FeedingFoodRow {
  id: string;
  name: string;
  /** Macros as an observation (FC-5) — "24g carbs · 8 oz". Empty → "nothing yet". */
  detail?: string;
  /** Electrolyte tag under the detail (Q-D8) — e.g. "ADDED FOR HYDRATION". */
  note?: string;
  quantity: number;
  step: number;
  cap: number;
  /** Parity ruling: the shared per-food glyph + disc colour, resolved by the surface. */
  icon: IconName;
  iconColor: string;
}

export interface FeedingCardProps {
  /** FC-1: arrives from the assembler; the card never invents one. */
  title: string;
  /** Uppercase window eyebrow — "60 – 15 MIN BEFORE". */
  windowLabel: string;
  /** Collapsed one-line foods summary; shown only while collapsed. */
  foodsLine?: string;
  /** FC-2: DELIVERED only — no aim, no window. */
  carbsDelivered: number;
  /** A fluid tier shows its oz next to carbs; null hides the figure. */
  fluidOz?: number | null;
  rows?: FeedingFoodRow[];
  /** FC-6: the hydration check, rendered as the first row (SNACK card, ≥ 2 h plans). */
  hydrationCheck?: ReactNode;
  /** FC-G2/G3: emits the row's new quantity (clamped to [0, cap]); the surface repaints the summary. */
  onStep?: (row: FeedingFoodRow, newQuantity: number) => void;
  /** FC-7: appends a row (expanded only). */
  onAddFood?: () => void;
  initiallyExpanded?: boolean;
  style?: CSSProperties;
}

const fmtQty = (q: number) => (q % 1 === 0 ? String(q) : q.toFixed(1));
const clamp = (q: number, cap: number) => Math.min(cap, Math.max(0, q));

/** One pre-workout feeding (meal · snack · top-off): orange Sansita title + window eyebrow + DELIVERED figures, expanding in place (FC-G1) to stepper food rows and the dashed "+ Add Food" pill. */
export function FeedingCard({ title, windowLabel, foodsLine, carbsDelivered, fluidOz = null, rows = [], hydrationCheck, onStep, onAddFood, initiallyExpanded = false, style }: FeedingCardProps) {
  const [expanded, setExpanded] = useState(initiallyExpanded);
  const figure = (value: string, label: string) => (
    <span style={{ display: 'grid', justifyItems: 'center', gap: 2, flex: '0 0 auto' }}>
      <span style={{ fontFamily: F.display, fontWeight: 700, fontSize: 16, lineHeight: 1, color: V.cream }}>{value}</span>
      <span style={{ fontFamily: F.body, fontSize: 8, letterSpacing: '0.08em', color: 'rgba(248,246,235,0.5)' }}>{label}</span>
    </span>
  );
  return (
    <div style={{ background: V.blackberryLight, borderRadius: 15, border: '1px solid rgba(247,139,20,0.25)', color: V.cream, boxSizing: 'border-box', ...style }}>
      {/* FC-G1: the header toggles in place, never navigates. */}
      <button type="button" onClick={() => setExpanded(!expanded)} style={{ ...resetBtn, width: '100%', textAlign: 'left', display: 'flex', alignItems: 'center', gap: 10, padding: 14, boxSizing: 'border-box' }}>
        <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke={V.orange} strokeWidth={2.5} strokeLinecap="round" strokeLinejoin="round" style={{ flex: '0 0 auto', transform: expanded ? 'none' : 'rotate(-90deg)', transition: 'transform 220ms' }}>
          <path d="M6 9l6 6 6-6" />
        </svg>
        <span style={{ flex: 1, minWidth: 0 }}>
          <span style={{ display: 'block', fontFamily: F.display, fontWeight: 700, fontSize: 17, lineHeight: 1.15, color: V.orange }}>{title}</span>
          <span style={{ display: 'block', fontFamily: F.body, fontSize: 9.5, letterSpacing: '0.12em', color: 'rgba(248,246,235,0.5)', marginTop: 4 }}>{windowLabel}</span>
          {!expanded && foodsLine ? (
            <span style={{ display: 'block', fontFamily: F.body, fontSize: 12, color: 'rgba(248,246,235,0.75)', marginTop: 5, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{foodsLine}</span>
          ) : null}
        </span>
        {figure(`${carbsDelivered}g`, 'CARBS')}
        {fluidOz != null ? figure(`${fluidOz}oz`, 'FLUIDS') : null}
      </button>
      {expanded && (
        <div style={{ borderTop: '1px solid rgba(247,139,20,0.25)', padding: '12px 14px 16px', display: 'grid', gap: 10 }}>
          {hydrationCheck}
          {rows.map((row) => (
            <div key={row.id} style={{ display: 'flex', alignItems: 'center', gap: 11, border: '1px solid rgba(247,139,20,0.45)', borderRadius: 12, padding: '10px 12px' }}>
              <span style={{ flex: '0 0 auto', width: 36, height: 36, borderRadius: '50%', background: row.iconColor, display: 'grid', placeItems: 'center' }}>
                <Icon name={row.icon} size={20} color="#fff" />
              </span>
              <span style={{ flex: 1, minWidth: 0 }}>
                {/* F-7: the name wraps to a second line — never lose a parenthetical to an ellipsis. */}
                <span style={{ display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden', fontFamily: F.display, fontWeight: 700, fontSize: 15, lineHeight: 1.2 }}>{row.name}</span>
                <span style={{ display: 'block', fontFamily: F.body, fontSize: 10.5, color: 'rgba(248,246,235,0.5)', marginTop: 2 }}>{row.detail || 'nothing yet'}</span>
                {row.note ? <span style={{ display: 'block', fontFamily: F.body, fontSize: 9, letterSpacing: '0.05em', color: V.electrolyte, marginTop: 2 }}>{row.note}</span> : null}
              </span>
              <button type="button" onClick={() => onStep?.(row, clamp(row.quantity - row.step, row.cap))} style={{ ...resetBtn, flex: '0 0 auto', width: 36, height: 36, borderRadius: '50%', border: `1px solid ${V.orange}`, display: 'grid', placeItems: 'center', fontFamily: F.body, fontSize: 20, lineHeight: 1, color: V.orange }}>−</button>
              <span style={{ minWidth: 28, textAlign: 'center', fontFamily: F.mono, fontSize: 15, fontVariantNumeric: 'tabular-nums', color: V.cream }}>{fmtQty(row.quantity)}</span>
              <button type="button" onClick={() => onStep?.(row, clamp(row.quantity + row.step, row.cap))} style={{ ...resetBtn, flex: '0 0 auto', width: 36, height: 36, borderRadius: '50%', border: `1px solid ${V.orange}`, display: 'grid', placeItems: 'center', fontFamily: F.body, fontSize: 20, lineHeight: 1, color: V.orange }}>+</button>
            </div>
          ))}
          <div style={{ display: 'flex', justifyContent: 'center', marginTop: 4 }}>
            <button type="button" onClick={onAddFood} style={{ ...resetBtn, height: 44, padding: '0 24px', borderRadius: 'var(--me-radius-pill)', border: `1px dashed ${V.orange}`, fontFamily: F.display, fontWeight: 700, fontSize: 14, color: V.orange }}>+ Add Food</button>
          </div>
        </div>
      )}
    </div>
  );
}
