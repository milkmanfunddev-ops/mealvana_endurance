import type { CSSProperties } from 'react';
import { DARK_DEFAULT, F, V, fg, resetBtn } from './_shared';

export interface ScreenHeaderProps {
  title: string;
  onBack?: () => void;
  dark?: boolean;
  style?: CSSProperties;
}

/** App screen chrome: 31.67 px filled back circle with a 10 px chevron, centred Sansita 17 title, hairline rule. */
export function ScreenHeader({ title, onBack, dark = DARK_DEFAULT, style }: ScreenHeaderProps) {
  const ink = fg(dark);
  const ground = dark ? V.blackberry : V.cream;
  return (
    <div
      style={{
        padding: '14px 17px',
        display: 'flex',
        alignItems: 'center',
        gap: 12,
        borderBottom: `1px solid ${dark ? 'rgba(248,246,235,0.1)' : V.hairline}`,
        ...style,
      }}
    >
      <button
        type="button"
        aria-label="Back"
        onClick={onBack}
        style={{ ...resetBtn, width: 31.67, height: 31.67, borderRadius: '50%', background: ink, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
      >
        <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke={ground} strokeWidth="2.6" strokeLinecap="square" strokeLinejoin="miter">
          <path d="M15 18l-6-6 6-6" />
        </svg>
      </button>
      <div style={{ flex: 1, textAlign: 'center', fontFamily: F.display, fontWeight: 700, fontSize: 17, lineHeight: 1.1, color: ink }}>{title}</div>
      <div style={{ width: 31.67 }} />
    </div>
  );
}
