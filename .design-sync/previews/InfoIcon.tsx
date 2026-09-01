import { InfoIcon } from '@mealvana/endurance-ds';
import { Phone } from './_frame';
export const Inline = () => <Phone><div className="me-body-lg" style={{ display: 'flex', alignItems: 'center', gap: 10 }}>Resting <InfoIcon label="resting energy" /> <span style={{ marginLeft: 20 }}>Total burned</span> <InfoIcon label="total burned" color="var(--me-electrolyte)" /></div></Phone>;
