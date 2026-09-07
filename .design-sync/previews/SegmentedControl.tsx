import { useState } from 'react';
import { SegmentedControl } from '@mealvana/endurance-ds';
import { Phone, Light } from './_frame';
const filters = [{ value: 'all', label: 'All' }, { value: 'workout', label: 'Workout' }, { value: 'meals', label: 'Meals' }];
export const Filters = () => { const [v, s] = useState('all'); return <Phone><div><SegmentedControl segments={filters} selected={v} onChange={s} /></div></Phone>; };
export const LargeDailyWeekly = () => { const [v, s] = useState('daily'); return <Phone><SegmentedControl full size="lg" segments={[{ value: 'daily', label: 'Daily' }, { value: 'weekly', label: 'Weekly' }]} selected={v} onChange={s} /></Phone>; };
export const OrangePlannedActual = () => { const [v, s] = useState('planned'); return <Phone><SegmentedControl full size="lg" tone="orange" segments={[{ value: 'planned', label: 'Planned' }, { value: 'actual', label: 'Actual' }]} selected={v} onChange={s} /></Phone>; };
export const OnLight = () => { const [v, s] = useState('workout'); return <Light><div><SegmentedControl dark={false} segments={filters} selected={v} onChange={s} /></div></Light>; };
