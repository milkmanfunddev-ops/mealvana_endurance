import { NetBalanceCard } from '@mealvana/endurance-ds';
import { Phone } from './_frame';
export const Deficit = () => <Phone><NetBalanceCard value={-415} status="slight deficit" /></Phone>;
export const OnTrack = () => <Phone><NetBalanceCard value={-133} status="on track" statusColor="var(--me-electrolyte)" /></Phone>;
export const Surplus = () => <Phone><NetBalanceCard value={210} status="surplus" /></Phone>;
