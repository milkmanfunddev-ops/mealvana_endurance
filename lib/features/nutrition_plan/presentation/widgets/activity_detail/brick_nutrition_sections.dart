import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../core/utils/debug_logger.dart';
import '../../../../../shared/domain/activity_type.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../activities/domain/activity.dart';
import '../../../application/macro_explanation_service.dart';
import '../../../domain/food_item_data.dart';
import '../../../domain/nutrition_plan.dart';
import '../../../domain/macro_targets.dart';
import '../../../domain/time_slot_assignment.dart';
import 'before_phase_widget.dart';
import 'dismissible_food_item.dart';
import 'during_phase_section_widget.dart';
import 'macro_summary_row.dart';
import 'phase_explanation_sheet.dart';

/// BrickNutritionSections widget - renders multi-phase nutrition sections for brick workouts
///
/// Displays nutrition sections in order: Before → During-Swim → T1 → During-Bike → T2 → During-Run → After
/// Transition sections (T1, T2) have special styling with 🔄 icon
/// During-Swim typically shows "No foods recommended - mouth rinse only"
class BrickNutritionSections extends StatelessWidget {
  const BrickNutritionSections({
    super.key,
    required this.brick,
    required this.planData,
    required this.onAddFood,
    required this.onSwapFood,
    required this.onDeleteFood,
    required this.onUpdateQuantity,
    this.onInitializeByHour,
    this.onMoveFoodToTimeSlot,
    this.onPlaceFoodInSlot,
    this.onRemoveFoodFromSlot,
    this.onAdjustSlotQuantity,
    this.onMoveSipFoodToSlot,
    this.onScaleSubPhase,
    this.macroTargets,
    this.showSwipeHint = false,
    this.useImperial = false,
    this.bodyWeightKg = 70.0,
    this.enableSectionHeroes = false,
    this.heroTagSeed,
  });

  final Activity brick;
  final NutritionPlan planData;
  final Function(String category) onAddFood;
  final Function(String foodId, String foodName, String category) onSwapFood;
  final Function(String foodId, String category) onDeleteFood;
  final Function(String foodId, String category, double newQuantity)
  onUpdateQuantity;
  final void Function(String category, int durationMinutes)? onInitializeByHour;
  final void Function(
    String foodId,
    String category,
    TimeSlot sourceTimeSlot,
    TimeSlot newTimeSlot,
  )?
  onMoveFoodToTimeSlot;
  final void Function(
    String foodId,
    String category,
    TimeSlot slot,
    double qty,
    TimingCategory? timingCategory,
    bool isSipThroughout,
  )?
  onPlaceFoodInSlot;
  final void Function(String foodId, String category, TimeSlot slot)?
  onRemoveFoodFromSlot;
  final void Function(
    String foodId,
    String category,
    TimeSlot slot,
    double delta,
  )?
  onAdjustSlotQuantity;
  final void Function(
    String foodId,
    String category,
    TimeSlot targetSlot,
    double qty,
    TimingCategory? timingCategory,
  )?
  onMoveSipFoodToSlot;
  final void Function(int subPhaseIndex, int foodIndex, double newQuantity)?
  onScaleSubPhase;
  final MacroTargets? macroTargets;
  final bool showSwipeHint;
  final bool useImperial;
  final double bodyWeightKg;
  final bool enableSectionHeroes;
  final String? heroTagSeed;

