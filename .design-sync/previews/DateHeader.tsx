import { DateHeader } from '@mealvana/endurance-ds';
import { Phone } from './_frame';

export const Today = () => (
  <Phone><DateHeader title="Today, September 7" /></Phone>
);

export const OtherDay = () => (
  <Phone><DateHeader title="Tuesday, September 1" /></Phone>
);
