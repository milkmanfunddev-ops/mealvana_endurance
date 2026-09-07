import type { CSSProperties, ReactNode } from 'react';
import { DARK_DEFAULT, F, V, resetBtn } from './_shared';

export interface TertiaryButtonProps {
  children: ReactNode;
  onClick?: () => void;
  /** `dragonfruit` = remove / destructive (default in the app); `electrolyte` = add / positive. Golden rule 5. */
  tone?: 'dragonfruit' | 'electrolyte';
  icon?: ReactNode;
  underlined?: boolean;
  disabled?: boolean;
  style?: CSSProperties;
}

/** Text-only action. Apercu 14/500, 8 px radius hit area, 16 px leading icon. */
export function TertiaryButton({ children, onClick, tone = 'dragonfruit', icon, underlined, disabled, style }: TertiaryButtonProps) {
  const color = tone === 'electrolyte' ? V.electrolyteDark : V.dragonfruit;
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      style={{
        ...resetBtn,
        color,
        borderRadius: 'var(--me-radius-sm)',
        padding: '8px 12px',
        fontFamily: F.body,
        fontWeight: 500,
        fontSize: 14,
        lineHeight: 1.2,
        display: 'inline-flex',
        alignItems: 'center',
        gap: 8,
        textDecoration: underlined ? 'underline' : 'none',
        textUnderlineOffset: 3,
        opacity: disabled ? 0.4 : 1,
        cursor: disabled ? 'default' : 'pointer',
        ...style,
      }}
    >
      {icon ? <span style={{ display: 'inline-flex', width: 16, height: 16 }}>{icon}</span> : null}
      {children}
    </button>
  );
}
