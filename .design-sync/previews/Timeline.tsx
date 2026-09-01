import { useState } from 'react';
import { Timeline, WorkoutCard, FoodRow, SecondaryButton, Icon, ViewTabs, WeekStrip, NetBalanceCard, SegmentedControl, IconChip, TabBar } from '@mealvana/endurance-ds';
import { Phone } from './_frame';

const AddRow = () => (
  <div style={{ display: 'flex', gap: 12 }}>
    <SecondaryButton size="sm" outline="dashed" icon={<Icon name="plus" size={12} />} style={{ flex: 1, height: 48 }}>Add Food</SecondaryButton>
    <SecondaryButton size="sm" outline="dashed" tone="orange" icon={<Icon name="plus" size={12} />} style={{ flex: 1, height: 48 }}>Add Activity</SecondaryButton>
  </div>
);

export const Day = () => (
  <Phone>
    <Timeline entries={[
      { dot: 'start', children: <AddRow /> },
      { time: '5:57 AM', dot: 'planned', children: <WorkoutCard title="Drills Day" detail="3 mi · 43 min" status="planned" /> },
      { time: '5:57 AM', dot: 'done', children: <WorkoutCard title="12 mi Run" detail="5.0 mi · 43 min" status="verified" source="Garmin" /> },
      { time: '7:00 AM', dot: 'planned', children: <WorkoutCard title="Foam Rolling" detail="other" status="planned" sport="other" /> },
      { time: '7:51 AM', dot: 'food', children: <FoodRow name="Oatmeal with Berries" kcal={777} carbs={102} protein={29} fat={31} onMore={() => {}} /> },
      { time: '8:30 AM', dot: 'skipped', children: <WorkoutCard title="Warm Up" detail="other" status="skipped" fuelLine={null} /> },
    ]} />
  </Phone>
);

export const FuelTimelineScreen = () => {
  const [view, setView] = useState('week'); const [day, setDay] = useState(2); const [f, setF] = useState('all'); const [tab, setTab] = useState('timeline');
  const days = [23, 24, 25, 26, 27, 28, 29].map((d, i) => ({ day: d, letter: 'SMTWTFS'[i], hasEntries: true }));
  return (
    <div style={{ position: 'relative', width: '100%', maxWidth: 428, background: 'var(--me-blackberry)', color: 'var(--me-cream)', paddingTop: 60, overflow: 'hidden', boxSizing: 'border-box' }}>
      <div style={{ padding: '0 16px' }}>
        <ViewTabs tabs={[{ value: 'week', label: 'By Week' }, { value: 'month', label: 'By Month' }]} selected={view} onChange={setView} period="August 2026" />
      </div>
      <div style={{ marginTop: 24 }}><WeekStrip days={days} selected={day} onSelect={setDay} style={{ padding: '0 8px 18px' }} /></div>
      <div style={{ padding: '18px 16px 0', display: 'grid', gap: 16 }}>
        <NetBalanceCard value={-415} status="slight deficit" />
        <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
          <SegmentedControl full segments={[{ value: 'all', label: 'All' }, { value: 'workout', label: 'Workout' }, { value: 'meals', label: 'Meals' }]} selected={f} onChange={setF} style={{ flex: 1 }} />
          <IconChip size={44} variant="outline" color="var(--me-dragonfruit)"><Icon name="heartPulse" size={18} /></IconChip>
          <IconChip size={44} variant="outline" color="var(--me-electrolyte)"><Icon name="clock" size={18} /></IconChip>
        </div>
        <Timeline style={{ marginTop: 6 }} entries={[
          { dot: 'start', children: <AddRow /> },
          { time: '5:57 AM', dot: 'planned', children: <WorkoutCard title="Drills Day" detail="3 mi · 43 min" status="planned" /> },
          { time: '5:57 AM', dot: 'done', children: <WorkoutCard title="12 mi Run" detail="5.0 mi · 43 min" status="verified" source="Garmin" /> },
          { time: '7:00 AM', dot: 'planned', children: <WorkoutCard title="Foam Rolling" detail="other" status="planned" sport="other" /> },
          { time: '7:51 AM', dot: 'food', children: <FoodRow name="Oatmeal with Berries" kcal={777} carbs={102} protein={29} fat={31} onMore={() => {}} /> },
          { time: '8:30 AM', dot: 'skipped', children: <WorkoutCard title="Warm Up" detail="other" status="skipped" fuelLine={null} /> },
        ]} />
        <div style={{ height: 110 }} />
      </div>
      <TabBar items={[{ value: 'timeline', icon: 'calendar', label: 'Timeline' }, { value: 'plan', icon: 'calendarCheck', label: 'Plan' }, { value: 'learn', icon: 'graduationCap', label: 'Learn' }]} selected={tab} onChange={setTab} />
    </div>
  );
};
