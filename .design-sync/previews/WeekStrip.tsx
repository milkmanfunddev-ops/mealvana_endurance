import { useState } from 'react';
import { WeekStrip } from '@mealvana/endurance-ds';
import { Phone } from './_frame';
const days = [23, 24, 25, 26, 27, 28, 29].map((d, i) => ({ day: d, letter: 'SMTWTFS'[i], hasEntries: i !== 5 }));
export const Week = () => { const [s, set] = useState(2); return <Phone w={428}><WeekStrip days={days} selected={s} onSelect={set} /></Phone>; };
