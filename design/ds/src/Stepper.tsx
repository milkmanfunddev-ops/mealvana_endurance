import type { CSSProperties } from 'react';
import { DARK_DEFAULT, F, V, fg, resetBtn } from './_shared';

export interface StepperProps {
  value: number;
  onChange: (value: number) => void;
  min?: number;
  max?: number;
  step?: number;
  /** Unit rendered after the number with no space ("g", "ml"). */
  unit?: string;
  dark?: boolean;
  style?: CSSProperties;
}

/** ± control for macro targets: 36 px orange-outlined circles around a tabular Apercu Mono value. */
export function Stepper({ value, onChange, min = 0, max = 999, step = 1, unit = 'g', dark = DARK_DEFAULT, style }: StepperProps) {
  const ink = fg(dark);
  const btn: CSSProperties = {
    ...resetBtn,
    width: 36,
    height: 36,
    borderRadius: '50%',
    border: `1px solid ${V.orange}`,
    color: ink,
    fontSize: 20,
    lineHeight: 1,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontFamily: F.body,
    boxShadow: 'var(--me-shadow-xs)',
  };
  return (
    <div style={{ display: 'inline-flex', alignItems: 'center', gap: 14, ...style }}>
      <button type="button" aria-label="Decrease" style={btn} onClick={() => onChange(Math.max(min, value - step))}>−</button>
      <div style={{ minWidth: 80, textAlign: 'center', fontFamily: F.mono, fontSize: 20, fontVariantNumeric: 'tabular-nums', color: ink }}>
        {value}{unit}
      </div>
      <button type="button" aria-label="Increase" style={btn} onClick={() => onChange(Math.min(max, value + step))}>+</button>
    </div>
  );
}
