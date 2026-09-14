import type { CSSProperties } from 'react';
import { V, F } from './_shared';

// D-2 source-provenance chip family — the twin of Flutter
// lib/shared/widgets/kyle_design/data/kyle_source_chip.dart
// (RATIFIED Xuan 2026-09-11; integrations-data-display.md D-2 / D-2b / D-2c,
// Q-DID2 variant A — chip is SOURCE ONLY, no relative time; manual-wins;
// inline conflict, never a modal). ONE parameterized family shared by
// FTP/CSS, body composition, events, and onboarding pre-fill.

const pill: CSSProperties = {
  fontFamily: F.body,
  fontSize: 12,
  fontStyle: 'italic',
  fontWeight: 600,
  padding: '4px 10px',
  borderRadius: 100,
  background: 'transparent',
  display: 'inline-flex',
  alignItems: 'center',
  whiteSpace: 'nowrap',
};

export interface SourceChipProps {
  /** 'Manual' renders cream; every provider ('TrainingPeaks', 'Garmin',
   *  'Final Surge', …) renders electrolyte. */
  source: string;
  /** Optional value suffix, shown only in a conflict pairing
   *  (e.g. '250 W' → "Manual · 250 W"). */
  value?: string;
  style?: CSSProperties;
}

/** A single provenance pill. Source only — never a relative time. */
export function SourceChip({ source, value, style }: SourceChipProps) {
  const isManual = source === 'Manual';
  const ink = isManual ? V.cream : V.electrolyte;
  const label = value == null ? source : `${source} · ${value}`;
  return (
    <span style={{ ...pill, color: ink, border: `1px solid ${ink}`, ...style }}>
      {label}
    </span>
  );
}

/** The "stale" tag — shown when the source value is older than the
 *  surface's ruled window (FTP/CSS 24 h, body comp 30 d). */
export function StaleChip({ style }: { style?: CSSProperties }) {
  const ink = 'rgba(248,246,235,0.5)';
  return (
    <span
      style={{
        fontFamily: F.body,
        fontSize: 11,
        fontStyle: 'italic',
        fontWeight: 600,
        padding: '2px 7px',
        borderRadius: 6,
        border: '1px solid rgba(248,246,235,0.12)',
        color: ink,
        display: 'inline-flex',
        alignItems: 'center',
        ...style,
      }}
    >
      stale
    </span>
  );
}

export interface TapToUseChipProps {
  source: string;
  value: string;
  onTap?: () => void;
  style?: CSSProperties;
}

/** The conflict adopt affordance: adopts the provider's value in a single
 *  tap ("TrainingPeaks · 240 W — tap to use"). Rendered in the same pill
 *  outline as SourceChip (Xuan amendment 2026-09-13 — reads as a tappable
 *  pill, not bare text). Never a modal (variant A). */
export function TapToUseChip({ source, value, onTap, style }: TapToUseChipProps) {
  return (
    <button
      type="button"
      onClick={onTap}
      style={{
        ...pill,
        color: V.electrolyte,
        border: `1px solid ${V.electrolyte}`,
        cursor: 'pointer',
        ...style,
      }}
    >
      {`${source} · ${value} — tap to use`}
    </button>
  );
}

export interface SourceProvenanceRowProps {
  /** The athlete's own value; null when unset. */
  manualValue?: number | null;
  /** The provider's value; null when the provider carries none. */
  providerValue?: number | null;
  /** Provider display name (default 'TrainingPeaks'; 'Garmin', 'Final Surge'). */
  providerName?: string;
  /** Show the stale tag (only takes effect with a provider value). */
  stale?: boolean;
  /** Unit suffix, e.g. 'W', 's/100m', 'lb'. */
  unit?: string;
  onAdoptProvider?: (v: number) => void;
  style?: CSSProperties;
}

/** The D-2 provenance ROW (variant A, manual-wins, inline conflict, NO
 *  modal). Agreement/provider-only → one source pill; a real conflict →
 *  Manual pill + tap-to-use pill; plus the stale tag when applicable. */
export function SourceProvenanceRow({
  manualValue,
  providerValue,
  providerName = 'TrainingPeaks',
  stale = false,
  unit = '',
  onAdoptProvider,
  style,
}: SourceProvenanceRowProps) {
  if (manualValue == null && providerValue == null) return null;

  const conflict =
    manualValue != null && providerValue != null && manualValue !== providerValue;
  const providerSourced =
    providerValue != null && (manualValue == null || manualValue === providerValue);

  return (
    <div
      style={{
        display: 'flex',
        flexWrap: 'wrap',
        gap: '6px 8px',
        alignItems: 'center',
        ...style,
      }}
    >
      {conflict ? (
        <>
          <SourceChip source="Manual" value={`${manualValue} ${unit}`} />
          <TapToUseChip
            source={providerName}
            value={`${providerValue} ${unit}`}
            onTap={() => onAdoptProvider?.(providerValue as number)}
          />
        </>
      ) : providerSourced ? (
        <SourceChip source={providerName} />
      ) : (
        <SourceChip source="Manual" />
      )}
      {stale && providerValue != null ? <StaleChip /> : null}
    </div>
  );
}
