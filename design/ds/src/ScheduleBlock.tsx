import type { CSSProperties } from 'react';
import { F, V, resetBtn } from './_shared';

export interface ScheduleBlockProps {
  /** Eyebrow — "Run scheduled for". */
  label: string;
  /** Stats separated by dots — ["5.0 mi", "43m", "9:00 /mi"]. */
  stats: string[];
  date: string;
  time: string;
  onEditDate?: () => void;
  onEditTime?: () => void;
  /** Device line — "Garmin Forerunner 955" with the GARMIN badge. */
  device?: string;
  style?: CSSProperties;
}

/** Centred schedule summary under the hero: eyebrow, dotted stats, DATE / TIME with edit glyphs, device badge. */
export function ScheduleBlock({ label, stats, date, time, onEditDate, onEditTime, device, style }: ScheduleBlockProps) {
  const eyebrow: CSSProperties = { fontFamily: F.body, fontWeight: 500, fontSize: 12, letterSpacing: '0.12em', textTransform: 'uppercase', color: 'rgba(248,246,235,0.55)' };
  const Field = ({ k, v, onEdit }: { k: string; v: string; onEdit?: () => void }) => (
    <div style={{ display: 'grid', justifyItems: 'center', gap: 10 }}>
      <span style={eyebrow}>{k}</span>
      <button type="button" onClick={onEdit} style={{ ...resetBtn, display: 'inline-flex', alignItems: 'baseline', gap: 8, fontFamily: F.display, fontWeight: 700, fontSize: 26, color: V.cream }}>
        {v} <span style={{ color: 'rgba(248,246,235,0.5)', display: 'inline-flex' }}><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="square"><path d="M12 20h9M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z" /></svg></span>
      </button>
    </div>
  );
  return (
    <div style={{ textAlign: 'center', color: V.cream, display: 'grid', gap: 14, ...style }}>
      <div style={eyebrow}>{label}</div>
      <div style={{ fontFamily: F.body, fontWeight: 500, fontSize: 20, display: 'flex', justifyContent: 'center', gap: 14, flexWrap: 'wrap' }}>
        {stats.map((s, i) => <span key={i}>{i ? <span style={{ color: 'rgba(248,246,235,0.5)', marginRight: 14 }}>•</span> : null}{s}</span>)}
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', marginTop: 4 }}>
        <Field k="Date" v={date} onEdit={onEditDate} />
        <Field k="Time" v={time} onEdit={onEditTime} />
      </div>
      {device ? (
        <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 10, fontFamily: F.body, fontWeight: 500, fontSize: 15, color: 'rgba(248,246,235,0.75)' }}>
          <span style={{ background: '#fff', color: '#000', fontFamily: F.body, fontWeight: 700, fontSize: 9, letterSpacing: '0.08em', padding: '3px 6px', borderRadius: 2 }}>GARMIN</span> {device}
        </div>
      ) : null}
    </div>
  );
}
