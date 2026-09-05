import type { CSSProperties } from 'react';
import { DARK_DEFAULT, F, V, fg, resetBtn } from './_shared';

// Twin of lib/shared/widgets/kyle_design/inputs/intensity_preset_chips.dart —
// spec docs/ssot/spec/design/surfaces/create-flow-fueling-controls.md, chip
// geometry from prototypes/create-activity-plan/v1.html. Labels are
// sport-specific and arrive from the surface (WorkoutPresetData.labelFor).

export interface IntensityPresetChip {
  value: string;
  /** Sport-specific label — "Easy Run", "Long Ride", "Race Pace"… */
  label: string;
}

export interface IntensityPresetChipsProps {
  chips: IntensityPresetChip[];
  selected?: string;
  onSelect?: (value: string) => void;
  enabled?: boolean;
  dark?: boolean;
  style?: CSSProperties;
}

/** Wrap of tappable workout-preset pills for the intensity estimate mode: the selected chip is orange (15% fill, 2 px border, bold); the rest are hairline outlines. Two-per-row falls out of the wrap. */
export function IntensityPresetChips({ chips, selected, onSelect, enabled = true, dark = DARK_DEFAULT, style }: IntensityPresetChipsProps) {
  const inkAlpha = (a: number) => (dark ? `rgba(248,246,235,${a})` : `rgba(56,22,51,${a})`);
  return (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 9, ...style }}>
      {chips.map((chip) => {
        const isSelected = chip.value === selected;
        const border = !enabled ? inkAlpha(0.2) : isSelected ? V.orange : inkAlpha(0.4);
        const color = !enabled ? inkAlpha(0.3) : isSelected ? V.orange : fg(dark);
        return (
          <button
            key={chip.value}
            type="button"
            disabled={!enabled}
            onClick={enabled ? () => onSelect?.(chip.value) : undefined}
            style={{ ...resetBtn, padding: '11px 15px', borderRadius: 'var(--me-radius-pill)', border: `${isSelected ? 2 : 1}px solid ${border}`, background: isSelected ? 'rgba(247,139,20,0.15)' : 'transparent', fontFamily: F.body, fontSize: 12, lineHeight: 1.5, fontWeight: isSelected ? 700 : 400, color, cursor: enabled ? 'pointer' : 'default', transition: 'background 200ms, border-color 200ms, color 200ms' }}
          >
            {chip.label}
          </button>
        );
      })}
    </div>
  );
}
