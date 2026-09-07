import { StackedBar } from '@mealvana/endurance-ds';
import { Phone } from './_frame';
export const DonePlannedRemaining = () => <Phone><StackedBar segments={[{ value: 411, kind: 'done', label: '411 done' }, { value: 519, kind: 'planned', label: '519 planned' }, { value: 120, kind: 'remaining' }]} /></Phone>;
export const AllDone = () => <Phone><StackedBar segments={[{ value: 930, kind: 'done', label: '930 done' }]} /></Phone>;
