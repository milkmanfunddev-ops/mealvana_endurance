import { PagerDots } from '@mealvana/endurance-ds';
import { Phone } from './_frame';
export const First = () => <Phone><PagerDots count={3} index={0} /></Phone>;
export const Last = () => <Phone><PagerDots count={3} index={2} /></Phone>;
