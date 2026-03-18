import 'package:flutter/material.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../application/macro_explanation_service.dart';
import '../../../domain/macro_targets.dart';

/// Bottom sheet that explains how nutrition targets were calculated for a given phase.
///
/// Shows personalized calculation breakdowns per macro with formula,
/// range rationale, and source citations. Follows the existing
/// HelpBottomSheetWidget DraggableScrollableSheet pattern.
class PhaseExplanationSheet extends StatefulWidget {
  const PhaseExplanationSheet({
    super.key,
    required this.phase,
    required this.macroTargets,
    required this.bodyWeightKg,
    this.sportLabel,
    this.useImperial = false,
  });

  final ExplanationPhase phase;
  final MacroTargets macroTargets;
  final double bodyWeightKg;
  final String? sportLabel;
  final bool useImperial;

  /// Show the explanation sheet as a modal bottom sheet.
  static void show(
    BuildContext context, {
    required ExplanationPhase phase,
    required MacroTargets macroTargets,
    required double bodyWeightKg,
    String? sportLabel,
    bool useImperial = false,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PhaseExplanationSheet(
        phase: phase,
        macroTargets: macroTargets,
        bodyWeightKg: bodyWeightKg,
        sportLabel: sportLabel,
        useImperial: useImperial,
      ),
    );
  }

  @override
  State<PhaseExplanationSheet> createState() => _PhaseExplanationSheetState();
}

class _PhaseExplanationSheetState extends State<PhaseExplanationSheet> {
  final _service = const MacroExplanationService();
  String? _expandedMacro;

  @override
  void initState() {
    super.initState();
    // Default: first macro expanded
    final explanations = _service.getExplanations(
      phase: widget.phase,
      macroTargets: widget.macroTargets,
      bodyWeightKg: widget.bodyWeightKg,
      useImperial: widget.useImperial,
    );
    if (explanations.isNotEmpty) {
      _expandedMacro = explanations.first.macroName;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _service.getSheetTitle(widget.phase, widget.sportLabel);
    final explanations = _service.getExplanations(
      phase: widget.phase,
      macroTargets: widget.macroTargets,
      bodyWeightKg: widget.bodyWeightKg,
      useImperial: widget.useImperial,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              title,
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...explanations.map((explanation) => _buildExplanationCard(
                          context,
                          explanation,
                        )),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanationCard(
    BuildContext context,
    MacroExplanation explanation,
  ) {
    final isExpanded = _expandedMacro == explanation.macroName;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded
              ? AppColors.electrolyte.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _expandedMacro =
                _expandedMacro == explanation.macroName ? null : explanation.macroName;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      explanation.displayHeader,
                      style: AppTextStyles.subtitle.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),

              // Expanded content
              if (isExpanded) ...[
                const SizedBox(height: 12),
                // Formula / explanation
                Text(
                  explanation.formulaText,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                // Range rationale in a subtle container
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.electrolyte.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    explanation.rangeRationale,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.electrolyte,
                      height: 1.4,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
