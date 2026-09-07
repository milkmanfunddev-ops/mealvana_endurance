import { Banner } from '@mealvana/endurance-ds';
import { Phone } from './_frame';
export const Pins = () => <Phone><Banner title="Some pins honored, some skipped" detail="3 honored · 1 skipped" onExpand={() => {}} /></Phone>;
export const Electrolyte = () => <Phone><Banner color="var(--me-electrolyte)" icon="circleCheck" title="Synced with Garmin" detail="Updated 2 min ago" /></Phone>;
export const Warning = () => <Phone><Banner color="var(--me-dragonfruit)" icon="triangleExclamation" title="Sodium above the safe range" detail="1,404 mg max for this session" onExpand={() => {}} /></Phone>;
