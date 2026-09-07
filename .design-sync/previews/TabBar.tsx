import { useState } from 'react';
import { TabBar } from '@mealvana/endurance-ds';
import { Phone } from './_frame';
const items = [{ value: 'timeline', icon: 'calendar' as const, label: 'Timeline' }, { value: 'plan', icon: 'calendarCheck' as const, label: 'Plan' }, { value: 'learn', icon: 'graduationCap' as const, label: 'Learn' }];
export const Inline = () => { const [v, s] = useState('timeline'); return <Phone><TabBar inline items={items} selected={v} onChange={s} /></Phone>; };
