import { PrimaryButton, Icon } from '@mealvana/endurance-ds';
import { Phone, Light } from './_frame';

export const GeneratePlan = () => <Phone><div><PrimaryButton>Generate Plan</PrimaryButton></div></Phone>;
export const FullWidth = () => <Phone><PrimaryButton full>Complete Workout</PrimaryButton></Phone>;
export const WithIcon = () => <Phone><div><PrimaryButton icon={<Icon name="plus" size={14} />}>Create Plan</PrimaryButton></div></Phone>;
export const Small = () => <Phone><div><PrimaryButton size="sm">Save</PrimaryButton></div></Phone>;
export const Disabled = () => <Phone><div><PrimaryButton disabled>Generate Plan</PrimaryButton></div></Phone>;
export const OnLight = () => <Light><PrimaryButton full>Generate Plan</PrimaryButton></Light>;
