import type { CSSProperties, ReactNode } from 'react';
import { DARK_DEFAULT, F, V, resetBtn } from './_shared';

export interface PrimaryButtonProps {
  /** Label — Title Case, no exclamation marks ("Generate Plan", "Complete Workout"). */
  children: ReactNode;
  onClick?: () => void;
  /** Stretch to the container width (the common mobile placement). */
  full?: boolean;
  /** Leading 20 px icon. */
  icon?: ReactNode;
  disabled?: boolean;
  /** 44 px variant for inline placements; default is the 56 px primary height. */
  size?: 'md' | 'sm';
  style?: CSSProperties;
}

/**
 * The one filled orange pill per screen. Blackberry Sansita label, 100 px radius.
 * Golden rule 3: primary CTA once per screen — never two on one surface.
 */
export function PrimaryButton({ children, onClick, full, icon, disabled, size = 'md', style }: PrimaryButtonProps) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      style={{
        ...resetBtn,
        background: V.orange,
        color: V.blackberry,
        borderRadius: 'var(--me-radius-pill)',
        height: size === 'sm' ? 'var(--me-button-height-sm)' : 'var(--me-button-height)',
        padding: '0 24px',
        fontFamily: F.display,
        fontWeight: 700,
        fontSize: 16,
        lineHeight: 1.2,
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 8,
        width: full ? '100%' : 'auto',
        opacity: disabled ? 0.4 : 1,
        cursor: disabled ? 'default' : 'pointer',
        ...style,
      }}
    >
      {icon ? <span style={{ display: 'inline-flex', width: 20, height: 20 }}>{icon}</span> : null}
      {children}
    </button>
  );
}
