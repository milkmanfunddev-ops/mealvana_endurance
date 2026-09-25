import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../events/domain/event.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/widgets/content_area.dart';
import '../../domain/carb_loading_entryway_engine.dart';

/// The protocol chooser (spec/fueling/carb-loading-entryway.md CE-8 + the
/// CL-12 point-value copy rule): 3-Day Classic, 2-Day Quick and the 1-Day
/// protocol (Q-CL3a), feasibility-gated — a protocol is choosable iff
/// daysUntilRace >= protocolDays; infeasible cards render DISABLED WITH THE
/// REASON, never hidden; race day offers nothing (the entry row already says
/// the window has passed). Selection re-checks feasibility (F5,
/// midnight-rollover guard) and pops the chosen day count.
class CarbLoadingProtocolSelectionScreen extends ConsumerWidget {
  const CarbLoadingProtocolSelectionScreen({
    super.key,
    required Event this.event,
  }) : raceDateOverride = null,
       currentProtocolDays = null;

  /// Re-pick mode (from the plan summary): no Event in hand, the race date
  /// and the current protocol arrive directly; the current card is tagged.
  const CarbLoadingProtocolSelectionScreen.forRepick({
    super.key,
    required DateTime raceDate,
    required this.currentProtocolDays,
  }) : event = null,
       raceDateOverride = raceDate;

  final Event? event;
  final DateTime? raceDateOverride;
  final int? currentProtocolDays;

  DateTime? get _raceDate {
    if (raceDateOverride != null) return raceDateOverride;
    final d = event?.eventDate;
    if (d != null) return DateTime(d.year, d.month, d.day);
    final s = event?.startTime;
    final parsed = s == null ? null : DateTime.tryParse(s);
    return parsed == null
        ? null
        : DateTime(parsed.year, parsed.month, parsed.day);
  }

  int get _daysUntilRace {
    final race = _raceDate;
    if (race == null) return 3; // No date on record: gate nothing.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return race.difference(today).inDays;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysUntil = _daysUntilRace;
    bool choosable(int days) => CarbLoadingEntrywayEngine.isChoosable(
      daysUntilRace: daysUntil,
      protocolDays: days,
    );
    String? reason(int days) => choosable(days)
        ? null
        : 'Needs $days day${days == 1 ? '' : 's'} before race day';
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          key: ValueKey('carb_loading.title'),
          'Choose Carb Loading Protocol',
        ),
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
                  key: const ValueKey('carb_loading.subheading'),
                  'Select Your Protocol',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  key: const ValueKey('carb_loading.description'),
                  'Choose a carb loading protocol based on your experience and race type. Each protocol is backed by research and customized to your body weight.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),

                // 3-day protocol (Recommended)
                _ProtocolCard(
                  key: const ValueKey('carb_loading.protocol_3_day_card'),
                  selectButtonKey: const ValueKey(
                    'carb_loading.select_3_day_button',
                  ),
                  tagKeyPrefix: 'carb_loading.protocol_3_day_tag',
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
                      'Classic loading: taper + high-CHO days achieve supercompensation (Sherman \'81/\'87; Burke \'11; Murray \'18), with historical roots in Bergström & Hultman\'s 3-day high-CHO after depletion.',
                  // CL-12: point-value copy — the actual per-day rates,
                  // never ranges.
                  phases: const [
                    _ProtocolPhase(
                      title: '3–2 days out',
                      carbsPerKg: '8 g/kg/day',
                      description:
                          'Reduce training volume by 75%\nFocus on complex carbohydrates and hydration',
                    ),
                    _ProtocolPhase(
                      title: '1 day out',
                      carbsPerKg: '10 g/kg/day',
                      description:
                          'Light movement only, maximize glycogen\nPeak carb loading day',
                    ),
                  ],
                  enabled: choosable(3),
                  disabledReason: reason(3),
                  isCurrent: currentProtocolDays == 3,
                  onTap: () => _selectProtocol(context, ref, 3),
                ),

                const SizedBox(height: 16),

