import { DetailHeader } from '@mealvana/endurance-ds';
import { Phone } from './_frame';
export const WithActions = () => <Phone><DetailHeader title="12 mi Run" actions={[{ icon: 'penToSquare', label: 'Edit' }, { icon: 'trash', label: 'Delete', tone: 'destructive' }]} /></Phone>;
export const BackOnly = () => <Phone><DetailHeader title="Adjust Your Macros" /></Phone>;
