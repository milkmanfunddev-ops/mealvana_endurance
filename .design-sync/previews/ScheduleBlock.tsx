import { ScheduleBlock } from '@mealvana/endurance-ds';
import { Phone } from './_frame';
export const Run = () => <Phone><ScheduleBlock label="Run scheduled for" stats={['5.0 mi', '43m', '9:00 /mi']} date="Aug 25, 2026" time="5:57am" device="Garmin Forerunner 955" /></Phone>;
export const NoDevice = () => <Phone><ScheduleBlock label="Ride scheduled for" stats={['28 mi', '1h 30m']} date="Aug 27, 2026" time="6:30am" /></Phone>;