                // 2-day protocol (Advanced)
                _ProtocolCard(
                  key: const ValueKey('carb_loading.protocol_2_day_card'),
                  selectButtonKey: const ValueKey(
                    'carb_loading.select_2_day_button',
                  ),
                  tagKeyPrefix: 'carb_loading.protocol_2_day_tag',
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
                      carbsPerKg: '9 g/kg/day',
                      description:
                          'Complete rest or very light activity\nHigh-GI carbs with frequent meals',
                    ),
                    _ProtocolPhase(
                      title: '1 day out',
                      carbsPerKg: '11 g/kg/day',
                      description:
                          'Focus on digestibility and timing\nMaximum carb density with minimal fiber',
                    ),
                  ],
                  enabled: choosable(2),
                  disabledReason: reason(2),
                  isCurrent: currentProtocolDays == 2,
                  onTap: () => _selectProtocol(context, ref, 2),
                ),

                const SizedBox(height: 16),

                // 1-day protocol (Q-CL3a: ACSM band midpoint, 11.0 g/kg).
                _ProtocolCard(
                  key: const ValueKey('carb_loading.protocol_1_day_card'),
                  selectButtonKey: const ValueKey(
                    'carb_loading.select_1_day_button',
                  ),
                  tagKeyPrefix: 'carb_loading.protocol_1_day_tag',
                  protocolDays: 1,
                  title: '1-Day',
                  badge: 'RACE WEEK',
                  badgeColor: const Color(0xFF2196F3),
                  subtitle: 'Single-day load for the day before racing',
                  experienceLevel: 'All levels',
                  bestForTags: const [
                    'Race tomorrow',
                    'Short prep windows',
                    'Behind-schedule rescue',
                  ],
                  research:
                      'ACSM contemporary recommendation (10–12 g/kg per 24 h band); Bussau 2002: single-day high-CHO with rest reaches supranormal glycogen.',
                  phases: const [
                    _ProtocolPhase(
                      title: '1 day out',
                      carbsPerKg: '11 g/kg/day',
                      description:
                          'Rest day\nHigh-GI carbs, frequent small meals, minimal fiber',
                    ),
                  ],
                  enabled: choosable(1),
                  disabledReason: reason(1),
                  isCurrent: currentProtocolDays == 1,
                  onTap: () => _selectProtocol(context, ref, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectProtocol(BuildContext context, WidgetRef ref, int days) {
    // F5: feasibility is re-evaluated AT SELECTION TIME, not just when the
    // chooser opened — a midnight rollover mid-chooser must not let a
    // now-infeasible protocol through.
    if (!CarbLoadingEntrywayEngine.isChoosable(
      daysUntilRace: _daysUntilRace,
      protocolDays: days,
    )) {
      return;
    }
    try {
      ref
          .read(appExternalDepsProvider)
          .analytics
          .track(
            'carb_loading_protocol_selected',
            properties: {
              'protocol': '${days}_day',
              'protocol_days': days,
              if (event != null) 'event_id': event!.id,
            },
          );
    } catch (_) {}

    // TODO: Navigate to carb loading plan generation
    // This will be implemented in the next step
    Navigator.pop(context, days);
  }
}

/// Protocol card widget showing detailed protocol information
class _ProtocolCard extends StatefulWidget {
  const _ProtocolCard({
    super.key,
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
    this.selectButtonKey,
    this.tagKeyPrefix,
    this.enabled = true,
    this.disabledReason,
    this.isCurrent = false,
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
  final Key? selectButtonKey;
  final String? tagKeyPrefix;

  /// CE-8: false renders the card disabled WITH [disabledReason] — never
  /// hidden; taps are no-ops.
  final bool enabled;
  final String? disabledReason;

  /// Re-pick mode: tags the athlete's current protocol.
  final bool isCurrent;

  @override
  State<_ProtocolCard> createState() => _ProtocolCardState();
}

class _ProtocolCardState extends State<_ProtocolCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.enabled ? 1 : 0.45,
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: widget.enabled ? widget.onTap : null,
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
                    if (widget.isCurrent)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFF78B14)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'CURRENT PLAN',
                            style: TextStyle(
                              color: Color(0xFFF78B14),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
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
                if (widget.disabledReason != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.disabledReason!,
                    key: widget.tagKeyPrefix != null
                        ? ValueKey('${widget.tagKeyPrefix}_disabled_reason')
                        : null,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
                              final slug = tag.toLowerCase().replaceAll(
                                RegExp(r'[^a-z0-9]+'),
                                '_',
                              );
                              return Container(
                                key: widget.tagKeyPrefix != null
                                    ? ValueKey('${widget.tagKeyPrefix}_$slug')
                                    : null,
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
                                    border: Border.all(
                                      color: Colors.grey[200]!,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                    key: widget.selectButtonKey,
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
