import type { CSSProperties } from 'react';
import { DARK_DEFAULT, V } from './_shared';

// Twin of lib/shared/widgets/kyle_design/inputs/intensity_composite_bar.dart —
// spec docs/ssot/spec/design/surfaces/create-flow-fueling-controls.md,
// reference prototypes/create-activity-plan/v1.html.

export interface IntensityCompositeBarProps {
  /** Z1–Z2 percentage — the electrolyte segment. */
  conversationalPct: number;
  /** Z3–Z4 percentage — the orange segment. */
  tempoPct: number;
  /** Z5+ percentage — the dragonfruit segment. */
  allOutPct: number;
  height?: number;
  /** false dims the segments to 40%. */
  enabled?: boolean;
  dark?: boolean;
  style?: CSSProperties;
}

/** Slim (4 px) fully-rounded full-width intensity track: segment widths are the zone percentages, painted with the brand zone tokens (electrolyte conversational, orange tempo, dragonfruit all-out). */
export function IntensityCompositeBar({ conversationalPct, tempoPct, allOutPct, height = 4, enabled = true, dark = DARK_DEFAULT, style }: IntensityCompositeBarProps) {
  const seg = (pct: number, color: string) =>
    pct > 0 ? <span style={{ flex: pct, background: color, opacity: enabled ? 1 : 0.4 }} /> : null;
  return (
    <div
      role="img"
      aria-label={`Intensity distribution: ${conversationalPct}% conversational, ${tempoPct}% tempo, ${allOutPct}% all-out`}
      style={{ display: 'flex', width: '100%', height, borderRadius: height / 2, overflow: 'hidden', background: dark ? 'rgba(248,246,235,0.14)' : 'rgba(56,22,51,0.14)', ...style }}
    >
      {seg(conversationalPct, V.electrolyte)}
      {seg(tempoPct, V.orange)}
      {seg(allOutPct, V.dragonfruit)}
    </div>
  );
}
