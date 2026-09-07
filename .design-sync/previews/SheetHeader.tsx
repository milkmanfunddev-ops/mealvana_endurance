import type React from 'react';
import { SheetHeader } from '@mealvana/endurance-ds';
import { Phone } from './_frame';
export const Energy = () => <Phone><SheetHeader title="Today's Energy" subtitle="6:14 PM · 76% of the day done" /></Phone>;
export const NoSubtitle = () => <Phone><SheetHeader title="Today's Fuel" /></Phone>;
import { EquationCard, BreakdownTable, SourceLegend, PagerDots, HeroNumber, StackedBar, EnergyRow, Card, InfoIcon, SegmentedControl, MacroDonut } from '@mealvana/endurance-ds';
const Screen = ({ children }: { children: React.ReactNode }) => <div style={{ width: '100%', maxWidth: 428, background: 'var(--me-blackberry)', color: 'var(--me-cream)', padding: '44px 16px 24px', boxSizing: 'border-box', display: 'grid', gridTemplateColumns: 'minmax(0, 1fr)', gap: 18 }}>{children}</div>;
export const TodaysEnergyScreen = () => (
  <Screen>
    <SheetHeader title="Today's Energy" subtitle="6:14 PM · 76% of the day done" />
    <EquationCard eaten={1107} burned={1522} />
    <div style={{ display: 'flex', justifyContent: 'space-between', gap: 16, fontFamily: 'var(--me-font-body)', fontSize: 12, color: 'rgba(248,246,235,0.55)' }}><span>Eaten <b style={{ color: 'var(--me-cream)', fontWeight: 500 }}>1,107</b> / 1,928 · 821 to go</span><span>Burned <b style={{ color: 'var(--me-cream)', fontWeight: 500 }}>1,522</b> / 2,462 projected</span></div>
    <div className="me-eyebrow" style={{ fontSize: 13 }}>Where the burn comes from</div>
    <BreakdownTable title="Energy burned" rows={[
      { name: 'Resting', source: 'estimated', sourceLabel: 'estimated', soFar: '808', byEnd: '1,064' },
      { name: 'Workout', source: 'verified', sourceLabel: 'verified · Garmin', soFar: '+411', byEnd: '+930' },
      { name: 'Daily movement', source: 'verified', sourceLabel: 'verified · Garmin', soFar: '+193', byEnd: '+275' },
      { name: 'Digestion', source: 'estimated', sourceLabel: 'estimated', soFar: '+110', byEnd: '+193' },
    ]} total={{ label: 'Total burned', soFar: '1,522', byEnd: '2,462' }} />
    <SourceLegend />
    <PagerDots count={3} index={0} style={{ marginTop: 40 }} />
  </Screen>
);
export const ActiveEnergyScreen = () => (
  <Screen>
    <SheetHeader title="Active Energy" subtitle="6:14 PM · 76% of the day done" />
    <HeroNumber label="Done so far" value="411" unit="kcal" caption={<>+519 planned → <b style={{ color: 'var(--me-electrolyte)', fontWeight: 500 }}>930</b> projected</>} />
    <StackedBar segments={[{ value: 411, kind: 'done', label: '411 done' }, { value: 519, kind: 'planned', label: '519 planned' }, { value: 120, kind: 'remaining' }]} />
    <EnergyRow title="Drills Day" detail="5:57 AM · 3 mi · 43 min" kcal={397} status="planned" source="planned" sourceLabel="planned (estimate)" />
    <EnergyRow title="12 mi Run" detail="5:57 AM · 5.0 mi · 43 min" kcal={411} status="verified" source="verified" sourceLabel="verified · Garmin · as planned" />
    <Card accent="var(--me-electrolyte)" style={{ borderRadius: 24, padding: 22 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}><span style={{ fontFamily: 'var(--me-font-display)', fontWeight: 700, fontSize: 22, display: 'inline-flex', gap: 10, alignItems: 'center' }}>Active energy <InfoIcon label="active energy" color="var(--me-electrolyte)" /></span><span style={{ fontFamily: 'var(--me-font-mono)', fontSize: 28, color: 'var(--me-electrolyte)' }}>930</span></div>
      <div style={{ textAlign: 'right', fontFamily: 'var(--me-font-mono)', fontSize: 16, color: 'rgba(248,246,235,0.6)', marginTop: 6 }}><span style={{ color: 'var(--me-electrolyte)' }}>411 done</span> + 519 planned</div>
    </Card>
    <SourceLegend labels={{ verified: 'verified · Garmin', 'self-reported': 'self-reported', planned: 'planned (estimate)' }} />
    <PagerDots count={3} index={1} style={{ marginTop: 40 }} />
  </Screen>
);
export const TodaysFuelScreen = () => (
  <Screen>
    <SheetHeader title="Today's Fuel" />
    <SegmentedControl full size="lg" segments={[{ value: 'daily', label: 'Daily' }, { value: 'weekly', label: 'Weekly' }]} selected="daily" onChange={() => {}} />
    <div style={{ textAlign: 'center', fontFamily: 'var(--me-font-body)', fontSize: 14, color: 'rgba(248,246,235,0.5)' }}>6:14 PM</div>
    <div style={{ textAlign: 'center' }}><span style={{ fontFamily: 'var(--me-font-display)', fontWeight: 700, fontSize: 56, lineHeight: 1 }}>1,107</span> <span style={{ fontFamily: 'var(--me-font-display)', fontWeight: 700, fontSize: 22, color: 'rgba(248,246,235,0.6)' }}>/ 1,928 kcal</span><div style={{ fontFamily: 'var(--me-font-body)', fontSize: 16, color: 'rgba(248,246,235,0.55)', marginTop: 8 }}>57% of target · 821 to go</div></div>
    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
      <MacroDonut size={108} label="Carbs" value={184} target={253} color="var(--me-data-carbs)" caption="70 g left" />
      <MacroDonut size={108} label="Protein" value={29} target={85} color="var(--me-data-protein)" caption="57 g left" />
      <MacroDonut size={108} label="Fat" value={31} target={64} color="var(--me-data-fat)" caption="34 g left" />
    </div>
    <div style={{ display: 'flex', justifyContent: 'center', gap: 28, fontFamily: 'var(--me-font-body)', fontSize: 14, color: 'rgba(248,246,235,0.6)' }}><span><span style={{ display: 'inline-block', width: 26, height: 10, borderRadius: 6, background: 'var(--me-electrolyte)', verticalAlign: 'middle', marginRight: 8 }} />logged</span><span><span style={{ display: 'inline-block', width: 26, height: 10, borderRadius: 6, background: 'rgba(28,249,207,0.35)', verticalAlign: 'middle', marginRight: 8 }} />+ planned</span></div>
    <div style={{ borderTop: '1px solid rgba(248,246,235,0.15)', paddingTop: 20, display: 'flex', justifyContent: 'space-between', fontFamily: 'var(--me-font-body)', fontSize: 14, letterSpacing: '0.1em', textTransform: 'uppercase', color: 'rgba(248,246,235,0.55)' }}><span>Where it came from · <span style={{ textTransform: 'none' }}>1 logged</span></span><span>⌄</span></div>
    <PagerDots count={3} index={2} style={{ marginTop: 40 }} />
  </Screen>
);
