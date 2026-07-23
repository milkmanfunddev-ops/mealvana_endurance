import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';

/// Brick Phase Breakdown Widget
///
/// Displays expandable phase-by-phase macro breakdown for brick workouts.
/// Shows macros for: Before, During-Swim, T1 Transition, During-Bike, T2 Transition, During-Run, After.
///
/// Design specs from /docs/brick/ui-flow.md:
/// - Expandable section (collapsed by default)
/// - Each phase shows: Carbs, Protein (if applicable), Sodium, Water targets
/// - Phases displayed in workout order
class BrickPhaseBreakdown extends StatefulWidget {
  const BrickPhaseBreakdown({
    super.key,
    required this.phases,
    this.onEditPhase,
  });

  /// Map of phase data: phase_id -> {carbs, protein, sodium, water}
  /// Example phase IDs: 'before', 'during_segment_1', 'T1', 'during_segment_2', 'T2', 'during_segment_3', 'after'
  final Map<String, BrickPhaseData> phases;

  /// Optional callback when user wants to edit a specific phase
  final void Function(String phaseId)? onEditPhase;

  @override
  State<BrickPhaseBreakdown> createState() => _BrickPhaseBreakdownState();
}

class _BrickPhaseBreakdownState extends State<BrickPhaseBreakdown> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 17),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with expand/collapse
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isExpanded ? 'Phase Breakdown' : 'View Phase Breakdown',
                  style: AppTextStyles.sectionTitle.copyWith(
                    fontSize: 14,
                    color: AppColors.orange,
                  ),
                ),
                Icon(
                  _isExpanded
                      ? FontAwesomeIcons.chevronUp.data
                      : FontAwesomeIcons.chevronDown.data,
                  size: 14,
                  color: AppColors.orange,
                ),
              ],
            ),
          ),

          // Expandable phase details
          if (_isExpanded) ...[
            const SizedBox(height: 16),
            ..._buildPhases(context),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildPhases(BuildContext context) {
    final sortedPhases = _sortPhases(widget.phases.keys.toList());
    final phaseWidgets = <Widget>[];

    for (int i = 0; i < sortedPhases.length; i++) {
      final phaseId = sortedPhases[i];
      final phaseData = widget.phases[phaseId]!;

      if (i > 0) {
        phaseWidgets.add(const SizedBox(height: 16));
      }

      phaseWidgets.add(_buildPhaseRow(context, phaseId, phaseData));
    }

    return phaseWidgets;
  }

  Widget _buildPhaseRow(
    BuildContext context,
    String phaseId,
    BrickPhaseData data,
  ) {
    final phaseName = _getPhaseDisplayName(phaseId);
    final phaseNote = _getPhaseNote(phaseId, data);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Phase name
        Text(
          phaseName.toUpperCase(),
          style: AppTextStyles.sectionTitle.copyWith(
            fontSize: 12,
            letterSpacing: 1.2,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 6),

        // Macro values
        Text(
          _formatMacros(data),
          style: AppTextStyles.bodyLarge.copyWith(
            fontFamily: 'Apercu',
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),

        // Phase-specific note (e.g., "no eating during swim")
        if (phaseNote != null) ...[
          const SizedBox(height: 4),
          Text(
            phaseNote,
            style: AppTextStyles.bodyLarge.copyWith(
              fontFamily: 'Apercu',
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }

  String _formatMacros(BrickPhaseData data) {
    final parts = <String>[];

    if (data.carbsG != null && data.carbsG! > 0) {
      parts.add('Carbs: ${data.carbsG}g');
    }

    if (data.proteinG != null && data.proteinG! > 0) {
      parts.add('Protein: ${data.proteinG}g');
    }

    if (data.sodiumMg != null && data.sodiumMg! > 0) {
      parts.add('Sodium: ${data.sodiumMg}mg');
    }

    if (data.waterMl != null && data.waterMl! > 0) {
      parts.add('Water: ${data.waterMl}ml');
    }

    return parts.isEmpty ? 'No nutrition' : parts.join(' | ');
  }

  String _getPhaseDisplayName(String phaseId) {
    if (phaseId == 'before') return 'Before';
    if (phaseId == 'after') return 'After';
    if (phaseId == 'T1') return 'T1 Transition';
    if (phaseId == 'T2') return 'T2 Transition';

    // Handle during_segment_X
    if (phaseId.startsWith('during_segment_')) {
      final segmentNum = phaseId.split('_').last;
      // Note: To get proper sport name, we'd need the segment data
      // For now, use generic label
      return 'During Segment $segmentNum';
    }

    return phaseId;
  }

  String? _getPhaseNote(String phaseId, BrickPhaseData data) {
    // Swimming phase typically has 0 carbs
    if (phaseId.contains('swim') ||
        (data.carbsG == 0 && phaseId.startsWith('during'))) {
      return '(no eating during swim)';
    }
    return null;
  }

  /// Sort phases in logical workout order:
  /// before → during_segment_1 → T1 → during_segment_2 → T2 → during_segment_3 → after
  List<String> _sortPhases(List<String> phases) {
    final order = <String, int>{
      'before': 0,
      'during_segment_1': 1,
      'T1': 2,
      'during_segment_2': 3,
      'T2': 4,
      'during_segment_3': 5,
      'after': 6,
    };

    phases.sort((a, b) {
      final aOrder = order[a] ?? 99;
      final bOrder = order[b] ?? 99;
      return aOrder.compareTo(bOrder);
    });

    return phases;
  }
}

/// Data for a single phase in a brick workout
class BrickPhaseData {
  const BrickPhaseData({
    this.carbsG,
    this.proteinG,
    this.sodiumMg,
    this.waterMl,
  });

  final int? carbsG;
  final int? proteinG;
  final int? sodiumMg;
  final int? waterMl;

  factory BrickPhaseData.fromJson(Map<String, dynamic> json) {
    return BrickPhaseData(
      carbsG: json['carbs_g'] as int?,
      proteinG: json['protein_g'] as int?,
      sodiumMg: json['sodium_mg'] as int?,
      waterMl: json['water_ml'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (carbsG != null) 'carbs_g': carbsG,
      if (proteinG != null) 'protein_g': proteinG,
      if (sodiumMg != null) 'sodium_mg': sodiumMg,
      if (waterMl != null) 'water_ml': waterMl,
    };
  }
}
