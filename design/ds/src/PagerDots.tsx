import type { CSSProperties } from 'react';
import { V, resetBtn } from './_shared';

export interface PagerDotsProps {
  count: number;
  /** Zero-based. */
  index: number;
  onChange?: (index: number) => void;
  style?: CSSProperties;
}

/** Sheet pager: the current page is an electrolyte pill, the rest muted dots. Centred under the sheet. */
export function PagerDots({ count, index, onChange, style }: PagerDotsProps) {
  return (
    <div role="tablist" style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 16, ...style }}>
      {Array.from({ length: count }, (_, i) => (
        <button key={i} type="button" role="tab" aria-selected={i === index} aria-label={`Page ${i + 1}`} onClick={() => onChange?.(i)}
          style={{ ...resetBtn, width: i === index ? 44 : 12, height: 12, borderRadius: 100, background: i === index ? V.electrolyte : 'rgba(248,246,235,0.25)', transition: 'width var(--me-duration-base) var(--me-ease-out)' }} />
      ))}
    </div>
  );
}
