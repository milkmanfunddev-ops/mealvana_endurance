import { BreakdownTable } from '@mealvana/endurance-ds';
import { Phone } from './_frame';
export const EnergyBurned = () => (
  <Phone><BreakdownTable title="Energy burned" rows={[
    { name: 'Resting', source: 'estimated', sourceLabel: 'estimated', soFar: '808', byEnd: '1,064' },
    { name: 'Workout', source: 'verified', sourceLabel: 'verified · Garmin', soFar: '+411', byEnd: '+930' },
    { name: 'Daily movement', source: 'verified', sourceLabel: 'verified · Garmin', soFar: '+193', byEnd: '+275' },
    { name: 'Digestion', source: 'estimated', sourceLabel: 'estimated', soFar: '+110', byEnd: '+193' },
  ]} total={{ label: 'Total burned', soFar: '1,522', byEnd: '2,462' }} /></Phone>
);
