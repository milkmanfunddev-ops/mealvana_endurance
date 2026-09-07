import type { CSSProperties, ReactNode } from 'react';
import { DARK_DEFAULT, F, cardFill, fg, fg3, line } from './_shared';

export interface CardProps {
  children: ReactNode;
  /** Sansita 19 title; renders a titled card when set. */
  title?: string;
  /** Uppercase Apercu eyebrow under the title ("3 HOURS BEFORE"). */
  subtitle?: string;
  /** Hairline border. On dark it's the faint cream line; on light, blackberry. Default true. */
  outlined?: boolean;
  /** Accent the border (the rendering's "verified" card uses electrolyte). */
  accent?: string;
  padding?: number | string;
  /** The app is dark-first; pass `false` inside an `.on-light` subtree. */
  dark?: boolean;
  style?: CSSProperties;
}

/**
 * The base surface. 15 px radius (ratified), 16 px padding. On the blackberry ground a card is a
 * faint cream-tinted fill with a hairline — never a solid box; on cream it's cream with a 1 px
 * blackberry outline. No gradients, no drop shadows.
 */
export function Card({ children, title, subtitle, outlined = true, accent, padding = 16, dark = DARK_DEFAULT, style }: CardProps) {
  return (
    <section
      style={{
        borderRadius: 'var(--me-radius-md)',
        background: cardFill(dark),
        border: outlined ? `1px solid ${accent ?? line(dark)}` : 'none',
        padding,
        color: fg(dark),
        ...style,
      }}
    >
      {title ? (
        <header style={{ marginBottom: 12 }}>
          <div style={{ fontFamily: F.display, fontWeight: 700, fontSize: 19, lineHeight: 1.15 }}>{title}</div>
          {subtitle ? (
            <div style={{ fontFamily: F.body, fontWeight: 500, fontSize: 9.5, letterSpacing: '0.12em', textTransform: 'uppercase', color: fg3(dark), marginTop: 6 }}>{subtitle}</div>
          ) : null}
        </header>
      ) : null}
      {children}
    </section>
  );
}
