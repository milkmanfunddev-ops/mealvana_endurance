import { useState } from 'react';
import { Switch } from '@mealvana/endurance-ds';
import { Phone, Light } from './_frame';

const Row = ({ label, init, dark = true }: { label: string; init: boolean; dark?: boolean }) => {
  const [v, s] = useState(init);
  return (<label style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 24 }}><span className="me-body">{label}</span><Switch value={v} onChange={s} label={label} dark={dark} /></label>);
};
export const On = () => <Phone><Row label="Carb loading" init /></Phone>;
export const Off = () => <Phone><Row label="Caffeine in gels" init={false} /></Phone>;
export const Disabled = () => <Phone><label style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}><span className="me-body" style={{ opacity: 0.5 }}>Garmin sync</span><Switch value disabled onChange={() => {}} label="Garmin sync" /></label></Phone>;
export const OnLight = () => <Light><Row dark={false} label="Dark mode" init={false} /></Light>;
