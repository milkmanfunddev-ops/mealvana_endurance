import type { CSSProperties } from 'react';
import { Icon } from './Icon';
import type { IconName } from './Icon';
import { V, F, resetBtn } from './_shared';

export interface TabBarItem<T extends string = string> { value: T; icon: IconName; label: string }

export interface TabBarProps<T extends string = string> {
  /** 3–5 destinations (spec Q3). */
  items: TabBarItem<T>[];
  selected: T;
  onChange: (value: T) => void;
  /**
   * COLLAPSED state (spec Q1): one ~52px circular glass button at the
   * bottom-left showing only the active tab's icon. The app collapses on
   * scroll-down and re-expands on scroll-up; here it's a prop.
   */
  collapsed?: boolean;
  /** Render inline rather than pinned to the bottom of a positioned ancestor. */
  inline?: boolean;
  style?: CSSProperties;
}

/**
 * The home shell's floating tab bar — `tab-bar.md` v1 as amended 2026-09-07
 * (liquid-bubble ratification): a LEFT-ANCHORED glass pill on the dimmed
 * backdrop chain, icon+label items, and the active item highlighted by a
 * raised liquid-glass bubble that bulges 6px past the bar's border, `cream`
 * ink on glass. The active item's content zooms 1.08 (the magnified-through-
 * glass read). True refraction is Impeller-only in the app; this twin renders
 * the flat translucent approximation (same as Flutter web's FakeGlass).
 */
export function TabBar<T extends string = string>({ items, selected, onChange, collapsed, inline, style }: TabBarProps<T>) {
  const BULGE = 6;
  const active = items.find((it) => it.value === selected) ?? items[0];

  if (collapsed) {
    return (
      <div style={{ position: inline ? 'relative' : 'absolute', bottom: inline ? undefined : 28, left: 14, display: 'inline-flex', ...style }}>
        <button
          type="button"
          aria-label={active.label}
          onClick={() => onChange(active.value)}
          className="me-glass-dim me-glass-lift"
          style={{ ...resetBtn, width: 52, height: 52, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', color: V.cream }}
        >
          <Icon name={active.icon} size={20} />
        </button>
      </div>
    );
  }

  return (
    <div style={{ position: inline ? 'relative' : 'absolute', bottom: inline ? undefined : 28, left: 14, display: 'inline-flex', ...style }}>
      <div
        className="me-glass-dim me-glass-lift"
        style={{ display: 'flex', alignItems: 'stretch', borderRadius: 'var(--me-radius-pill)', padding: '6px 10px' }}
      >
        {items.map((it) => {
          const on = it.value === selected;
          return (
            <button
              key={it.value}
              type="button"
              aria-label={it.label}
              aria-current={on ? 'page' : undefined}
              onClick={() => onChange(it.value)}
              style={{ ...resetBtn, position: 'relative', width: 82, padding: '8px 0 7px', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3, color: on ? V.cream : 'rgba(248,246,235,0.6)' }}
            >
              {on && (
                <span
                  aria-hidden
                  style={{
                    position: 'absolute',
                    left: 0,
                    right: 0,
                    top: -(BULGE + 6),
                    bottom: -(BULGE + 6),
                    borderRadius: 'var(--me-radius-pill)',
                    background: 'radial-gradient(120% 120% at 50% 20%, rgba(248,246,235,0.14), rgba(248,246,235,0.04) 65%)',
                    boxShadow: 'inset 0 1px 0 var(--me-glass-rim-top), inset 0 -1px 1px rgba(0,0,0,0.25), var(--me-glass-lift)',
                    backdropFilter: 'blur(1.5px) saturate(1.15)',
                    WebkitBackdropFilter: 'blur(1.5px) saturate(1.15)',
                  }}
                />
              )}
              <span style={{ position: 'relative', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3, transform: on ? 'scale(1.08)' : undefined }}>
                <Icon name={it.icon} size={19} />
                <span style={{ fontFamily: F.body, fontSize: 10.5, lineHeight: '14px', fontWeight: on ? 500 : 400 }}>{it.label}</span>
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
