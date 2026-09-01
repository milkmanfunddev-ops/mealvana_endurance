import type { CSSProperties } from 'react';
import { Icon } from './Icon';
import type { IconName } from './Icon';
import { V, resetBtn } from './_shared';

export interface TabBarItem<T extends string = string> { value: T; icon: IconName; label: string }

export interface TabBarProps<T extends string = string> {
  items: TabBarItem<T>[];
  selected: T;
  onChange: (value: T) => void;
  /** Render inline rather than pinned to the bottom of a positioned ancestor. */
  inline?: boolean;
  style?: CSSProperties;
}

/**
 * The floating bottom navigation: a hairline pill with three 28 px glyphs; the selected one
 * sits in a cream circle with blackberry ink. Default items are calendar · tasks · learn.
 */
export function TabBar<T extends string = string>({ items, selected, onChange, inline, style }: TabBarProps<T>) {
  return (
    <div style={{ position: inline ? 'relative' : 'absolute', bottom: inline ? undefined : 22, left: 0, right: 0, display: 'flex', justifyContent: 'center', pointerEvents: 'none', ...style }}>
      <div style={{ pointerEvents: 'auto', display: 'flex', alignItems: 'center', gap: 8, padding: 6, borderRadius: 'var(--me-radius-pill)', border: '1px solid rgba(248,246,235,0.35)', background: 'rgba(56,22,51,0.92)', backdropFilter: 'blur(8px)' }}>
        {items.map((it) => {
          const on = it.value === selected;
          return (
            <button key={it.value} type="button" aria-label={it.label} aria-current={on ? 'page' : undefined} onClick={() => onChange(it.value)}
              style={{ ...resetBtn, width: 66, height: 66, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', background: on ? V.cream : 'transparent', color: on ? V.blackberry : V.cream }}>
              <Icon name={it.icon} size={26} />
            </button>
          );
        })}
      </div>
    </div>
  );
}
