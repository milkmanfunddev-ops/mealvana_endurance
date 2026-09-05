import { FeedingCard } from '@mealvana/endurance-ds';
import { Phone } from './_frame';

const rows = [
  { id: 'banana', name: 'Banana', detail: '27g carbs', quantity: 1, step: 0.5, cap: 3, icon: 'appleWhole' as const, iconColor: 'var(--me-orange)' },
  { id: 'water', name: 'Water (cups)', detail: '8 oz', note: 'ADDED FOR HYDRATION', quantity: 1.5, step: 0.5, cap: 8, icon: 'droplet' as const, iconColor: 'var(--me-electrolyte-dark)' },
];

export const Collapsed = () => <Phone><FeedingCard title="Pre-Workout Snack" windowLabel="60 – 15 MIN BEFORE" foodsLine="Banana · Water (cups)" carbsDelivered={52} fluidOz={12} rows={rows} /></Phone>;
export const Expanded = () => <Phone><FeedingCard title="Pre-Workout Snack" windowLabel="60 – 15 MIN BEFORE" carbsDelivered={52} fluidOz={12} rows={rows} initiallyExpanded /></Phone>;
export const ZeroCarbFluid = () => <Phone><FeedingCard title="Top-Off" windowLabel="LAST 15 MIN" carbsDelivered={0} fluidOz={4} rows={[{ id: 'water2', name: 'Water (cups)', detail: '4 oz', quantity: 0.5, step: 0.5, cap: 4, icon: 'droplet' as const, iconColor: 'var(--me-electrolyte-dark)' }]} initiallyExpanded /></Phone>;
