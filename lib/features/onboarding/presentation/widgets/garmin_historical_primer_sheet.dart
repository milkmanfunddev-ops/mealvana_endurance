import 'package:flutter/material.dart';

import '../../../../shared/widgets/kyle_design/materials/glass.dart';
import '../theme/onboarding_design_tokens.dart';

/// Onboarding-only primer shown the moment a user taps "Connect" on the
/// Garmin row during onboarding, just before Garmin's hosted OAuth/consent
/// screen opens.
///
/// Why it exists: Garmin's consent screen defaults the "Historical Data"
/// toggle OFF, and that toggle controls the `HISTORICAL_DATA_EXPORT`
/// permission that authorizes backfill of a user's PAST workouts — which we
/// use to build the first plan from real training instead of an average
/// (verified live 2026-09-13; ops
/// 2026-09-13-garmin-historical-data-off-by-default). We can't change
/// Garmin's default, so we prime the user to switch it on. Onboarding only:
/// the history insight is only computed during onboarding, so there is no
/// settings-side or post-connect variant.
///
/// Returns true if the athlete chose to continue to Garmin, false/null if
/// they dismissed ("Not now").
Future<bool?> showGarminHistoricalPrimer(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _GarminHistoricalPrimerSheet(),
  );
}

class _GarminHistoricalPrimerSheet extends StatelessWidget {
  const _GarminHistoricalPrimerSheet();

  @override
  Widget build(BuildContext context) {
    // The ratified glass sheet material (home-shell@v1 §Materials) — backdrop
    // blur + veil + gradient fill + specular rim, not a flat card fill.
    return GlassSheetSurface(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Grabber.
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: OnbTokens.creamA(0.25),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'ONE QUICK STEP',
            style: TextStyle(
              fontFamily: OnbTokens.fontBody,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: OnbTokens.teal,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Turn on Historical Data',
            style: TextStyle(
              fontFamily: OnbTokens.fontDisplay,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: OnbTokens.cream,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'So your first plan is built on your real training, not an average.',
            style: TextStyle(
              fontFamily: OnbTokens.fontBody,
              fontSize: 15,
              height: 1.35,
              color: OnbTokens.creamA(0.7),
            ),
          ),
          const SizedBox(height: 20),
          const _GarminToggleMock(),
          const SizedBox(height: 16),
          Text(
            'Just your workouts. Change it in Garmin anytime.',
            style: TextStyle(
              fontFamily: OnbTokens.fontBody,
              fontSize: 12.5,
              height: 1.3,
              color: OnbTokens.creamA(0.5),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('garmin_primer.continue'),
              style: FilledButton.styleFrom(
                backgroundColor: OnbTokens.orange,
                foregroundColor: OnbTokens.bg,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(OnbTokens.rPill),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Continue to Garmin',
                style: TextStyle(
                  fontFamily: OnbTokens.fontDisplay,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              key: const ValueKey('garmin_primer.not_now'),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Not now',
                style: TextStyle(
                  fontFamily: OnbTokens.fontBody,
                  fontSize: 14,
                  color: OnbTokens.creamA(0.6),
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}

/// A small facsimile of Garmin's consent toggles, with the Historical Data
/// row highlighted as the one to switch on. The visual carries the
/// instruction so the copy can stay short.
class _GarminToggleMock extends StatelessWidget {
  const _GarminToggleMock();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OnbTokens.cream,
        borderRadius: BorderRadius.circular(OnbTokens.rChip),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'connect.garmin.com',
            style: TextStyle(
              fontFamily: OnbTokens.fontBody,
              fontSize: 11,
              color: OnbTokens.bg.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 10),
          const _MockRow(label: 'Activities', on: true),
          const SizedBox(height: 8),
          const _MockRow(label: 'Daily Health Stats', on: true),
          const SizedBox(height: 8),
          const _MockRow(
            label: 'Historical Data',
            on: true,
            highlight: true,
            annotation: 'Turn this on',
          ),
        ],
      ),
    );
  }
}

class _MockRow extends StatelessWidget {
  const _MockRow({
    required this.label,
    required this.on,
    this.highlight = false,
    this.annotation,
  });

  final String label;
  final bool on;
  final bool highlight;
  final String? annotation;

  @override
  Widget build(BuildContext context) {
    // Garmin's toggle blue; the highlighted row rings the toggle in orange.
    const garminBlue = Color(0xFF2481F9);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: OnbTokens.fontBody,
              fontSize: 13,
              color: OnbTokens.bg,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            border: highlight
                ? Border.all(color: OnbTokens.orange, width: 2)
                : null,
          ),
          child: Container(
            width: 40,
            height: 24,
            decoration: BoxDecoration(
              color: garminBlue,
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(right: 2),
                child: CircleAvatar(radius: 10, backgroundColor: Colors.white),
              ),
            ),
          ),
        ),
        if (annotation != null) ...[
          const SizedBox(width: 8),
          Text(
            annotation!,
            style: const TextStyle(
              fontFamily: OnbTokens.fontDisplay,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: OnbTokens.orange,
            ),
          ),
        ],
      ],
    );
  }
}
