import type { CSSProperties } from 'react';
import { Icon } from './Icon';
import { DARK_DEFAULT, F, V, fg, resetBtn } from './_shared';

// Twin of lib/shared/widgets/kyle_design/fueling/fueling_window_control.dart —
// spec docs/ssot/spec/design/surfaces/create-flow-fueling-controls.md v1.
// The DEFAULT value it opens at is the owning controller's §3a derivation,
// never computed here.

export interface FuelingWindowControlProps {
  /** Sport-dynamic header (CF-5) — "Pre-Run Fueling Window". */
  label: string;
  /** Current window in minutes. */
  minutes: number;
  /** The ruled clamp `min(240, time-until-start)` (CF-1/CF-2), computed by the owning controller. */
  maxMinutes: number;
  onChanged?: (minutes: number) => void;
  /** Q-CF1 class caption ("3 h — long session") or CF-2 clamp explanation; hidden when absent. */
  caption?: string;
  dark?: boolean;
  style?: CSSProperties;
}

const STEP = 15;
const MIN = 0;

/** CF-1 label: `N HOUR[S] M MIN` (minutes-only below the hour). */
export function formatFuelingWindow(minutes: number): string {
  if (minutes === 0) return '0 MINUTES';
  if (minutes < 60) return `${minutes} MINUTES`;
  const hours = Math.floor(minutes / 60);
  const remaining = minutes % 60;
  const hourWord = hours === 1 ? 'HOUR' : 'HOURS';
  return remaining === 0 ? `${hours} ${hourWord}` : `${hours} ${hourWord} ${remaining} MIN`;
}

// CF-1 grid rule: an off-grid value snaps onto the 15-min grid on the first
// step; the off-grid ceiling stays reachable from below (it is the real one).
const snapDown = (m: number) => Math.max(MIN, Math.floor((m - 1) / STEP) * STEP);
const snapUp = (m: number, max: number) => Math.min(max, (Math.floor(m / STEP) + 1) * STEP);

/** The pre-workout window stepper: −/+ walk the 15-min grid between 0 and the ruled clamp; at the clamp the + disables (CF-2 — the athlete sees the real ceiling). Optional class/clamp caption beneath. */
export function FuelingWindowControl({ label, minutes, maxMinutes, onChanged, caption, dark = DARK_DEFAULT, style }: FuelingWindowControlProps) {
  const ink = fg(dark);
  const canDec = minutes > MIN;
  const canInc = minutes < maxMinutes;
  const stepBtn = (enabled: boolean, icon: 'minus' | 'plus', next: number) => (
    <button
      type="button"
      disabled={!enabled}
      onClick={enabled ? () => onChanged?.(next) : undefined}
      style={{ ...resetBtn, flex: '0 0 auto', width: 36, height: 36, borderRadius: 'var(--me-radius-pill)', border: `2px solid ${enabled ? V.orange : 'rgba(247,139,20,0.4)'}`, display: 'grid', placeItems: 'center', cursor: enabled ? 'pointer' : 'default' }}
    >
      <Icon name={icon} size={20} color={dark ? V.cream : V.orange} style={enabled ? undefined : { opacity: 0.4 }} />
    </button>
  );
  return (
    <div style={{ color: ink, ...style }}>
      <div style={{ fontFamily: F.ui, fontSize: 14, fontWeight: 700, lineHeight: 1.4, letterSpacing: '0.04em' }}>{label}</div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 24, marginTop: 12 }}>
        {stepBtn(canDec, 'minus', snapDown(minutes))}
        <span style={{ flex: 1, textAlign: 'center', fontFamily: F.body, fontWeight: 700, fontSize: 20, lineHeight: 1.2 }}>{formatFuelingWindow(minutes)}</span>
        {stepBtn(canInc, 'plus', snapUp(minutes, maxMinutes))}
      </div>
      {caption ? (
        <div style={{ textAlign: 'center', fontFamily: F.ui, fontSize: 14, lineHeight: 1.4, letterSpacing: '0.04em', opacity: 0.65, marginTop: 8 }}>{caption}</div>
      ) : null}
    </div>
  );
}
