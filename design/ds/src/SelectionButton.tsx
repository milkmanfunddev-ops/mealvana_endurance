import type { CSSProperties, ReactNode } from 'react';
import { DARK_DEFAULT, F, bg, fg, resetBtn } from './_shared';

export interface SelectionButtonProps {
  label: string;
  isSelected: boolean;
  onTap: () => void;
  /** Optional icon above the label (sport pickers, goal pickers). */
  icon?: ReactNode;
  width?: number | string;
  height?: number | string;
  dark?: boolean;
  style?: CSSProperties;
}

/**
 * A selectable tile (onboarding sport/goal grids). 2 px border in the surface foreground —
 * 30 % alpha when unselected, filled + inverted label when selected. 15 px radius.
 */
export function SelectionButton({ label, isSelected, onTap, icon, width, height, dark = DARK_DEFAULT, style }: SelectionButtonProps) {
  const ink = fg(dark);
  const ground = bg(dark);
  const faint = dark ? 'rgba(248,246,235,0.3)' : 'rgba(56,22,51,0.3)';
  const faintText = dark ? 'rgba(248,246,235,0.5)' : 'rgba(56,22,51,0.5)';
  return (
    <button
      type="button"
      aria-pressed={isSelected}
      onClick={onTap}
      style={{
        ...resetBtn,
        width,
        height,
        padding: icon ? '12px 8px' : '16px 12px',
        border: `2px solid ${isSelected ? ink : faint}`,
        borderRadius: 'var(--me-radius-md)',
        background: isSelected ? ink : 'transparent',
        color: isSelected ? ground : faintText,
        display: 'inline-flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 4,
        fontFamily: F.body,
        fontWeight: 500,
        fontSize: 12,
        lineHeight: 1.3,
        ...style,
      }}
    >
      {icon ? <span style={{ display: 'inline-flex', width: 24, height: 24 }}>{icon}</span> : null}
      {label}
    </button>
  );
}
