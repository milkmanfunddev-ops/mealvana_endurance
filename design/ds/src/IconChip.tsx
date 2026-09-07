import type { CSSProperties, ReactNode } from 'react';
import { V } from './_shared';

export interface IconChipProps {
  /** An `<Icon>` (Font Awesome glyph) — 20–24 px in a 56 px chip, 14–16 px in a 36 px chip. */
  children: ReactNode;
  /** Diameter: 56 (card marker, default) or 36 (rows, filters). */
  size?: number;
  /** Fill colour. Orange = food / intake, electrolyte = activity / burn (the rendering's contract). */
  color?: string;
  /** `filled` (default): solid circle, blackberry glyph. `outline`: 1.5 px ring in `color`, glyph in `color` — the filter-chip look. */
  variant?: 'filled' | 'outline';
  style?: CSSProperties;
}

/** The round icon marker used on every card and row. Food is an orange chip, activity an electrolyte chip. */
export function IconChip({ children, size = 56, color = V.electrolyte, variant = 'filled', style }: IconChipProps) {
  const filled = variant === 'filled';
  return (
    <div
      style={{
        width: size,
        height: size,
        borderRadius: '50%',
        background: filled ? color : 'transparent',
        border: filled ? 'none' : `1.5px solid ${color}`,
        color: filled ? V.blackberry : color,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        flex: '0 0 auto',
        ...style,
      }}
    >
      {children}
    </div>
  );
}
