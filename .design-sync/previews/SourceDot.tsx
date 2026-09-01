import { SourceDot, SourceLegend } from '@mealvana/endurance-ds';
import { Phone } from './_frame';
export const Dots = () => <Phone><div style={{ display: 'flex', gap: 18, alignItems: 'center' }}><SourceDot source="verified" size={16} /><SourceDot source="self-reported" size={16} /><SourceDot source="estimated" size={16} /></div></Phone>;
