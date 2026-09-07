// Internal helpers shared by components. Lowercase filename: not a component export.
import type { CSSProperties } from 'react';

export const V = {
  blackberry: 'var(--me-blackberry)',
  blackberryLight: 'var(--me-blackberry-light)',
  cream: 'var(--me-cream)',
  creamDark: 'var(--me-cream-dark)',
  orange: 'var(--me-orange)',
  electrolyte: 'var(--me-electrolyte)',
  electrolyteDark: 'var(--me-electrolyte-dark)',
  dragonfruit: 'var(--me-dragonfruit)',
  yolk: 'var(--me-yolk)',
  inactive: 'var(--me-inactive)',
  hairline: 'var(--me-hairline)',
  inputBg: 'var(--me-input-bg)',
  // surface-relative (resolve through .on-light)
  bg: 'var(--me-bg)',
  ink: 'var(--me-ink)',
  ink2: 'var(--me-ink-2)',
  ink3: 'var(--me-ink-3)',
  ink4: 'var(--me-ink-4)',
  card: 'var(--me-card)',
  cardLine: 'var(--me-card-line)',
  cardRaised: 'var(--me-card-raised)',
  dataCarbs: 'var(--me-data-carbs)',
  dataProtein: 'var(--me-data-protein)',
  dataFat: 'var(--me-data-fat)',
} as const;

export const F = {
  display: 'var(--me-font-display)',
  ui: 'var(--me-font-ui)',
  uiWide: 'var(--me-font-ui-wide)',
  body: 'var(--me-font-body)',
  mono: 'var(--me-font-mono)',
} as const;

/** The app is dark-first: `dark` defaults to true everywhere. */
export const DARK_DEFAULT = true;
/** Foreground for the surface. */
export const fg = (dark: boolean = DARK_DEFAULT) => (dark ? V.cream : V.blackberry);
/** Ground for the surface. */
export const bg = (dark: boolean = DARK_DEFAULT) => (dark ? V.blackberry : V.cream);
/** Muted foreground for the surface. */
export const fg2 = (dark: boolean = DARK_DEFAULT) => (dark ? 'rgba(248,246,235,0.65)' : 'rgba(56,22,51,0.7)');
export const fg3 = (dark: boolean = DARK_DEFAULT) => (dark ? 'rgba(248,246,235,0.5)' : 'rgba(56,22,51,0.55)');
/** Hairline for the surface. */
export const line = (dark: boolean = DARK_DEFAULT) => (dark ? 'rgba(248,246,235,0.14)' : V.blackberry);
/** Card fill for the surface. */
export const cardFill = (dark: boolean = DARK_DEFAULT) => (dark ? 'rgba(248,246,235,0.06)' : V.cream);

export const resetBtn: CSSProperties = {
  border: 'none',
  background: 'transparent',
  padding: 0,
  margin: 0,
  cursor: 'pointer',
  font: 'inherit',
  color: 'inherit',
};
