import 'package:flutter/material.dart';

import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';

/// Design SSOT component — **source provenance chip family** (D-2).
///
/// Spec: `docs/ssot/spec/design/surfaces/integrations-data-display.md`
/// D-2 / D-2b / D-2c (RATIFIED Xuan 2026-09-11; Q-DID2 variant A — chip is
/// SOURCE ONLY, no relative time). Rendering:
/// `docs/ssot/spec/design/renderings/ftp-source-provenance@v1.html`
/// (pill: Apercu italic 600 12, 1px border, transparent fill, 4x10 padding;
/// Manual = cream, provider = electrolyte).
///
/// ONE parameterized implementation for every application, per the
/// data-integrations handoff's component-reuse rule: FTP/CSS
/// (Manual · TrainingPeaks, 24 h stale window), Body Composition
/// (Manual · Garmin, 30 d window), Events (Manual · TrainingPeaks ·
/// Final Surge, no window) — three call sites, one chip. The stale tag and
/// the tap-to-use affordance are likewise single widgets here. Proposed
/// spec stub: `spec/design/components/source-chip.md`.
class KyleSourceChip extends StatelessWidget {
  const KyleSourceChip({
    super.key,
    required this.source,
    this.value,
  });

  /// Source display name ('Manual', 'TrainingPeaks', 'Garmin',
  /// 'Final Surge'). 'Manual' renders cream; every provider renders
  /// electrolyte.
  final String source;

  /// Optional value suffix shown ONLY in a conflict pairing
  /// (e.g. '250 W' -> "Manual · 250 W").
  final String? value;

  bool get _isManual => source == 'Manual';

  @override
  Widget build(BuildContext context) {
    final ink = _isManual ? AppColors.cream : AppColors.electrolyte;
    final label = value == null ? source : '$source · $value';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: ink),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTextStyles.apercu,
          fontSize: 12,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
    );
  }
}

/// The "stale" tag: shown when the source value is older than the
/// surface's ruled window (FTP/CSS: the 24 h zones clock; body comp: 30 d).
class KyleStaleChip extends StatelessWidget {
  const KyleStaleChip({super.key});

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.cream.withValues(alpha: 0.5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.cream.withValues(alpha: 0.12)),
      ),
      child: Text(
        'stale',
        style: TextStyle(
          fontFamily: AppTextStyles.apercu,
          fontSize: 11,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
    );
  }
}

/// The tap-to-use affordance for a conflict: adopts the provider's value in
/// a single tap ("TrainingPeaks · 240 W — tap to use"). NEVER a modal —
/// the ruled conflict treatment is inline (variant A).
class KyleTapToUseChip extends StatelessWidget {
  const KyleTapToUseChip({
    super.key,
    required this.source,
    required this.value,
    required this.onTap,
  });

  final String source;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        '$source · $value — tap to use',
        style: const TextStyle(
          fontFamily: AppTextStyles.apercu,
          fontSize: 12,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
          color: AppColors.electrolyte,
        ),
      ),
    );
  }
}

/// The D-2 provenance ROW: the ruled composition of the chip family for a
/// value field (variant A, manual-wins, inline conflict, NO modal).
/// Parameterized per surface: FTP/CSS use provider 'TrainingPeaks' with the
/// 24 h zones window; body composition uses 'Garmin' with the 30 d window;
/// events use their per-row origin with no window.
class KyleSourceProvenanceRow extends StatelessWidget {
  const KyleSourceProvenanceRow({
    super.key,
    required this.manualValue,
    required this.providerValue,
    required this.onAdoptProvider,
    this.providerName = 'TrainingPeaks',
    this.stale = false,
    this.unit = '',
  });

  final int? manualValue;
  final int? providerValue;
  final String providerName;
  final bool stale;
  final String unit;
  final void Function(int) onAdoptProvider;

  @override
  Widget build(BuildContext context) {
    if (manualValue == null && providerValue == null) {
      return const SizedBox.shrink();
    }

    final conflict = manualValue != null &&
        providerValue != null &&
        manualValue != providerValue;
    final providerSourced = providerValue != null &&
        (manualValue == null || manualValue == providerValue);

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (conflict) ...[
          KyleSourceChip(source: 'Manual', value: '$manualValue $unit'),
          KyleTapToUseChip(
            source: providerName,
            value: '$providerValue $unit',
            onTap: () => onAdoptProvider(providerValue!),
          ),
        ] else if (providerSourced)
          KyleSourceChip(source: providerName)
        else
          const KyleSourceChip(source: 'Manual'),
        if (stale && providerValue != null) const KyleStaleChip(),
      ],
    );
  }
}

