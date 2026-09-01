import type { CSSProperties } from 'react';

export interface HeroImageCardProps {
  /** Image URL (athlete photo). Without one, the card shows the brand burst on a gradient. */
  src?: string;
  alt?: string;
  height?: number;
  style?: CSSProperties;
}

/**
 * The activity-details hero: a 20 px-radius image card with a soft blackberry→dragonfruit gradient
 * and the dragonfruit starburst over teal spokes. Photography is warm, back-of-athlete, mid-stride.
 */
export function HeroImageCard({ src, alt = '', height = 300, style }: HeroImageCardProps) {
  const spokes = Array.from({ length: 8 }, (_, i) => (i * 180) / 8);
  const star = Array.from({ length: 32 }, (_, i) => { const a = (i * Math.PI) / 16; const r = i % 2 ? 36 : 50; return `${50 + r * Math.cos(a)},${50 + r * Math.sin(a)}`; }).join(' ');
  return (
    <div style={{ position: 'relative', height, borderRadius: 20, overflow: 'hidden', background: 'linear-gradient(135deg, rgb(74,33,67) 0%, rgb(56,22,51) 50%, rgba(220,37,151,0.35) 100%)', ...style }}>
      <svg viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', opacity: 0.9 }} aria-hidden>
        {spokes.map((deg) => <line key={deg} x1="50" y1="50" x2={50 + 60 * Math.cos((deg * Math.PI) / 180)} y2={50 + 60 * Math.sin((deg * Math.PI) / 180)} stroke="rgba(28,249,207,0.25)" strokeWidth="0.6" />)}
        {spokes.map((deg) => <line key={'b' + deg} x1="50" y1="50" x2={50 - 60 * Math.cos((deg * Math.PI) / 180)} y2={50 - 60 * Math.sin((deg * Math.PI) / 180)} stroke="rgba(28,249,207,0.25)" strokeWidth="0.6" />)}
        <polygon points={star} fill="none" stroke="rgb(220,37,151)" strokeWidth="1" />
      </svg>
      {src ? <img src={src} alt={alt} style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover', mixBlendMode: 'luminosity', opacity: 0.85 }} /> : null}
    </div>
  );
}
