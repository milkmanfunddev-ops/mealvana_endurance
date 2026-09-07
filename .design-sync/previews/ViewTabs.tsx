import { useState } from 'react';
import { ViewTabs } from '@mealvana/endurance-ds';
import { Phone } from './_frame';
const tabs = [{ value: 'week', label: 'By Week' }, { value: 'month', label: 'By Month' }];
export const WithPeriod = () => { const [v, s] = useState('week'); return <Phone w={428}><ViewTabs tabs={tabs} selected={v} onChange={s} period="August 2026" /></Phone>; };
export const TabsOnly = () => { const [v, s] = useState('month'); return <Phone w={428}><ViewTabs tabs={tabs} selected={v} onChange={s} /></Phone>; };
