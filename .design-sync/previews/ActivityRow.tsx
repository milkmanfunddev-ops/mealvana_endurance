import { ActivityRow } from '@mealvana/endurance-ds';
import { Phone, Light } from './_frame';

export const Verified = () => <Phone><ActivityRow sport="swim" title="Swim" detail="2,000 yd · 40 min" verified="Garmin" fuelLine="Pre · During · Recovery fuel >" /></Phone>;
export const Planned = () => <Phone><ActivityRow sport="run" title="Sunday Long Run" detail="1.8 h · 12 mi" fuelLine="Pre · During · Recovery fuel >" /></Phone>;
export const Upcoming = () => <Phone><ActivityRow sport="run" title="Boston Marathon" detail="26.2 mi · 9:00/mi" daysAway="12 days away" /></Phone>;
export const List = () => (
  <Phone>
    <ActivityRow sport="bike" title="Tempo Ride" detail="1.5 h · 28 mi" daysAway="Today" />
    <ActivityRow sport="strength" title="Strength" detail="45 min" daysAway="3 days" />
  </Phone>
);
export const OnLight = () => <Light><ActivityRow dark={false} sport="swim" title="Swim" detail="2,000 yd · 40 min" verified="Garmin" /></Light>;
