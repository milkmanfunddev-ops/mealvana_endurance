import type { CSSProperties } from 'react';
import { DARK_DEFAULT, V, resetBtn } from './_shared';

export interface SwitchProps {
  value: boolean;
  onChange: (value: boolean) => void;
  disabled?: boolean;
  dark?: boolean;
  /** Accessible name. */
  label?: string;
  style?: CSSProperties;
}

/** Toggle. Electrolyte track when on (the darker cut on cream), white thumb, no outline. 51×31. */
export function Switch({ value, onChange, disabled, dark = DARK_DEFAULT, label, style }: SwitchProps) {
  const onTrack = dark ? V.electrolyte : V.electrolyteDark;
  const offTrack = dark ? 'rgba(248,246,235,0.25)' : 'rgba(56,22,51,0.2)';
  return (
    <button
      type="button"
      role="switch"
      aria-checked={value}
      aria-label={label}
      disabled={disabled}
      onClick={() => onChange(!value)}
      style={{
        ...resetBtn,
        width: 51,
        height: 31,
        borderRadius: 31,
        background: value ? onTrack : offTrack,
        position: 'relative',
        transition: 'background var(--me-duration-fast) var(--me-ease-out)',
        opacity: disabled ? 0.5 : 1,
        cursor: disabled ? 'default' : 'pointer',
        flex: '0 0 auto',
        ...style,
      }}
    >
      <span
        style={{
          position: 'absolute',
          top: 2,
          left: value ? 22 : 2,
          width: 27,
          height: 27,
          borderRadius: '50%',
          background: disabled ? 'rgba(255,255,255,0.65)' : '#fff',
          boxShadow: 'var(--me-shadow-xs)',
          transition: 'left var(--me-duration-fast) var(--me-ease-out)',
        }}
      />
    </button>
  );
}
