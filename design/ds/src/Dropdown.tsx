import type { CSSProperties } from 'react';
import { DARK_DEFAULT, F, V, fg } from './_shared';

export interface DropdownItem<T extends string = string> {
  value: T;
  label: string;
}

export interface DropdownProps<T extends string = string> {
  /** Descriptor above the field (Compadre 14). */
  label: string;
  value: T;
  items: DropdownItem<T>[];
  onChange: (value: T) => void;
  disabled?: boolean;
  dark?: boolean;
  style?: CSSProperties;
}

/** Labelled select. 2 px outlined box, 15 px radius, value in Apercu 14/600, chevron at the trailing edge. */
export function Dropdown<T extends string = string>({ label, value, items, onChange, disabled, dark = DARK_DEFAULT, style }: DropdownProps<T>) {
  const ink = fg(dark);
  return (
    <label style={{ display: 'flex', flexDirection: 'column', gap: 12, ...style }}>
      <span style={{ fontFamily: F.ui, fontSize: 14, lineHeight: 1.4, letterSpacing: 0.5, color: ink }}>{label}</span>
      <span style={{ position: 'relative', display: 'block' }}>
        <select
          value={value}
          disabled={disabled}
          onChange={(e) => onChange(e.target.value as T)}
          style={{
            width: '100%',
            appearance: 'none',
            WebkitAppearance: 'none',
            border: `2px solid ${ink}`,
            borderRadius: 'var(--me-radius-md)',
            background: dark ? 'rgba(56,22,51,0.3)' : V.cream,
            color: ink,
            padding: '12px 44px 12px 16px',
            fontFamily: F.body,
            fontSize: 14,
            fontWeight: 600,
            lineHeight: 1.2,
            opacity: disabled ? 0.5 : 1,
          }}
        >
          {items.map((i) => (
            <option key={i.value} value={i.value}>{i.label}</option>
          ))}
        </select>
        <svg
          aria-hidden
          width="14" height="14" viewBox="0 0 24 24" fill="none"
          stroke={ink} strokeWidth="2.6" strokeLinecap="square" strokeLinejoin="miter"
          style={{ position: 'absolute', right: 16, top: '50%', transform: 'translateY(-50%)', pointerEvents: 'none' }}
        >
          <path d="M6 9l6 6 6-6" />
        </svg>
      </span>
    </label>
  );
}
