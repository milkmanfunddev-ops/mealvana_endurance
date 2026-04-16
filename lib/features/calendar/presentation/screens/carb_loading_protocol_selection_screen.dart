import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../events/domain/event.dart';
import '../../../carb_loading/presentation/providers/carb_loading_controller.dart';
import '../../../events/presentation/providers/events_controller.dart';
import '../../../../shared/widgets/content_area.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';

/// Screen for selecting carb loading protocol
/// Displays 2-day and 3-day protocol options with detailed information
class CarbLoadingProtocolSelectionScreen extends ConsumerWidget {
  const CarbLoadingProtocolSelectionScreen({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Carb Loading Protocol'),
        actions: [
          if (event.hasCarbLoading)
            IconButton(
              onPressed: () => _confirmDeletePlan(context, ref),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete Carb Loading Plan',
            ),
        ],
      ),
      body: SafeArea(
        child: ContentArea.wide(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section
                Text(
                  'Select Your Protocol',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a carb loading protocol based on your experience and race type. Each protocol is backed by research and customized to your body weight.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),

                // 3-day protocol (Recommended)
                _ProtocolCard(
                  protocolDays: 3,
                  title: '3-Day Classic',
                  badge: 'RECOMMENDED',
                  badgeColor: const Color(0xFF4CAF50),
                  subtitle: 'Balanced approach with moderate loading',
                  experienceLevel: 'Intermediate',
                  bestForTags: const [
                    'Marathon',
                    'Half Marathon',
                    'Long distance races',
                  ],
                  research:
                      'Classic loading: taper + ~8–12 g/kg/day for 24–72 h achieves supercompensation (Sherman \'81/\'87; Burke \'11; Murray \'18), with historical roots in Bergström & Hultman\'s 3-day high-CHO after depletion.',
                  phases: const [
                    _ProtocolPhase(
                      title: '3–2 days out',
                      carbsPerKg: '7–9 g/kg/day',
                      description:
                          'Reduce training volume by 75%\nFocus on complex carbohydrates and hydration',
                    ),
                    _ProtocolPhase(
                      title: '1 day out',
                      carbsPerKg: '9–12 g/kg/day',
                      description:
                          'Light movement only, maximize glycogen\nPeak carb loading day',
                    ),
                  ],
                  onTap: () => _selectProtocol(context, ref, 3),
                ),

                const SizedBox(height: 16),

                // 2-day protocol (Advanced)
                _ProtocolCard(
                  protocolDays: 2,
                  title: '2-Day Quick',
                  badge: 'ADVANCED',
                  badgeColor: const Color(0xFFFF9800),
                  subtitle: 'Rapid loading for time-constrained athletes',
                  experienceLevel: 'Advanced',
                  bestForTags: const [
                    '10K',
                    '15K',
                    'Experienced athletes',
                    'Late race registration',
                  ],
                  research:
                      'Fairchild 2002: supranormal glycogen in 24 h after brief high-intensity priming + high-CHO; Bussau 2002: 24 h with rest + high-CHO.',
                  phases: const [
                    _ProtocolPhase(
                      title: '2 days out',
                      carbsPerKg: '8–10 g/kg/day',
                      description:
                          'Complete rest or very light activity\nHigh-GI carbs with frequent meals',
                    ),
                    _ProtocolPhase(
                      title: '1 day out',
                      carbsPerKg: '10–12 g/kg/day',
                      description:
                          'Focus on digestibility and timing\nMaximum carb density with minimal fiber',
                    ),
                  ],
                  onTap: () => _selectProtocol(context, ref, 2),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectProtocol(BuildContext context, WidgetRef ref, int days) {
    Navigator.pop(context, days);
  }

  Future<void> _confirmDeletePlan(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Carb Loading Plan'),
        content: const Text(
          'This will delete the carb loading plan and all associated days. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(carbLoadingControllerProvider.notifier)
          .deleteCarbLoadingPlan(event.id);

      // Refresh event detail
      ref.invalidate(eventDetailProvider(event.id));

      if (context.mounted) {
        MealvanaSnackbar.showSuccess(context, 'Carb loading plan deleted');
        Navigator.pop(context); // Return to event detail
      }
    } catch (e) {
      if (context.mounted) {
        MealvanaSnackbar.showError(context, 'Failed to delete plan: $e');
      }
    }
  }
}

/// Protocol card widget showing detailed protocol information
class _ProtocolCard extends StatefulWidget {
  const _ProtocolCard({
    required this.protocolDays,
    required this.title,
    required this.badge,
    required this.badgeColor,
    required this.subtitle,
    required this.experienceLevel,
    required this.bestForTags,
    required this.research,
    required this.phases,
    required this.onTap,
  });

  final int protocolDays;
  final String title;
  final String badge;
  final Color badgeColor;
  final String subtitle;
  final String experienceLevel;
  final List<String> bestForTags;
  final String research;
  final List<_ProtocolPhase> phases;
  final VoidCallback onTap;

  @override
  State<_ProtocolCard> createState() => _ProtocolCardState();
}

class _ProtocolCardState extends State<_ProtocolCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with title and badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: widget.badgeColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                widget.subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),

              // Experience level
              Text(
                widget.experienceLevel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),

              // Best For section
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚡ ', style: TextStyle(fontSize: 16)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Best For',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.bestForTags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[900],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Expandable details section
              const SizedBox(height: 12),
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Row(
                  children: [
                    Text(
                      _isExpanded ? 'Hide Details' : 'Show Details',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Theme.of(context).primaryColor,
                    ),
                  ],
                ),
              ),

              if (_isExpanded) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // Research section
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🔬 ', style: TextStyle(fontSize: 16)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Research',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.research,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Protocol phases
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📅 ', style: TextStyle(fontSize: 16)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Protocol Phases',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 12),
                          ...widget.phases.map((phase) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      phase.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      phase.carbsPerKg,
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      phase.description,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Select button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onTap,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Select ${widget.protocolDays}-Day Protocol'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Protocol phase data class
class _ProtocolPhase {
  const _ProtocolPhase({
    required this.title,
    required this.carbsPerKg,
    required this.description,
  });

  final String title;
  final String carbsPerKg;
  final String description;
}
