import type { CSSProperties } from 'react';
import { F, V } from './_shared';

export type DataSource = 'verified' | 'self-reported' | 'estimated' | 'planned';

export interface SourceDotProps {
  source: DataSource;
  size?: number;
  style?: CSSProperties;
}

/** The provenance glyph: filled = verified, half = self-reported, outline = estimated / planned. Always electrolyte. */
export function SourceDot({ source, size = 14, style }: SourceDotProps) {
  const base: CSSProperties = { width: size, height: size, borderRadius: '50%', display: 'inline-block', boxSizing: 'border-box', flex: '0 0 auto', verticalAlign: 'middle', ...style };
  if (source === 'verified') return <span style={{ ...base, background: V.electrolyte }} />;
  if (source === 'self-reported') return <span style={{ ...base, background: `linear-gradient(90deg, ${V.electrolyte} 50%, transparent 50%)`, border: `2px solid ${V.electrolyte}` }} />;
  return <span style={{ ...base, border: `2px solid ${V.electrolyte}`, opacity: 0.8 }} />;
}

export interface SourceLegendProps {
  /** Labels per source; omit a key to hide it. */
  labels?: Partial<Record<DataSource, string>>;
  onInfo?: () => void;
  style?: CSSProperties;
}

/** The legend row under a breakdown: `● verified by Garmin  ◐ self-reported  ○ estimated  (i)`. */
export function SourceLegend({ labels = { verified: 'verified by Garmin', 'self-reported': 'self-reported', estimated: 'estimated' }, style }: SourceLegendProps) {
  return (
    <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 16, flexWrap: 'wrap', fontFamily: F.body, fontSize: 13, color: 'rgba(248,246,235,0.7)', ...style }}>
      {(Object.keys(labels) as DataSource[]).map((k) => (
        <span key={k} style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}><SourceDot source={k} /> {labels[k]}</span>
      ))}
    </div>
  );
}
