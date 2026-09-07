import type { CSSProperties } from 'react';
import { DARK_DEFAULT, F, V, resetBtn } from './_shared';

export type SnackbarType = 'success' | 'error' | 'warning' | 'info';

export interface SnackbarProps {
  message: string;
  type?: SnackbarType;
  /** Optional action label ("Undo", "Retry"). */
  actionLabel?: string;
  onAction?: () => void;
  style?: CSSProperties;
}

const palette: Record<SnackbarType, { bg: string; text: string; action: string }> = {
  success: { bg: V.electrolyte, text: V.blackberry, action: V.blackberry },
  error: { bg: V.dragonfruit, text: V.cream, action: V.cream },
  warning: { bg: V.orange, text: V.blackberry, action: V.blackberry },
  info: { bg: V.cream, text: V.blackberry, action: V.electrolyteDark },
};

/**
 * The app's only snackbar (MealvanaSnackbar in Flutter — raw SnackBar is banned). Floating,
 * 16 px radius, 1 px blackberry border, Apercu 16 message. Colour is the semantic token:
 * electrolyte success, dragonfruit error, orange warning, cream info.
 */
export function Snackbar({ message, type = 'info', actionLabel, onAction, style }: SnackbarProps) {
  const p = palette[type];
  return (
    <div
      role="status"
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 12,
        padding: 16,
        margin: '20px 16px',
        borderRadius: 'var(--me-radius-lg)',
        background: p.bg,
        color: p.text,
        border: `1px solid ${V.blackberry}`,
        fontFamily: F.body,
        fontSize: 16,
        lineHeight: 1.3,
        ...style,
      }}
    >
      <span style={{ flex: 1 }}>{message}</span>
      {actionLabel ? (
        <button type="button" onClick={onAction} style={{ ...resetBtn, color: p.action, fontFamily: F.display, fontWeight: 700, fontSize: 14, padding: '4px 8px' }}>
          {actionLabel}
        </button>
      ) : null}
    </div>
  );
}
