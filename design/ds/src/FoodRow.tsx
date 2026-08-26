import type { CSSProperties, ReactNode } from 'react';
import { Icon } from './Icon';
import { IconChip } from './IconChip';
import { DARK_DEFAULT, F, V, cardFill, fg, fg2, fg3, line } from './_shared';

export interface FoodRowProps {
  /** Food name — Compadre, renders in caps ("Oatmeal, Banana & Honey"). Truncates to one line. */
  name: string;
  kcal?: number;
  carbs?: number;
  protein?: number;
  fat?: number;
  /** Free-text line used when the macro numbers aren't given ("1 medium • 27 g carbs"). */
  detail?: string;
  /** Clock label rendered by a timeline, not the row — pass it if you compose your own rail. */
  time?: string;
  icon?: ReactNode;
  onClick?: () => void;
  /** Trailing `…` more affordance (the release meal card). */
  onMore?: () => void;
  dark?: boolean;
  style?: CSSProperties;
}

/**
 * A meal on the fuel timeline: 56 px orange utensils chip, caps food name, then
 * `640 kcal · 116C · 16P · 12F` in the surface's data colours. Rendered as a card row.
 */
export function FoodRow({ name, kcal, carbs, protein, fat, detail, icon, onClick, onMore, dark = DARK_DEFAULT, style }: FoodRowProps) {
  const hasMacros = kcal != null;
  return (
    <div
      role={onClick ? 'button' : undefined}
      onClick={onClick}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 14,
        minWidth: 0,
        width: '100%',
        boxSizing: 'border-box',
        padding: 16,
        borderRadius: 'var(--me-radius-lg)',
        background: cardFill(dark),
        border: `1px solid ${line(dark)}`,
        color: fg(dark),
        cursor: onClick ? 'pointer' : 'default',
        ...style,
      }}
    >
      <IconChip size={56} color={V.orange}>{icon ?? <Icon name="utensils" size={22} />}</IconChip>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontFamily: 'var(--me-font-ui-wide)', fontSize: 19, lineHeight: 1.1, letterSpacing: '0.06em', textTransform: 'uppercase', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{name}</div>
        <div style={{ fontFamily: F.body, fontSize: 13, marginTop: 6, color: fg2(dark), fontVariantNumeric: 'tabular-nums', display: 'flex', gap: 6, alignItems: 'baseline', flexWrap: 'wrap' }}>
          {hasMacros ? (
            <>
              <span style={{ fontWeight: 500, color: fg(dark) }}>{kcal}</span><span style={{ color: fg3(dark) }}>kcal</span>
              <span style={{ color: fg3(dark) }}>·</span><span style={{ color: V.dataCarbs }}>{carbs}C</span>
              <span style={{ color: fg3(dark) }}>·</span><span style={{ color: V.dataProtein }}>{protein}P</span>
              <span style={{ color: fg3(dark) }}>·</span><span style={{ color: V.dataFat }}>{fat}F</span>
            </>
          ) : (
            <span>{detail}</span>
          )}
        </div>
      </div>
      {onMore ? <button type="button" aria-label="More" onClick={(e) => { e.stopPropagation(); onMore(); }} style={{ border: 'none', background: 'transparent', color: 'rgba(248,246,235,0.5)', cursor: 'pointer', display: 'flex', padding: 4 }}><Icon name="ellipsis" size={18} /></button> : null}
    </div>
  );
}
