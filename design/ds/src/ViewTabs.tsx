import type { CSSProperties } from 'react';
import { Icon } from './Icon';
import { F, V, resetBtn } from './_shared';

export interface ViewTab<T extends string = string> { value: T; label: string }

export interface ViewTabsProps<T extends string = string> {
  tabs: ViewTab<T>[];
  selected: T;
  onChange: (value: T) => void;
  /** Trailing gear opens settings. */
  onSettings?: () => void;
  /** Month stepper under the tabs ("August 2026"); omit to hide. */
  period?: string;
  onPrev?: () => void;
  onNext?: () => void;
  style?: CSSProperties;
}

/**
 * The dashboard's top chrome: `BY WEEK · BY MONTH` in Compadre Wide caps (active cream with a
 * 2 px underline, inactive at 50 %), a gear at the trailing edge, and the `‹ August 2026 ›`
 * stepper in Sansita 24 beneath.
 */
export function ViewTabs<T extends string = string>({ tabs, selected, onChange, onSettings, period, onPrev, onNext, style }: ViewTabsProps<T>) {
  return (
    <div style={{ display: 'grid', gap: 22, ...style }}>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr auto', alignItems: 'center' }}>
        <div style={{ display: 'flex', justifyContent: 'center', gap: 36 }}>
          {tabs.map((t) => {
            const on = t.value === selected;
            return (
              <button key={t.value} type="button" onClick={() => onChange(t.value)} aria-selected={on} role="tab"
                style={{ ...resetBtn, fontFamily: F.uiWide, fontSize: 18, letterSpacing: '0.16em', textTransform: 'uppercase', color: on ? V.cream : 'rgba(248,246,235,0.5)', paddingBottom: 8, borderBottom: `2px solid ${on ? V.cream : 'transparent'}` }}>
                {t.label}
              </button>
            );
          })}
        </div>
        <button type="button" aria-label="Settings" onClick={onSettings} style={{ ...resetBtn, color: V.cream, display: 'flex' }}><Icon name="gear" size={26} /></button>
      </div>
      {period ? (
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 28, color: V.cream }}>
          <button type="button" aria-label="Previous" onClick={onPrev} style={{ ...resetBtn, display: 'flex', color: V.cream }}><Icon name="chevronLeft" size={14} /></button>
          <span style={{ fontFamily: F.display, fontWeight: 700, fontSize: 22, lineHeight: 1 }}>{period}</span>
          <button type="button" aria-label="Next" onClick={onNext} style={{ ...resetBtn, display: 'flex', color: V.cream }}><Icon name="chevronRight" size={14} /></button>
        </div>
      ) : null}
    </div>
  );
}
