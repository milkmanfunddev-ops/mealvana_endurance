import { WorkoutCard } from '@mealvana/endurance-ds';
import { Phone } from './_frame';
export const Planned = () => <Phone><WorkoutCard title="Drills Day" detail="3 mi · 43 min" status="planned" /></Phone>;
export const Verified = () => <Phone><WorkoutCard title="12 mi Run" detail="5.0 mi · 43 min" status="verified" source="Garmin" /></Phone>;
export const Skipped = () => <Phone><WorkoutCard title="Warm Up" detail="other" status="skipped" fuelLine={null} /></Phone>;
export const SwipeMarkDone = () => <Phone><WorkoutCard title="Drills Day" detail="3 mi · 43 min" status="planned" reveal="done" /></Phone>;
export const SwipeSkip = () => <Phone><WorkoutCard title="Drills Day" detail="3 mi · 43 min" status="planned" reveal="skip" /></Phone>;
