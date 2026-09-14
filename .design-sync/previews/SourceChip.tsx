import { SourceChip, StaleChip, TapToUseChip, SourceProvenanceRow } from '@mealvana/endurance-ds';
import { Phone } from './_frame';

const row = { display: 'flex', gap: 10, flexWrap: 'wrap' as const, alignItems: 'center' };

export const Chips = () => (
  <Phone><div style={row}>
    <SourceChip source="Manual" />
    <SourceChip source="TrainingPeaks" />
    <SourceChip source="Garmin" />
    <SourceChip source="Final Surge" />
  </div></Phone>
);

export const ProviderSourced = () => (
  <Phone><SourceProvenanceRow manualValue={240} providerValue={240} unit="W" /></Phone>
);

export const Conflict = () => (
  <Phone><SourceProvenanceRow manualValue={250} providerValue={240} unit="W" onAdoptProvider={() => {}} /></Phone>
);

export const Stale = () => (
  <Phone><SourceProvenanceRow manualValue={240} providerValue={240} stale unit="W" /></Phone>
);

export const TapToUse = () => (
  <Phone><TapToUseChip source="TrainingPeaks" value="240 W" onTap={() => {}} /></Phone>
);

export const CssConflict = () => (
  <Phone><SourceProvenanceRow manualValue={95} providerValue={92} unit="s/100m" onAdoptProvider={() => {}} /></Phone>
);

export const BodyComp = () => (
  <Phone><SourceProvenanceRow manualValue={154} providerValue={152} providerName="Garmin" unit="lb" onAdoptProvider={() => {}} /></Phone>
);

export const StaleTag = () => (
  <Phone><div style={row}><SourceChip source="TrainingPeaks" /><StaleChip /></div></Phone>
);
