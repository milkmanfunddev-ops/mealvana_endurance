import type { CSSProperties, ReactNode } from 'react';

export interface GlassSurfaceProps {
  /**
   * Material variant (tokens.md §Materials):
   * `chrome` — the standard glass chain for floating chrome (blur 4 ·
   * saturate 1.8 · brighten 1.12; cream fill gradient, specular rim).
   * `dimmed` — the tab bar's own subdued chain (blur 12 · saturate 1.1 ·
   * blackberry 55% fill) for readability over busy content.
   * `sheet` — summoned surfaces (blur 18 · saturate 1.2 · blackberry 30%
   * veil, 24px top radius).
   */
  variant?: 'chrome' | 'dimmed' | 'sheet';
  /** Outer drop shadow for floating pills/buttons (0 8px 24px black 25%). */
  lift?: boolean;
  /** Corner radius; pill by default. Ignored by `sheet` (top corners fixed). */
  radius?: number | string;
  style?: CSSProperties;
  children?: ReactNode;
}

/**
 * A translucent-blur glass surface — the ONE material primitive for floating
 * chrome (home-shell@v1). Content behind stays recognizable through the
 * backdrop chain. Timeline/content cards NEVER take glass: solid fill +
 * hairline stays their treatment (§Materials boundary).
 */
export function GlassSurface({ variant = 'chrome', lift, radius, style, children }: GlassSurfaceProps) {
  const cls =
    variant === 'sheet' ? 'me-glass-sheet' : variant === 'dimmed' ? 'me-glass-dim' : 'me-glass';
  return (
    <div
      className={`${cls}${lift ? ' me-glass-lift' : ''}`}
      style={{
        borderRadius: variant === 'sheet' ? undefined : radius ?? 'var(--me-radius-pill)',
        overflow: variant === 'sheet' ? 'hidden' : undefined,
        ...style,
      }}
    >
      {children}
    </div>
  );
}
