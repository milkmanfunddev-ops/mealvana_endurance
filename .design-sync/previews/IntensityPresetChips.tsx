import { IntensityPresetChips } from '@mealvana/endurance-ds';
import { Phone } from './_frame';

const running = [
  { value: 'easy', label: 'Easy Run' },
  { value: 'long', label: 'Long Run' },
  { value: 'tempo', label: 'Tempo Run' },
  { value: 'intervals', label: 'Intervals' },
  { value: 'racePace', label: 'Race Pace' },
  { value: 'recovery', label: 'Recovery Run' },
];

export const Selected = () => <Phone><IntensityPresetChips chips={running} selected="long" /></Phone>;
export const Unselected = () => <Phone><IntensityPresetChips chips={running} /></Phone>;
export const Disabled = () => <Phone><IntensityPresetChips chips={running} selected="long" enabled={false} /></Phone>;
