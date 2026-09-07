import type React from 'react';
import { PhaseCard, MacroStat, FuelStep, FuelItem, DetailHeader, HeroImageCard, ScheduleBlock, Banner, SegmentedControl } from '@mealvana/endurance-ds';
import { Phone } from './_frame';
const Trio = ({ a, b, c }: { a: [string, number]; b: [string, number]; c: string }) => (
  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16 }}>
    <MacroStat value={a[0]} label="Carbs" color="var(--me-electrolyte)" range={{ min: '50g', max: '190g', position: a[1] }} />
    <MacroStat value={b[0]} label="Fluids" color="var(--me-electrolyte)" range={{ min: '0oz', max: '17oz', position: b[1] }} />
    <MacroStat value={c} label="Sodium" />
  </div>
);
export const Before = () => (
  <Phone><PhaseCard phase="before">
    <Trio a={['68g', 0.13]} b={['11oz', 0.65]} c="378mg" />
    <div style={{ display: 'grid', gap: 12 }}>
      <FuelStep title="Pre-Workout Snack" timing="Now – 30 min out" foods="Orange Juice + Bread / Toast" stats={[{ value: '50g', label: 'Carbs' }, { value: '8oz', label: 'Fluids' }]} />
      <FuelStep title="Top-Off" timing="Last 30 min" foods="Energy Chews + Sports Drink" stats={[{ value: '20g', label: 'Carbs' }, { value: '4oz', label: 'Fluids' }]} />
    </div>
  </PhaseCard></Phone>
);
export const During = () => (
  <Phone><PhaseCard phase="during" icon="personRunning">
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12 }}>
      <MacroStat value="82g" label="Carbs" color="var(--me-electrolyte)" range={{ min: '81', max: '108', position: 0.05 }} />
      <MacroStat value="49oz" label="Fluids" color="var(--me-electrolyte)" range={{ min: '41', max: '55', position: 0.57 }} />
      <MacroStat value="1250mg" label="Sodium" color="var(--me-electrolyte)" range={{ min: '936', max: '1404', position: 0.67 }} />
    </div>
    <div style={{ display: 'grid', gap: 12 }}>
      <FuelItem icon="droplet" text="1.5 servings Enervit Carbo Gel C2:1 Mango" />
      <FuelItem icon="bottleWater" text="4.5 cups Water" />
      <FuelItem icon="bottleWater" text="1.5 cups Sports Drink" />
      <FuelItem icon="bagShopping" text="5.5 salt packets" />
    </div>
  </PhaseCard></Phone>
);
export const ActivityDetailsScreen = () => (
  <div style={{ width: '100%', maxWidth: 428, background: 'var(--me-blackberry)', color: 'var(--me-cream)', padding: '44px 16px 24px', boxSizing: 'border-box', display: 'grid', gridTemplateColumns: 'minmax(0, 1fr)', gap: 20 }}>
    <DetailHeader title="12 mi Run" actions={[{ icon: 'penToSquare', label: 'Edit' }, { icon: 'trash', label: 'Delete', tone: 'destructive' }]} />
    <HeroImageCard height={260} />
    <ScheduleBlock label="Run scheduled for" stats={['5.0 mi', '43m', '9:00 /mi']} date="Aug 25, 2026" time="5:57am" device="Garmin Forerunner 955" />
    <Banner title="Some pins honored, some skipped" detail="3 honored · 1 skipped" onExpand={() => {}} />
    <SegmentedControl full size="lg" tone="orange" segments={[{ value: 'planned', label: 'Planned' }, { value: 'actual', label: 'Actual' }]} selected="planned" onChange={() => {}} />
    <PhaseCard phase="before">
      <Trio a={['68g', 0.13]} b={['11oz', 0.65]} c="378mg" />
      <div style={{ display: 'grid', gap: 12 }}>
        <FuelStep title="Pre-Workout Snack" timing="Now – 30 min out" foods="Orange Juice + Bread / Toast" stats={[{ value: '50g', label: 'Carbs' }, { value: '8oz', label: 'Fluids' }]} />
        <FuelStep title="Top-Off" timing="Last 30 min" foods="Energy Chews + Sports Drink" stats={[{ value: '20g', label: 'Carbs' }, { value: '4oz', label: 'Fluids' }]} />
      </div>
    </PhaseCard>
    <PhaseCard phase="during" icon="personRunning">
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12 }}>
        <MacroStat value="82g" label="Carbs" color="var(--me-electrolyte)" range={{ min: '81', max: '108', position: 0.05 }} />
        <MacroStat value="49oz" label="Fluids" color="var(--me-electrolyte)" range={{ min: '41', max: '55', position: 0.57 }} />
        <MacroStat value="1250mg" label="Sodium" color="var(--me-electrolyte)" range={{ min: '936', max: '1404', position: 0.67 }} />
      </div>
      <div style={{ display: 'grid', gap: 12 }}>
        <FuelItem icon="droplet" text="1.5 servings Enervit Carbo Gel C2:1 Mango" />
        <FuelItem icon="bottleWater" text="4.5 cups Water" />
      </div>
    </PhaseCard>
  </div>
);
