import type { CSSProperties } from 'react';
import { DARK_DEFAULT, F, V, fg2, line, resetBtn } from './_shared';

export interface SegmentedControlSegment<T extends string = string> {
  value: T;
  label: string;
}

export interface SegmentedControlProps<T extends string = string> {
  segments: SegmentedControlSegment<T>[];
  selected: T;
  onChange: (value: T) => void;
  /** Stretch segments to fill the container width. */
  full?: boolean;
  /** `md` (default) is the 12.5 px filter; `lg` is the sheet's big Daily / Weekly toggle (Apercu 500 20, 64 px tall). */
  size?: 'md' | 'lg';
  /** Selected fill: `cream` (default) or `orange` — the activity-details Planned / Actual toggle. */
  tone?: 'cream' | 'orange';
  dark?: boolean;
  style?: CSSProperties;
}

/**
 * Exclusive choice between 2–4 short options (All · Workout · Meals; Run · Bike · Swim).
 * A hairline pill track; the selected segment is a cream pill with blackberry text, the rest sit in
 * muted ink. Apercu 500 12.5 px — measured from the ratified rendering.
 */
export function SegmentedControl<T extends string = string>({ segments, selected, onChange, full, size = 'md', tone = 'cream', dark = DARK_DEFAULT, style }: SegmentedControlProps<T>) {
  const selFill = tone === 'orange' ? V.orange : dark ? V.cream : V.blackberry;
  const selInk = tone === 'orange' ? V.blackberry : dark ? V.blackberry : V.cream;
  const lg = size === 'lg';
  return (
    <div
      role="radiogroup"
      style={{
        display: full ? 'flex' : 'inline-flex',
        alignItems: 'center',
        gap: 2,
        padding: tone === 'orange' ? 0 : 4,
        border: tone === 'orange' ? 'none' : `1px solid ${line(dark)}`,
        background: lg && tone !== 'orange' ? 'rgba(248,246,235,0.06)' : 'transparent',
        borderRadius: 'var(--me-radius-pill)',
        ...style,
      }}
    >
      {segments.map((s) => {
        const on = s.value === selected;
        return (
          <button
            key={s.value}
            type="button"
            role="radio"
            aria-checked={on}
            onClick={() => onChange(s.value)}
            style={{
              ...resetBtn,
              flex: full ? 1 : undefined,
              padding: lg ? '20px 22px' : '12px 22px',
              borderRadius: 'var(--me-radius-pill)',
              background: on ? selFill : 'transparent',
              color: on ? selInk : fg2(dark),
              fontFamily: F.body,
              fontWeight: 500,
              fontSize: lg ? 20 : 12.5,
              lineHeight: 1,
              whiteSpace: 'nowrap',
              textAlign: 'center',
            }}
          >
            {s.label}
          </button>
        );
      })}
    </div>
  );
}
