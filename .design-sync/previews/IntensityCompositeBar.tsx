import { IntensityCompositeBar } from '@mealvana/endurance-ds';
import { Phone } from './_frame';

export const Mixed = () => <Phone><IntensityCompositeBar conversationalPct={70} tempoPct={25} allOutPct={5} /></Phone>;
export const AllConversational = () => <Phone><IntensityCompositeBar conversationalPct={100} tempoPct={0} allOutPct={0} /></Phone>;
export const RaceDay = () => <Phone><IntensityCompositeBar conversationalPct={10} tempoPct={40} allOutPct={50} /></Phone>;
export const Disabled = () => <Phone><IntensityCompositeBar conversationalPct={70} tempoPct={25} allOutPct={5} enabled={false} /></Phone>;
