import { StatusPill } from '@mealvana/endurance-ds';
import { Phone } from './_frame';
export const States = () => <Phone><div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}><StatusPill status="planned" /><StatusPill status="verified" source="Garmin" /><StatusPill status="done" /><StatusPill status="skipped" /></div></Phone>;
