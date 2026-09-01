import type { CSSProperties } from 'react';
import { InfoIcon } from './InfoIcon';
import { SourceDot } from './SourceDot';
import type { DataSource } from './SourceDot';
import { F, V } from './_shared';

export interface BreakdownRow {
  name: string;
  /** Provenance line — "verified · Garmin", "estimated". */
  source: DataSource;
  sourceLabel?: string;
  /** Left number column ("so far"). Prefix `+` for additive rows. */
  soFar: string;
  /** Right number column ("by day's end"). */
  byEnd: string;
  onInfo?: () => void;
}

export interface BreakdownTableProps {
  /** Card eyebrow — "Energy burned". */
  title: string;
  columns?: [string, string];
  rows: BreakdownRow[];
  /** Total line at the bottom, numbers in electrolyte. */
  total?: { label: string; soFar: string; byEnd: string; onInfo?: () => void };
  style?: CSSProperties;
}

const num: CSSProperties = { fontFamily: F.mono, fontSize: 17, fontVariantNumeric: 'tabular-nums', textAlign: 'right', whiteSpace: 'nowrap' };

/**
 * "Where the burn comes from": a bordered card with a two-column number table. Each row carries a
 * SourceDot, name + InfoIcon, provenance line, and its so-far / by-day's-end figures. Totals in electrolyte.
 */
export function BreakdownTable({ title, columns = ['so far', "by day's end"], rows, total, style }: BreakdownTableProps) {
  return (
    <div style={{ borderRadius: 18, border: '1px solid rgba(248,246,235,0.18)', background: 'rgba(248,246,235,0.03)', padding: '18px 18px 6px', color: V.cream, ...style }}>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr auto auto', columnGap: 16, alignItems: 'baseline', paddingBottom: 12, borderBottom: '1px solid rgba(248,246,235,0.18)' }}>
        <span style={{ fontFamily: F.body, fontWeight: 500, fontSize: 12, letterSpacing: '0.12em', textTransform: 'uppercase', color: 'rgba(248,246,235,0.55)' }}>{title}</span>
        <span style={{ fontFamily: F.body, fontSize: 12, color: 'rgba(248,246,235,0.5)' }}>{columns[0]}</span>
        <span style={{ fontFamily: F.body, fontSize: 12, color: 'rgba(248,246,235,0.5)' }}>{columns[1]}</span>
      </div>
      {rows.map((r) => (
        <div key={r.name} style={{ display: 'grid', gridTemplateColumns: '1fr auto auto', columnGap: 16, alignItems: 'center', padding: '16px 0', borderBottom: '1px solid rgba(248,246,235,0.12)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, minWidth: 0 }}>
            <SourceDot source={r.source} size={14} />
            <div style={{ minWidth: 0 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontFamily: F.body, fontSize: 17, lineHeight: 1.2 }}>{r.name} <InfoIcon label={r.name} onClick={r.onInfo} size={16} /></div>
              <div style={{ fontFamily: F.body, fontSize: 13, color: 'rgba(248,246,235,0.5)', marginTop: 3 }}>{r.sourceLabel ?? r.source}</div>
            </div>
          </div>
          <span style={num}>{r.soFar}</span>
          <span style={num}>{r.byEnd}</span>
        </div>
      ))}
      {total ? (
        <div style={{ display: 'grid', gridTemplateColumns: '1fr auto auto', columnGap: 16, alignItems: 'center', padding: '16px 0 12px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontFamily: F.display, fontWeight: 700, fontSize: 18 }}>{total.label} <InfoIcon label={total.label} onClick={total.onInfo} color={V.electrolyte} size={16} /></div>
          <span style={{ ...num, color: V.electrolyte }}>{total.soFar}</span>
          <span style={{ ...num, color: V.electrolyte }}>{total.byEnd}</span>
        </div>
      ) : null}
    </div>
  );
}
