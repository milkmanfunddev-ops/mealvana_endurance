import type { CSSProperties } from 'react';
import { DARK_DEFAULT, F, V, resetBtn } from './_shared';

export interface TripleActionProps {
  onBack?: () => void;
  onMore?: () => void;
  onAdd?: () => void;
  /** Render inline (for previews / non-absolute layouts) instead of pinned to the bottom. */
  inline?: boolean;
  style?: CSSProperties;
}

const pillBtn: CSSProperties = {
  ...resetBtn,
  color: V.cream,
  padding: '6px 14px',
  fontFamily: F.display,
  fontWeight: 700,
  fontSize: 13,
  borderRadius: 'var(--me-radius-pill)',
};

/** The floating Back • More • + pill (145×43, blackberry, orange plus). Bottom-centre of app screens. */
export function TripleAction({ onBack, onMore, onAdd, inline, style }: TripleActionProps) {
  return (
    <div
      style={{
        position: inline ? 'relative' : 'absolute',
        bottom: inline ? undefined : 24,
        left: 0,
        right: 0,
        display: 'flex',
        justifyContent: 'center',
        pointerEvents: 'none',
        ...style,
      }}
    >
      <div
        style={{
          pointerEvents: 'auto',
          background: V.blackberry,
          borderRadius: 'var(--me-radius-pill)',
          height: 43,
          display: 'flex',
          alignItems: 'center',
          padding: '4px 6px',
          gap: 2,
          boxShadow: 'var(--me-shadow-md)',
        }}
      >
        <button type="button" onClick={onBack} style={pillBtn}>Back</button>
        <button type="button" onClick={onMore} style={pillBtn}>More</button>
        <button
          type="button"
          aria-label="Add"
          onClick={onAdd}
          style={{ ...resetBtn, background: V.orange, width: 34, height: 34, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={V.blackberry} strokeWidth="2.6" strokeLinecap="square">
            <path d="M12 5v14M5 12h14" />
          </svg>
        </button>
      </div>
    </div>
  );
}
