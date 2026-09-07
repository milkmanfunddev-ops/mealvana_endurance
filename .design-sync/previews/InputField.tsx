import { useState } from 'react';
import { InputField } from '@mealvana/endurance-ds';
import { Phone, Light } from './_frame';

export const Text = () => { const [v, s] = useState('Sunday long run'); return <Phone><InputField value={v} onChange={s} label="Activity name" /></Phone>; };
export const Placeholder = () => { const [v, s] = useState(''); return <Phone><InputField value={v} onChange={s} placeholder="Activity name" label="Activity name" /></Phone>; };
export const NumericWithUnit = () => { const [v, s] = useState('72'); return <Phone><div className="me-descriptor">Body weight</div><InputField numeric suffix="kg" value={v} onChange={s} label="Body weight" /></Phone>; };
export const Disabled = () => <Phone><InputField disabled value="Boston Marathon" onChange={() => {}} label="Event" /></Phone>;
export const OnLight = () => { const [v, s] = useState('90'); return <Light><InputField dark={false} numeric suffix="min" value={v} onChange={s} label="Duration" /></Light>; };
