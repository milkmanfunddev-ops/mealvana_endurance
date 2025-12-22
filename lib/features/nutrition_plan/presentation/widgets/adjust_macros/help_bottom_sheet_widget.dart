import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../providers/macro_targets_controller.dart';

/// Help Bottom Sheet with Nutrition Science Guidelines
/// Shows detailed information about how we calculate each macro
class HelpBottomSheetWidget extends ConsumerStatefulWidget {
  const HelpBottomSheetWidget({
    super.key,
    required this.state,
  });

  final MacroTargetsState state;

  @override
  ConsumerState<HelpBottomSheetWidget> createState() => _HelpBottomSheetWidgetState();
}

class _HelpBottomSheetWidgetState extends ConsumerState<HelpBottomSheetWidget> {
  String? _expandedSection = 'Carbohydrates'; // Default expanded

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.98,
      minChildSize: 0.5,
      maxChildSize: 0.98,
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Title
            Text(
              'Nutrition Guidelines',
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
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
                    // Carbohydrates
                    _buildAccordionSection(
                      title: 'Carbohydrates',
                      content: '**How we calculate it:** Duration establishes a safe **absorption band**. We adjust for **intensity (MET)**, **gut training**, **body size**, and fuel mix—then **cap** based on what your gut can process.\n\nReplenish with high-quality carbs immediately after exercise to jumpstart recovery and restore glycogen.',
                      isExpanded: _expandedSection == 'Carbohydrates',
                      onTap: () {
                        setState(() {
                          _expandedSection = _expandedSection == 'Carbohydrates' ? null : 'Carbohydrates';
                        });
                      },
                    ),

                    // Sodium
                    _buildAccordionSection(
                      title: 'Sodium',
                      content: '**How we calculate it:** If you know your **sweat rate**, we estimate hourly sodium loss (**sweat sodium × sweat rate**) and target **~50–70%** of that (clamped at **300–1200 mg/h**). If not, we determine needs based on your **sweater type** (low/medium/high) and adjust for **heat/humidity**.\n\nInclude sodium in your **pre-run** and **post-run** drinks to enhance fluid retention and improve rehydration.',
                      isExpanded: _expandedSection == 'Sodium',
                      onTap: () {
                        setState(() {
                          _expandedSection = _expandedSection == 'Sodium' ? null : 'Sodium';
                        });
                      },
                    ),

                    // Fluids
                    _buildAccordionSection(
                      title: 'Fluids',
                      content: '**How we calculate it:** We begin with a running-friendly range (**~0.4–0.8 L/h**), adjust for **body size** and **intensity (MET)**, then modify based on **weather** (less in cool conditions, more in hot/humid). For those with a **measured sweat rate**, we target **~70–80%** of that rate, staying within the safe range to prevent overhydration.\n\nPost-run, replenish approximately **125%** of your **estimated fluid deficit** using a drink containing **~500–700 mg/L sodium**.',
                      isExpanded: _expandedSection == 'Fluids',
                      onTap: () {
                        setState(() {
                          _expandedSection = _expandedSection == 'Fluids' ? null : 'Fluids';
                        });
                      },
                    ),

                    // Protein
                    _buildAccordionSection(
                      title: 'Protein',
                      content: '**How we calculate it:**\n\n- **Pre-run:** small amount, **~0.15–0.25 g/kg** (varies with timing) for satiety without digestive discomfort.\n- **During:** **0 g/h** for runs ≤3.5 h (minimal amounts only for ultramarathons).\n- **After:** **~0.3 g/kg** within the first hour; 20–40 g high-quality protein containing **~2–3 g leucine**.\n\nRemember: "carbs first, protein **right after**" for optimal recovery.',
                      isExpanded: _expandedSection == 'Protein',
                      onTap: () {
                        setState(() {
                          _expandedSection = _expandedSection == 'Protein' ? null : 'Protein';
                        });
                      },
                    ),

                    // Fats
                    _buildAccordionSection(
                      title: 'Fats',
                      content: '**How we calculate it:**\n\n- **Pre-run:** modest intake, **~0.1–0.2 g/kg** (reduce fiber/fat closer to start time).\n- **During:** **0–2 g/h** maximum (minimized to protect gut function).\n- **After:** approximately **~0.2 g/kg** as part of your recovery meal—supports satiety and overall energy intake.\n\nPrioritize **unsaturated fats** (e.g., olive oil, nuts) in your recovery meals.',
                      isExpanded: _expandedSection == 'Fats',
                      onTap: () {
                        setState(() {
                          _expandedSection = _expandedSection == 'Fats' ? null : 'Fats';
                        });
                      },
                    ),

                    const SizedBox(height: 24),

                    // Key References section
                    BaseCard(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: AppColors.orange.withOpacity(0.1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Key References',
                            style: AppTextStyles.subtitle.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• ACSM Metabolic Calculations Handbook; ACSM Guidelines 10e\n'
                            '• Jeukendrup AE (2004, 2011)\n'
                            '• ACSM/AND/DC 2016; NATA & ACSM hydration position stands\n'
                            '• Thomas et al., JAND 2016\n'
                            '• IOC/consensus updates on recovery protein\n'
                            '• Burke et al., IOC consensus on athlete nutrition',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

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

  Widget _buildAccordionSection({
    required String title,
    required String content,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded
              ? AppColors.orange.withOpacity(0.3)
              : Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppTextStyles.subtitle.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? FontAwesomeIcons.chevronUp
                        : FontAwesomeIcons.chevronDown,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 12),
                Text(
                  _formatMarkdownText(content),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Helper to render simple markdown-like bold text
  String _formatMarkdownText(String text) {
    // Remove markdown ** symbols for now (could add RichText support later)
    return text.replaceAll('**', '');
  }
}
