import type { CSSProperties, ReactNode } from 'react';
import { DARK_DEFAULT, F, V } from './_shared';

export interface InputFieldProps {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  /** Trailing unit or hint rendered inside the field ("g", "min", "kg"). */
  suffix?: ReactNode;
  /** Numeric keyboard on mobile; also right-aligns the value with tabular figures. */
  numeric?: boolean;
  disabled?: boolean;
  dark?: boolean;
  /** Accessible name. */
  label?: string;
  style?: CSSProperties;
}

/**
 * 48 px text field, 12 px radius, no visible border. On dark surfaces the fill is the raised
 * input purple (`--me-input-bg`) with cream text; on cream it's cream-dark with blackberry text.
 */
export function InputField({ value, onChange, placeholder, suffix, numeric, disabled, dark = DARK_DEFAULT, label, style }: InputFieldProps) {
  const ink = dark ? V.cream : V.blackberry;
  return (
    <label
      style={{
        display: 'flex',
        alignItems: 'center',
        height: 'var(--me-input-height)',
        borderRadius: 'var(--me-radius-input)',
        background: dark ? V.inputBg : V.creamDark,
        padding: '0 16px',
        gap: 12,
        opacity: disabled ? 0.5 : 1,
        ...style,
      }}
    >
      <input
        aria-label={label}
        value={value}
        placeholder={placeholder}
        disabled={disabled}
        inputMode={numeric ? 'decimal' : undefined}
        onChange={(e) => onChange(e.target.value)}
        style={{
          flex: 1,
          minWidth: 0,
          border: 'none',
          outline: 'none',
          background: 'transparent',
          color: ink,
          fontFamily: F.body,
          fontSize: 16,
          lineHeight: 1.4,
          textAlign: numeric ? 'right' : 'left',
          fontVariantNumeric: numeric ? 'tabular-nums' : undefined,
        }}
      />
      {suffix ? (
        <span style={{ fontFamily: F.body, fontSize: 12, lineHeight: 1.5, color: ink, opacity: 0.4, whiteSpace: 'nowrap' }}>{suffix}</span>
      ) : null}
    </label>
  );
}
