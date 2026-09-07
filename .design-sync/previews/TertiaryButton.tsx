import { TertiaryButton, Icon } from '@mealvana/endurance-ds';
import { Phone, Light } from './_frame';

export const Remove = () => <Phone><div><TertiaryButton>× Remove Food Item</TertiaryButton></div></Phone>;
export const Add = () => <Phone><div><TertiaryButton tone="electrolyte" icon={<Icon name="plus" size={11} />}>Add Food</TertiaryButton></div></Phone>;
export const Underlined = () => <Phone><div><TertiaryButton underlined>Swap Food Item</TertiaryButton></div></Phone>;
export const Disabled = () => <Phone><div><TertiaryButton disabled>× Remove</TertiaryButton></div></Phone>;
export const OnLight = () => <Light><div><TertiaryButton dark={false}>× Remove Food Item</TertiaryButton></div></Light>;
