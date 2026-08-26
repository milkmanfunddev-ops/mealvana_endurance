import { useState } from 'react';
import { Stepper } from '@mealvana/endurance-ds';
import { Phone, Light } from './_frame';

export const Carbs = () => { const [v, s] = useState(97); return <Phone><div><Stepper value={v} onChange={s} step={5} unit="g" /></div></Phone>; };
export const Fluids = () => { const [v, s] = useState(444); return <Phone><div><Stepper value={v} onChange={s} step={50} unit="ml" max={2000} /></div></Phone>; };
export const OnLight = () => { const [v, s] = useState(23); return <Light><div><Stepper dark={false} value={v} onChange={s} unit="g" /></div></Light>; };
