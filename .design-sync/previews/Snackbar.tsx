import { Snackbar } from '@mealvana/endurance-ds';
import { Phone } from './_frame';

export const Success = () => <Phone><Snackbar type="success" message="Plan saved" actionLabel="Undo" onAction={() => {}} style={{ margin: 0 }} /></Phone>;
export const Error = () => <Phone><Snackbar type="error" message="Could not reach the server. Your changes are saved offline." actionLabel="Retry" onAction={() => {}} style={{ margin: 0 }} /></Phone>;
export const Warning = () => <Phone><Snackbar type="warning" message="Garmin token expires in 3 days" style={{ margin: 0 }} /></Phone>;
export const Info = () => <Phone><Snackbar type="info" message="Syncing activities…" style={{ margin: 0 }} /></Phone>;
