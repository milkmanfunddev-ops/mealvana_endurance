import { EnergyRow } from '@mealvana/endurance-ds';
import { Phone } from './_frame';
export const Planned = () => <Phone><EnergyRow title="Drills Day" detail="5:57 AM · 3 mi · 43 min" kcal={397} status="planned" source="planned" sourceLabel="planned (estimate)" /></Phone>;
export const Verified = () => <Phone><EnergyRow title="12 mi Run" detail="5:57 AM · 5.0 mi · 43 min" kcal={411} status="verified" source="verified" sourceLabel="verified · Garmin · as planned" /></Phone>;
