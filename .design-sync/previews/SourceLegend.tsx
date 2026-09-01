import { SourceLegend } from '@mealvana/endurance-ds';
import { Phone } from './_frame';
export const Burn = () => <Phone><SourceLegend /></Phone>;
export const Planned = () => <Phone><SourceLegend labels={{ verified: 'verified · Garmin', 'self-reported': 'self-reported', planned: 'planned (estimate)' }} /></Phone>;
