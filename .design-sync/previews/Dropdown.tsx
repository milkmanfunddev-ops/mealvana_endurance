import { useState } from 'react';
import { Dropdown } from '@mealvana/endurance-ds';
import { Phone, Light } from './_frame';

const types = [{ value: 'run', label: 'Run' }, { value: 'ride', label: 'Ride' }, { value: 'swim', label: 'Swim' }, { value: 'brick', label: 'Brick' }];
const zones = [{ value: 'z1', label: 'Zone 1 · Recovery' }, { value: 'z2', label: 'Zone 2 · Endurance' }, { value: 'z3', label: 'Zone 3 · Tempo' }, { value: 'z4', label: 'Zone 4 · Threshold' }];

export const ActivityType = () => { const [v, s] = useState('run'); return <Phone><Dropdown label="Activity type" value={v} items={types} onChange={s} /></Phone>; };
export const Intensity = () => { const [v, s] = useState('z2'); return <Phone><Dropdown label="Intensity" value={v} items={zones} onChange={s} /></Phone>; };
export const OnLight = () => { const [v, s] = useState('ride'); return <Light><Dropdown dark={false} label="Activity type" value={v} items={types} onChange={s} /></Light>; };
