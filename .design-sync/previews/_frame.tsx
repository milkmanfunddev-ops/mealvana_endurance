// Preview scaffolding: app-width column on the (dark-first) ground, and the light re-tint.
import type { ReactNode } from 'react';
export const Phone = ({ children, w = 396 }: { children: ReactNode; w?: number }) => (
  <div style={{ width: w, display: 'grid', gridTemplateColumns: 'minmax(0, 1fr)', gap: 12, padding: 16, background: 'var(--me-blackberry)', color: 'var(--me-cream)', borderRadius: 20, boxSizing: 'border-box' }}>{children}</div>
);
export const Light = ({ children, w = 396 }: { children: ReactNode; w?: number }) => (
  <div className="on-light" style={{ width: w, display: 'grid', gridTemplateColumns: 'minmax(0, 1fr)', gap: 12, padding: 16, borderRadius: 20, boxSizing: 'border-box' }}>{children}</div>
);
