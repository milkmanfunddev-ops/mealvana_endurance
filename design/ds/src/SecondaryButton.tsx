import type { CSSProperties, ReactNode } from 'react';
import { DARK_DEFAULT, F, V, fg, fg2, line, resetBtn } from './_shared';

export interface SecondaryButtonProps {
  children: ReactNode;
  onClick?: () => void;
  full?: boolean;
  /** Leading glyph (use `<Icon name="plus" size={12} />`). */
  icon?: ReactNode;
  disabled?: boolean;
  /** `orange` — orange outline + orange label (the accent action). `neutral` — hairline outline, muted label (the quiet action). */
  tone?: 'orange' | 'neutral';
  /** `dashed` is the "+ Add Food / + Add Activity" affordance in the rendering. */
  outline?: 'solid' | 'dashed';
  /** `md` 56 px (form CTAs); `sm` 44 px (inline, the rendering's Add buttons). */
  size?: 'md' | 'sm';
  dark?: boolean;
  style?: CSSProperties;
}

/** Outlined pill on transparent. Golden rule 4 — also the ± stepper shape. */
export function SecondaryButton({ children, onClick, full, icon, disabled, tone = 'neutral', outline = 'solid', size = 'md', dark = DARK_DEFAULT, style }: SecondaryButtonProps) {
  const color = tone === 'orange' ? V.orange : fg(dark);
  const border = tone === 'orange' ? V.orange : line(dark);
  const label = tone === 'orange' ? V.orange : fg2(dark);
  const small = size === 'sm';
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      style={{
        ...resetBtn,
        background: 'transparent',
        color: small ? label : color,
        border: `${small ? 1 : 2}px ${outline} ${border}`,
        borderRadius: 'var(--me-radius-pill)',
        height: small ? 'var(--me-button-height-sm)' : 'var(--me-button-height)',
        padding: small ? '0 14px' : '0 24px',
        fontFamily: small ? F.body : F.display,
        fontWeight: small ? 500 : 700,
        fontSize: small ? 14 : 16,
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
      {icon ? <span style={{ display: 'inline-flex' }}>{icon}</span> : null}
      {children}
    </button>
  );
}
