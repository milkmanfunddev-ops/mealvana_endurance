import type { ReactNode } from 'react';

const styles: Record<string, React.CSSProperties> = {
  stage: {
    minHeight: '100vh',
    width: '100%',
    background: 'var(--me-bg-dark)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    padding: '32px 16px',
  },
  frame: {
    width: 390,
    height: 844,
    maxHeight: 'calc(100vh - 64px)',
    background: 'var(--me-bg-dark)',
    borderRadius: 44,
    border: '1px solid rgba(248, 246, 235, 0.12)',
    boxShadow: 'var(--me-shadow-lg)',
    overflow: 'hidden',
    display: 'flex',
    flexDirection: 'column',
    position: 'relative',
  },
  notch: {
    position: 'absolute',
    top: 12,
    left: '50%',
    transform: 'translateX(-50%)',
    width: 120,
    height: 28,
    background: '#000',
    borderRadius: 100,
    zIndex: 2,
  },
};

export function PhoneFrame({ children }: { children: ReactNode }) {
  return (
    <div style={styles.stage}>
      <div style={styles.frame}>
        <div style={styles.notch} aria-hidden />
        {children}
      </div>
    </div>
  );
}
