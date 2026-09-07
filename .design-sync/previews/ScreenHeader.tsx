import { ScreenHeader } from '@mealvana/endurance-ds';

export const Default = () => <div style={{ width: 375, background: 'var(--me-blackberry)' }}><ScreenHeader title="Activity Details" /></div>;
export const LongTitle = () => <div style={{ width: 375, background: 'var(--me-blackberry)' }}><ScreenHeader title="Adjust Your Macros" /></div>;
export const OnLight = () => <div className="on-light" style={{ width: 375 }}><ScreenHeader dark={false} title="New Activity" /></div>;
