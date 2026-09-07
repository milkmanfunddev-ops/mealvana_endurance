import type { CSSProperties, ReactNode } from 'react';
import { Icon } from './Icon';
import type { IconName } from './Icon';
import { IconChip } from './IconChip';
import { DARK_DEFAULT, F, V, cardFill, fg, fg2, line } from './_shared';

export interface ActivityRowProps {
  /** Activity title — Compadre, renders in caps ("Swim", "Sunday Long Run"). */
  title: string;
  /** Data line — "2,000 yd · 40 min", "1.8 h · 12 mi". */
  detail: string;
  /** Sport glyph; defaults by common names, else pass an `<Icon>` via `icon`. */
  sport?: 'run' | 'bike' | 'swim' | 'walk' | 'hike' | 'strength';
  icon?: ReactNode;
  /** Shows the "✓ verified · Garmin" pill and accents the card border in electrolyte. */
  verified?: string;
  /** Orange fuel-plan line ("Pre · During · Recovery fuel >"). */
  fuelLine?: string;
  /** Trailing uppercase helper for event lists ("12 days away"). */
  daysAway?: string;
  selected?: boolean;
  onClick?: () => void;
  dark?: boolean;
  style?: CSSProperties;
}

const sportIcon: Record<NonNullable<ActivityRowProps['sport']>, IconName> = {
  run: 'personRunning', bike: 'personBiking', swim: 'personSwimming', walk: 'personWalking', hike: 'personHiking', strength: 'dumbbell',
};

/**
 * A workout card on the fuel timeline: 56 px electrolyte chip, caps title, verified pill, detail,
 * orange fuel line. Verified cards get an electrolyte hairline (the rendering's contract).
 */
export function ActivityRow({ title, detail, sport = 'run', icon, verified, fuelLine, daysAway, selected, onClick, dark = DARK_DEFAULT, style }: ActivityRowProps) {
  const border = verified ? V.electrolyte : selected ? V.orange : line(dark);
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
        padding: 14,
        borderRadius: 'var(--me-radius-md)',
        background: verified ? 'rgba(28,249,207,0.05)' : cardFill(dark),
        border: `1px solid ${border}`,
        color: fg(dark),
        cursor: onClick ? 'pointer' : 'default',
        ...style,
      }}
    >
      <IconChip size={56} color={V.electrolyte}>{icon ?? <Icon name={sportIcon[sport]} size={24} />}</IconChip>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
          <span style={{ fontFamily: F.ui, fontSize: 20, lineHeight: 1.1, letterSpacing: '0.02em', textTransform: 'uppercase' }}>{title}</span>
          {verified ? (
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, padding: '3px 9px', borderRadius: 'var(--me-radius-pill)', background: 'rgba(28,249,207,0.12)', color: V.electrolyte, fontFamily: F.body, fontWeight: 500, fontSize: 9.5, letterSpacing: '0.02em' }}>
              <Icon name="check" size={9} /> verified · {verified}
            </span>
          ) : null}
        </div>
        <div style={{ fontFamily: F.body, fontSize: 11, color: fg2(dark), marginTop: 4, fontVariantNumeric: 'tabular-nums' }}>{detail}</div>
        {fuelLine ? <div style={{ fontFamily: F.body, fontSize: 10.5, color: V.orange, marginTop: 4 }}>{fuelLine}</div> : null}
      </div>
      {daysAway ? (
        <div style={{ fontFamily: F.body, fontWeight: 500, fontSize: 9.5, letterSpacing: '0.1em', textTransform: 'uppercase', color: fg2(dark), whiteSpace: 'nowrap' }}>{daysAway}</div>
      ) : null}
    </div>
  );
}
