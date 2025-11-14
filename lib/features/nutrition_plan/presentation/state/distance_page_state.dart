import '../../domain/macro_targets.dart';
import '../../domain/pending_activity_data.dart';

/// State for both distance page and adjust macros screens.
///
/// This state object contains:
/// - UI text content (loaded from ContentService)
/// - Loading/error states
/// - Generated macro targets
/// - Activity/event linking data
class MacroTargetsState {
  const MacroTargetsState({
    // Distance page fields
    required this.title,
    required this.distanceLabel,
    required this.paceLabel,
    required this.preRunLabel,
    required this.gutTrainingLabel,
    required this.generateButtonText,
    required this.tipsText,
    required this.distanceValidationRequired,
    required this.distanceValidationNumber,
    required this.distanceValidationRange,
    required this.paceValidationRequired,
    required this.paceValidationFormat,
    required this.errorGeneric,
    required this.isGenerating,
    required this.isGeneratingMacros,
    // Adjust macros fields
    required this.adjustMacrosTitle,
    required this.shortRunBanner,
    required this.longRunBanner,
    required this.preRunSectionTitle,
    required this.duringRunSectionTitle,
    required this.postRunSectionTitle,
    required this.createPlanButton,
    required this.resetAllButton,
    required this.helpTitle,
    required this.helpOverview,
    required this.helpPreRun,
    required this.helpDuringRun,
    required this.helpPostRun,
    required this.helpValidation,
    required this.isCreatingPlan,
    this.macroTargets,
    this.validationMessages = const {},
    // Shared fields
    this.errorMessage,
    this.activityId,
    this.eventId,
    this.pendingActivityData,
  });

  // Distance page fields
  final String title;
  final String distanceLabel;
  final String paceLabel;
  final String preRunLabel;
  final String gutTrainingLabel;
  final String generateButtonText;
  final String tipsText;
  final String distanceValidationRequired;
  final String distanceValidationNumber;
  final String distanceValidationRange;
  final String paceValidationRequired;
  final String paceValidationFormat;
  final String errorGeneric;
  final bool isGenerating;
  final bool isGeneratingMacros;

  // Adjust macros screen fields
  final String adjustMacrosTitle;
  final String shortRunBanner;
  final String longRunBanner;
  final String preRunSectionTitle;
  final String duringRunSectionTitle;
  final String postRunSectionTitle;
  final String createPlanButton;
  final String resetAllButton;
  final String helpTitle;
  final String helpOverview;
  final String helpPreRun;
  final String helpDuringRun;
  final String helpPostRun;
  final String helpValidation;
  final bool isCreatingPlan;
  final MacroTargets? macroTargets;
  final Map<String, String> validationMessages;

  // Shared fields
  final String? errorMessage;
  final int? activityId; // Calendar activity ID (links nutrition plan to activity)
  final int? eventId; // Calendar event ID (for provider invalidation after plan creation)
  final PendingActivityData? pendingActivityData; // Activity data (not yet created)

  MacroTargetsState copyWith({
    // Distance page fields
    String? title,
    String? distanceLabel,
    String? paceLabel,
    String? preRunLabel,
    String? gutTrainingLabel,
    String? generateButtonText,
    String? tipsText,
    String? distanceValidationRequired,
    String? distanceValidationNumber,
    String? distanceValidationRange,
    String? paceValidationRequired,
    String? paceValidationFormat,
    String? errorGeneric,
    bool? isGenerating,
    bool? isGeneratingMacros,
    // Adjust macros fields
    String? adjustMacrosTitle,
    String? shortRunBanner,
    String? longRunBanner,
    String? preRunSectionTitle,
    String? duringRunSectionTitle,
    String? postRunSectionTitle,
    String? createPlanButton,
    String? resetAllButton,
    String? helpTitle,
    String? helpOverview,
    String? helpPreRun,
    String? helpDuringRun,
    String? helpPostRun,
    String? helpValidation,
    bool? isCreatingPlan,
    MacroTargets? macroTargets,
    Map<String, String>? validationMessages,
    // Shared fields
    String? errorMessage,
    int? activityId,
    int? eventId,
    PendingActivityData? pendingActivityData,
  }) {
    return MacroTargetsState(
      title: title ?? this.title,
      distanceLabel: distanceLabel ?? this.distanceLabel,
      paceLabel: paceLabel ?? this.paceLabel,
      preRunLabel: preRunLabel ?? this.preRunLabel,
      gutTrainingLabel: gutTrainingLabel ?? this.gutTrainingLabel,
      generateButtonText: generateButtonText ?? this.generateButtonText,
      tipsText: tipsText ?? this.tipsText,
      distanceValidationRequired: distanceValidationRequired ?? this.distanceValidationRequired,
      distanceValidationNumber: distanceValidationNumber ?? this.distanceValidationNumber,
      distanceValidationRange: distanceValidationRange ?? this.distanceValidationRange,
      paceValidationRequired: paceValidationRequired ?? this.paceValidationRequired,
      paceValidationFormat: paceValidationFormat ?? this.paceValidationFormat,
      errorGeneric: errorGeneric ?? this.errorGeneric,
      isGenerating: isGenerating ?? this.isGenerating,
      isGeneratingMacros: isGeneratingMacros ?? this.isGeneratingMacros,
      adjustMacrosTitle: adjustMacrosTitle ?? this.adjustMacrosTitle,
      shortRunBanner: shortRunBanner ?? this.shortRunBanner,
      longRunBanner: longRunBanner ?? this.longRunBanner,
      preRunSectionTitle: preRunSectionTitle ?? this.preRunSectionTitle,
      duringRunSectionTitle: duringRunSectionTitle ?? this.duringRunSectionTitle,
      postRunSectionTitle: postRunSectionTitle ?? this.postRunSectionTitle,
      createPlanButton: createPlanButton ?? this.createPlanButton,
      resetAllButton: resetAllButton ?? this.resetAllButton,
      helpTitle: helpTitle ?? this.helpTitle,
      helpOverview: helpOverview ?? this.helpOverview,
      helpPreRun: helpPreRun ?? this.helpPreRun,
      helpDuringRun: helpDuringRun ?? this.helpDuringRun,
      helpPostRun: helpPostRun ?? this.helpPostRun,
      helpValidation: helpValidation ?? this.helpValidation,
      isCreatingPlan: isCreatingPlan ?? this.isCreatingPlan,
      macroTargets: macroTargets ?? this.macroTargets,
      validationMessages: validationMessages ?? this.validationMessages,
      errorMessage: errorMessage ?? this.errorMessage,
      activityId: activityId ?? this.activityId,
      eventId: eventId ?? this.eventId,
      pendingActivityData: pendingActivityData ?? this.pendingActivityData,
    );
  }
}
