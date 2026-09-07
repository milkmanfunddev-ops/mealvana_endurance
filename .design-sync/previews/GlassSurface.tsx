import { GlassSurface } from '@mealvana/endurance-ds';
import { Phone } from './_frame';

// Glass only reads over content — every cell floats the surface over a busy ground.
const Ground = ({ children }: { children: React.ReactNode }) => (
  <div style={{ position: 'relative', borderRadius: 16, overflow: 'hidden', padding: 18, background: 'linear-gradient(135deg, rgba(247,139,20,0.5), rgba(56,22,51,0.3) 45%, rgba(28,249,207,0.4))' }}>
    <p style={{ margin: '0 0 10px', fontFamily: 'var(--me-font-body)', fontSize: 12.5, color: 'var(--me-cream)' }}>
      Content behind stays recognizable through the backdrop chain — more vivid, slightly brighter, never darker.
    </p>
    {children}
  </div>
);

export const Chrome = () => (
  <Phone><Ground>
    <GlassSurface lift style={{ padding: '12px 18px', display: 'inline-block', fontFamily: 'var(--me-font-body)', fontSize: 13 }}>Floating chrome pill</GlassSurface>
  </Ground></Phone>
);

export const Dimmed = () => (
  <Phone><Ground>
    <GlassSurface variant="dimmed" lift style={{ padding: '12px 18px', display: 'inline-block', fontFamily: 'var(--me-font-body)', fontSize: 13 }}>Tab-bar dim chain — readable over anything</GlassSurface>
  </Ground></Phone>
);

export const Sheet = () => (
  <Phone><Ground>
    <GlassSurface variant="sheet" style={{ padding: '22px 18px', fontFamily: 'var(--me-font-body)', fontSize: 13 }}>Summoned sheet material (blur 18 · veil)</GlassSurface>
  </Ground></Phone>
);