  @override
  Widget build(BuildContext context) {
    // Sort sections by phase order (before, during segments, transitions, after)
    final sortedSections = _sortSectionsByPhaseOrder(planData.sections);
    final fallbackSegmentOrder = _inferSegmentOrder(sortedSections);
    var duringIndex = 0;

    if (kDebugMode) {
      DebugLogger.info(
        '[BRICK_NUTRITION] build: sections=${sortedSections.length}, '
        'brickMetadata=${brick.brickMetadata}, '
        'segmentOrder=${brick.brickMetadata?.segmentOrder ?? fallbackSegmentOrder}',
      );
      for (final section in sortedSections) {
        DebugLogger.info(
          '[BRICK_NUTRITION] raw section: id=${section.id}, title=${section.title}',
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedSections.map((section) {
        final isDuring = _isDuringSection(section);
        final currentDuringIndex = isDuring ? duringIndex++ : null;
        return _wrapWithSectionHero(
          section.id,
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: _buildSection(
              context,
              section,
              duringIndex: currentDuringIndex,
              fallbackSegmentOrder: fallbackSegmentOrder,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _wrapWithSectionHero(String sectionId, Widget child) {
    // Hero animations removed — they caused RenderFlex overflow during flight
    // (section widgets are too tall for overlay constraints) which cascaded
    // into deactivated-widget and Riverpod state-modification errors.
    return child;
  }

  /// Sort sections by brick phase order
  List<PlanSection> _sortSectionsByPhaseOrder(List<PlanSection> sections) {
    final sectionMap = <String, List<PlanSection>>{};
    for (final section in sections) {
      sectionMap.putIfAbsent(section.id, () => <PlanSection>[]).add(section);
    }

    final sortedSections = <PlanSection>[];
    final usedSections = <PlanSection>{};

    void addSectionsForId(String id) {
      final list = sectionMap[id];
      if (list == null) return;
      for (final section in list) {
        if (usedSections.add(section)) {
          sortedSections.add(section);
        }
      }
    }

    // Add before section
    addSectionsForId('before');

    // Add during segments and transitions in order
    // Expected IDs: during_segment_1, T1, during_segment_2, T2, during_segment_3
    for (int i = 1; i <= 3; i++) {
      addSectionsForId('during_segment_$i');
      addSectionsForId('T$i');
    }

    // Add after section
    addSectionsForId('after');

    // Append any remaining sections in original order
    for (final section in sections) {
      if (usedSections.add(section)) {
        sortedSections.add(section);
      }
    }

    return sortedSections;
  }

  /// Build individual section
  Widget _buildSection(
    BuildContext context,
    PlanSection section, {
    required int? duringIndex,
    required List<String>? fallbackSegmentOrder,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTransition = section.id.startsWith('T');
    final isDuring = _isDuringSection(section);
    final sportType = _resolveSportType(
      section,
      duringIndex,
      fallbackSegmentOrder: fallbackSegmentOrder,
    );
    final displayTitle = _resolveDisplayTitle(section, sportType);
    final isSwimming = sportType == 'swimming';
    final category = _getCategoryFromSection(
      section,
      sportType,
      isDuring: isDuring,
    );
    final sectionColor = _getSectionColor(
      section,
      Theme.of(context).colorScheme.secondary,
    );

    if (kDebugMode) {
      DebugLogger.info(
        '[BRICK_NUTRITION] render: id=${section.id}, title=${section.title}, '
        'displayTitle=$displayTitle, sportType=$sportType, '
        'isDuring=$isDuring, duringIndex=$duringIndex, category=$category',
      );
    }

    // For before sections with sub-phases, use BeforePhaseWidget
    if (section.hasSubPhases && section.id.startsWith('before')) {
      return BeforePhaseWidget(
        section: section,
        sectionColor: sectionColor,
        sectionTitle: displayTitle.toUpperCase(),
        useImperial: useImperial,
        categoryPrefix: 'before',
        onSwapFood: (foodId, foodName, cat) =>
            onSwapFood(foodId, foodName, cat),
        onDeleteFood: (foodId, cat) => onDeleteFood(foodId, cat),
        onUpdateQuantity: (foodId, cat, newQuantity) =>
            onUpdateQuantity(foodId, cat, newQuantity),
        onScaleSubPhase: onScaleSubPhase!,
        onAddFood: (cat) => onAddFood(cat),
        showSwipeHint: showSwipeHint,
        macroTargets: macroTargets,
        bodyWeightKg: bodyWeightKg,
        sportLabel: 'Brick',
      );
    }

    // For during sections (not swim), use DuringPhaseSectionWidget if by-hour callbacks available
    if (isDuring &&
        !isSwimming &&
        onInitializeByHour != null &&
        onMoveFoodToTimeSlot != null) {
      final segmentDuration = _getSegmentDuration(duringIndex);
      if (segmentDuration >= 60) {
        // Look up brick segment for this during section
        BrickSegmentMacroTarget? brickSeg;
        if (duringIndex != null && macroTargets?.brickPhaseTargets != null) {
          final segments = macroTargets!.brickPhaseTargets!.duringSegments;
          if (duringIndex < segments.length) {
            brickSeg = segments[duringIndex];
          }
        }
        return DuringPhaseSectionWidget(
          section: section,
          sectionColor: sectionColor,
          sectionTitle: displayTitle.toUpperCase(),
          category: category,
          durationMinutes: segmentDuration,
          useImperial: useImperial,
          activityType: ActivityType.fromDbValue(sportType ?? 'running'),
          subtitle: section.subtitle,
          onSwapFood: (foodId, foodName, cat) =>
              onSwapFood(foodId, foodName, cat),
          onDeleteFood: (foodId, cat) => onDeleteFood(foodId, cat),
          onUpdateQuantity: (foodId, cat, newQuantity) =>
              onUpdateQuantity(foodId, cat, newQuantity),
          onAddFood: (cat) => onAddFood(cat),
          onInitializeByHour: onInitializeByHour!,
          onMoveFoodToTimeSlot: onMoveFoodToTimeSlot!,
          onPlaceFoodInSlot: onPlaceFoodInSlot!,
          onRemoveFoodFromSlot: onRemoveFoodFromSlot!,
          onAdjustSlotQuantity: onAdjustSlotQuantity,
          onMoveSipFoodToSlot: onMoveSipFoodToSlot,
          showSwipeHint: showSwipeHint,
          macroTargets: macroTargets,
          bodyWeightKg: bodyWeightKg,
          sportLabel: _sportDisplayName(sportType) ?? 'Brick',
          carbsLow: _getCarbsLow(section, category),
          carbsHigh: _getCarbsHigh(section, category),
          sodiumLow: _getSodiumLow(section, category),
          sodiumHigh: _getSodiumHigh(section, category),
          fluidsLow: _getFluidsLow(section, category),
          fluidsHigh: _getFluidsHigh(section, category),
          brickSegment: brickSeg,
          isBrick: true, // Always true — we're in BrickNutritionSections
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: sectionColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            displayTitle,
            sportType,
            isTransition,
            sectionColor,
            section.id,
            section,
            isDark: isDark,
            duringIndex: duringIndex,
          ),
          if (section.subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              section.subtitle!,
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (_isEmptyNutritionSection(section, isSwimming, isTransition)) ...[
            _buildQuickTransitionMessage(context, section, isTransition),
          ] else ...[
            MacroSummaryRow(
              foods: section.foodItems,
              section: section,
              category: category,
              useImperial: useImperial,
              carbsLow: _getCarbsLow(section, category),
              carbsHigh: _getCarbsHigh(section, category),
              proteinLow: _getProteinLow(section, category),
              proteinHigh: _getProteinHigh(section, category),
              sodiumLow: _getSodiumLow(section, category),
              sodiumHigh: _getSodiumHigh(section, category),
              fluidsLow: _getFluidsLow(section, category),
              fluidsHigh: _getFluidsHigh(section, category),
            ),
            const SizedBox(height: AppSpacing.md),
            ...section.foodItems.asMap().entries.map((entry) {
              final index = entry.key;
              final food = entry.value;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < section.foodItems.length - 1
                      ? AppSpacing.sm
                      : 0,
                ),
                child: DismissibleFoodItem(
                  food: food,
                  category: category,
                  onSwap: () => onSwapFood(food.id, food.name, category),
                  onDelete: () => onDeleteFood(food.id, category),
                  onQuantityChange: (newQuantity) =>
                      onUpdateQuantity(food.id, category, newQuantity),
                  showSwipeHint: showSwipeHint,
                  useImperial: useImperial,
                ),
              );
            }),
          ],
          const SizedBox(height: AppSpacing.md),
          KyleAddFoodButton(
            text: 'ADD FOOD',
            onPressed: () => onAddFood(category),
          ),
        ],
      ),
    );
  }

  /// Build section header with appropriate icon and styling
  Widget _buildSectionHeader(
    BuildContext context,
    String displayTitle,
    String? sportType,
    bool isTransition,
    Color sectionColor,
    String sectionId,
    PlanSection section, {
    required bool isDark,
    int? duringIndex,
  }) {
    return Row(
      children: [
        if (isTransition) ...[
          Icon(
            FontAwesomeIcons.repeat,
            size: AppIconSizes.md,
            color: sectionColor,
          ),
          const SizedBox(width: AppSpacing.sm),
        ] else ...[
          _getSportIcon(sportType, sectionId, isDark: isDark),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Text(
            displayTitle.toUpperCase(),
            style: AppTextStyles.sectionTitle.copyWith(
              color: sectionColor,
              fontSize: 18,
            ),
          ),
        ),
        if (macroTargets != null)
          SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 20,
              icon: Icon(
                Icons.help_outline_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              ),
              onPressed: () {
                final phase = _sectionIdToPhase(sectionId);
                final sportLabel = _sportDisplayName(sportType) ?? 'Brick';
                // Find the brick segment for this during section
                BrickSegmentMacroTarget? brickSegment;
                if (duringIndex != null &&
                    macroTargets!.brickPhaseTargets != null) {
                  final segments =
                      macroTargets!.brickPhaseTargets!.duringSegments;
                  if (duringIndex < segments.length) {
                    brickSegment = segments[duringIndex];
                  }
                }
                PhaseExplanationSheet.show(
                  context,
                  phase: phase,
                  macroTargets: macroTargets!,
                  bodyWeightKg: bodyWeightKg,
                  sportLabel: sportLabel,
                  useImperial: useImperial,
                  foods: section.foodItems,
                  brickSegment: brickSegment,
                  // Always true for during/transition — we're in BrickNutritionSections
                  isBrick: phase != ExplanationPhase.before &&
                      phase != ExplanationPhase.after,
                );
              },
            ),
          ),
      ],
    );
  }

  ExplanationPhase _sectionIdToPhase(String sectionId) {
    if (sectionId.startsWith('before')) return ExplanationPhase.before;
    if (sectionId.startsWith('after')) return ExplanationPhase.after;
    if (sectionId == 'T1') return ExplanationPhase.transition1;
    if (sectionId == 'T2') return ExplanationPhase.transition2;
    if (sectionId.startsWith('during')) return ExplanationPhase.during;
    return ExplanationPhase.during;
  }

  /// Get sport-specific icon for section
  Widget _getSportIcon(
    String? sportType,
    String sectionId, {
    required bool isDark,
  }) {
    IconData iconData;
    Color iconColor;

    if (sportType == 'swimming') {
      iconData = FontAwesomeIcons.personSwimming;
      iconColor = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;
    } else if (sportType == 'cycling') {
      iconData = FontAwesomeIcons.personBiking;
      iconColor = AppColors.orange;
    } else if (sportType == 'running') {
      iconData = FontAwesomeIcons.personRunning;
      iconColor = AppColors.dragonfruit;
    } else if (sportType == null && sectionId == 'before') {
      iconData = FontAwesomeIcons.clock;
      iconColor = AppColors.orange;
    } else if (sportType == null && sectionId == 'after') {
      iconData = FontAwesomeIcons.utensils;
      iconColor = AppColors.dragonfruit;
    } else {
      iconData = FontAwesomeIcons.utensils;
      iconColor = AppColors.orange;
    }

    return Icon(iconData, size: AppIconSizes.md, color: iconColor);
  }

  /// Check if a section should show an informational message instead of macro targets.
  /// True for: swim sections with no foods, or transition sections with 0g carb targets and no foods.
  bool _isEmptyNutritionSection(
    PlanSection section,
    bool isSwimming,
    bool isTransition,
  ) {
    if (isSwimming && section.foodItems.isEmpty) return true;
    if (isTransition && section.foodItems.isEmpty) {
      // Check if targets are all zero (quick transition)
      final carbTarget = section.carbsTarget ?? 0;
      if (carbTarget == 0) return true;
    }
    return false;
  }

  /// Build informational message for sections that don't need nutrition
  Widget _buildQuickTransitionMessage(
    BuildContext context,
    PlanSection section,
    bool isTransition,
  ) {
    String message;
    if (isTransition) {
      // Determine transition type from section ID
      final transitionNumber = int.tryParse(
        section.id.replaceAll(RegExp(r'[^0-9]'), ''),
      );
      if (transitionNumber == 1) {
        message = 'Quick transition - start fueling on the bike';
      } else {
        message = 'Quick transition - fuel at first aid station';
      }
    } else {
      message = 'No foods recommended - mouth rinse only';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(
        message,
        style: AppTextStyles.bodyMedium.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  /// Get category from section ID and sport type for food operations
  ///
  /// For brick during segments, uses sport type when available:
  /// - 'swimming' -> 'during_swim'
  /// - 'cycling' -> 'during_cycling'
  /// - 'running' -> 'during_run'
  String _getCategoryFromSection(
    PlanSection section,
    String? sportType, {
    required bool isDuring,
  }) {
    final idLower = section.id.toLowerCase();
    final titleLower = section.title.toLowerCase();

    if (idLower.startsWith('before') || titleLower.startsWith('before'))
      return 'before';
    if (idLower.startsWith('after') || titleLower.startsWith('after'))
      return 'after';
    if (idLower.startsWith('t') || titleLower.startsWith('transition'))
      return 'transition';

    if (isDuring) {
      if (sportType == 'swimming') {
        return 'during_swim';
      }
      if (sportType == 'cycling') {
        return 'during_cycling';
      }
      // Default to during_run for running segments
      return 'during_run';
    }

    return 'during_run';
  }

  /// Get color for section based on phase
  Color _getSectionColor(PlanSection section, Color themeSecondary) {
    final idLower = section.id.toLowerCase();
    final titleLower = section.title.toLowerCase();
    if (idLower.startsWith('before') || titleLower.startsWith('before'))
      return AppColors.orange;
    if (idLower.startsWith('after') || titleLower.startsWith('after'))
      return AppColors.dragonfruit;
    return themeSecondary;
  }

  String? _resolveSportType(
    PlanSection section,
    int? duringIndex, {
    required List<String>? fallbackSegmentOrder,
  }) {
    final segmentOrder =
        brick.brickMetadata?.segmentOrder ?? fallbackSegmentOrder;

    if (section.id.startsWith('during_segment_')) {
      final segmentIndex = int.tryParse(section.id.split('_').last);
      if (segmentIndex != null &&
          segmentIndex > 0 &&
          segmentOrder != null &&
          segmentIndex <= segmentOrder.length) {
        return segmentOrder[segmentIndex - 1];
      }
    }

    final titleLower = section.title.toLowerCase();
    if (titleLower.contains('swim')) return 'swimming';
    if (titleLower.contains('bike') ||
        titleLower.contains('cycle') ||
        titleLower.contains('ride')) {
      return 'cycling';
    }
    if (titleLower.contains('run')) return 'running';

    if (duringIndex != null &&
        segmentOrder != null &&
        duringIndex < segmentOrder.length) {
      return segmentOrder[duringIndex];
    }

    return null;
  }

  String _resolveDisplayTitle(PlanSection section, String? sportType) {
    if (section.id == 'before') return 'Before Brick';
    if (section.id == 'after') return 'After Brick';
    if (section.id.startsWith('T')) {
      final transitionNumber = int.tryParse(
        section.id.replaceAll(RegExp(r'[^0-9]'), ''),
      );
      if (transitionNumber != null) return 'Transition $transitionNumber';
      return 'Transition';
    }

    final sportName = _sportDisplayName(sportType);
    if (sportName != null) return 'During $sportName';

    return section.title;
  }

  bool _isDuringSection(PlanSection section) {
    if (section.id.startsWith('during')) return true;
    final titleLower = section.title.toLowerCase();
    return titleLower.startsWith('during ');
  }

  List<String>? _inferSegmentOrder(List<PlanSection> sections) {
    final explicitOrder = brick.brickMetadata?.segmentOrder;
    if (explicitOrder != null && explicitOrder.isNotEmpty) {
      return explicitOrder;
    }

    final duringCount = sections.where(_isDuringSection).length;
    if (duringCount >= 3) return const ['swimming', 'cycling', 'running'];
    if (duringCount == 2) return const ['cycling', 'running'];
    if (duringCount == 1) return const ['running'];
    return null;
  }

  /// Get segment duration in minutes from brick metadata.
  /// Falls back to total duration / segment count if specific segment not found.
  int _getSegmentDuration(int? duringIndex) {
    final segments = brick.brickMetadata?.segments;
    if (segments != null &&
        duringIndex != null &&
        duringIndex < segments.length) {
      return segments[duringIndex].durationMinutes;
    }
    // Fallback: use total duration divided by number of during sections
    final totalDuration = brick.durationMinutes ?? 60;
    return totalDuration;
  }

  String? _sportDisplayName(String? sportType) {
    switch (sportType) {
      case 'swimming':
        return 'Swim';
      case 'cycling':
        return 'Bike';
      case 'running':
        return 'Run';
      default:
        return null;
    }
  }

  // Range helpers: resolve per-phase ranges from MacroTargets based on category
  int? _getCarbsLow(PlanSection section, String category) {
    if (section.carbsLowTarget != null) return section.carbsLowTarget!.round();
    final mt = macroTargets;
    if (mt == null) return null;
    if (category.startsWith('before')) return mt.preRun.carbsLowG?.round();
    if (category.startsWith('during')) return mt.duringRun.carbsLowG?.round();
    if (category.startsWith('after')) return mt.postRun.carbsLowG?.round();
    return null;
  }

  int? _getCarbsHigh(PlanSection section, String category) {
    if (section.carbsHighTarget != null)
      return section.carbsHighTarget!.round();
    final mt = macroTargets;
    if (mt == null) return null;
    if (category.startsWith('before')) return mt.preRun.carbsHighG?.round();
    if (category.startsWith('during')) return mt.duringRun.carbsHighG?.round();
    if (category.startsWith('after')) return mt.postRun.carbsHighG?.round();
    return null;
  }

  int? _getProteinLow(PlanSection section, String category) {
    if (section.proteinLowTarget != null)
      return section.proteinLowTarget!.round();
    final mt = macroTargets;
    if (mt == null) return null;
    if (category.startsWith('before')) return mt.preRun.proteinLowG?.round();
    if (category.startsWith('after')) return mt.postRun.proteinLowG?.round();
    return null;
  }

  int? _getProteinHigh(PlanSection section, String category) {
    if (section.proteinHighTarget != null)
      return section.proteinHighTarget!.round();
    final mt = macroTargets;
    if (mt == null) return null;
    if (category.startsWith('before')) return mt.preRun.proteinHighG?.round();
    if (category.startsWith('after')) return mt.postRun.proteinHighG?.round();
    return null;
  }

  int? _getSodiumLow(PlanSection section, String category) {
    if (section.sodiumLowTarget != null)
      return section.sodiumLowTarget!.round();
    final mt = macroTargets;
    if (mt == null) return null;
    if (category.startsWith('before')) return mt.preRun.sodiumLowMg?.round();
    if (category.startsWith('during')) return mt.duringRun.sodiumLowMg?.round();
    if (category.startsWith('after')) return mt.postRun.sodiumLowMg?.round();
    return null;
  }

  int? _getSodiumHigh(PlanSection section, String category) {
    if (section.sodiumHighTarget != null)
      return section.sodiumHighTarget!.round();
    final mt = macroTargets;
    if (mt == null) return null;
    if (category.startsWith('before')) return mt.preRun.sodiumHighMg?.round();
    if (category.startsWith('during'))
      return mt.duringRun.sodiumHighMg?.round();
    if (category.startsWith('after')) return mt.postRun.sodiumHighMg?.round();
    return null;
  }

  int? _getFluidsLow(PlanSection section, String category) {
    if (section.fluidsLowTarget != null)
      return section.fluidsLowTarget!.round();
    final mt = macroTargets;
    if (mt == null) return null;
    if (category.startsWith('before')) return mt.preRun.fluidsLowMl?.round();
    if (category.startsWith('during')) return mt.duringRun.fluidsLowMl?.round();
    if (category.startsWith('after')) return mt.postRun.fluidsLowMl?.round();
    return null;
  }

  int? _getFluidsHigh(PlanSection section, String category) {
    if (section.fluidsHighTarget != null)
      return section.fluidsHighTarget!.round();
    final mt = macroTargets;
    if (mt == null) return null;
    if (category.startsWith('before')) return mt.preRun.fluidsHighMl?.round();
    if (category.startsWith('during'))
      return mt.duringRun.fluidsHighMl?.round();
    if (category.startsWith('after')) return mt.postRun.fluidsHighMl?.round();
    return null;
  }
}
