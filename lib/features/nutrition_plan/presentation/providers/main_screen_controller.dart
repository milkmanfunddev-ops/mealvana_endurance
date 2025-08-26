import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../../application/nutrition_plan_service.dart';
import '../../domain/nutrition_plan.dart';
import 'nutrition_plan_controller.dart';

part 'main_screen_controller.g.dart';

/// State for the main nutrition plan screen
class MainScreenState {
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
  final NutritionPlan? currentPlan;
  final String? errorMessage;

  const MainScreenState({
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
    this.currentPlan,
    this.errorMessage,
  });

  MainScreenState copyWith({
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
    NutritionPlan? currentPlan,
    String? errorMessage,
  }) {
    return MainScreenState(
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
      currentPlan: currentPlan ?? this.currentPlan,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Controller for main nutrition plan screen
@riverpod
class MainScreenController extends _$MainScreenController {
  ContentService get _contentService => ref.read(contentServiceProvider);
  NutritionPlanService get _nutritionPlanService => ref.read(nutritionPlanServiceProvider);

  @override
  FutureOr<MainScreenState> build() {
    // Load content synchronously from in-memory cache
    final title = _contentService.getValue(ContentKeys.mainScreenTitle, defaultValue: 'Mealvana Endurance');
    final distanceLabel = _contentService.getValue(ContentKeys.mainScreenDistanceLabel, defaultValue: 'Distance');
    final paceLabel = _contentService.getValue(ContentKeys.mainScreenPaceLabel, defaultValue: 'Average pace');
    final preRunLabel = _contentService.getValue(ContentKeys.mainScreenPreRunLabel, defaultValue: 'Time before run');
    final gutTrainingLabel = _contentService.getValue(ContentKeys.mainScreenGutTrainingLabel, defaultValue: 'Gut training level');
    final generateButtonText = _contentService.getValue(ContentKeys.mainScreenGenerateButton, defaultValue: 'Generate Plan');
    final tipsText = _contentService.getValue(ContentKeys.mainScreenTipsText, defaultValue: 'We\'ll create a personalized nutrition plan\nbased on your run details');
    
    // Validation messages
    final distanceValidationRequired = _contentService.getValue(ContentKeys.validationRequired, defaultValue: 'Required');
    final distanceValidationNumber = _contentService.getValue(ContentKeys.validationInvalidNumber, defaultValue: 'Please enter a valid number');
    final distanceValidationRange = _contentService.getValue(ContentKeys.validationDistanceRange, defaultValue: 'Distance must be between 0 and 200');
    final paceValidationRequired = _contentService.getValue(ContentKeys.validationRequired, defaultValue: 'Required');
    final paceValidationFormat = _contentService.getValue(ContentKeys.validationPaceFormat, defaultValue: 'Format: 8:30 or 8.5');
    final errorGeneric = _contentService.getValue(ContentKeys.errorGeneric, defaultValue: 'Something went wrong. Please try again.');

    return MainScreenState(
      title: title,
      distanceLabel: distanceLabel,
      paceLabel: paceLabel,
      preRunLabel: preRunLabel,
      gutTrainingLabel: gutTrainingLabel,
      generateButtonText: generateButtonText,
      tipsText: tipsText,
      distanceValidationRequired: distanceValidationRequired,
      distanceValidationNumber: distanceValidationNumber,
      distanceValidationRange: distanceValidationRange,
      paceValidationRequired: paceValidationRequired,
      paceValidationFormat: paceValidationFormat,
      errorGeneric: errorGeneric,
      isGenerating: false,
    );
  }

  /// Generate nutrition plan
  Future<NutritionPlan?> generatePlan({
    required double distanceMiles,
    required double paceMinutesPerMile,
  }) async {
    final currentState = state.valueOrNull;
    if (currentState == null) return null;

    state = AsyncData(currentState.copyWith(isGenerating: true, errorMessage: null));

    state = await AsyncValue.guard(() async {
      final plan = await _nutritionPlanService.generateNutritionPlan(
        distanceMiles: distanceMiles,
        paceMinutesPerMile: paceMinutesPerMile,
      );

      // Invalidate the nutrition plan controller to force it to show the new plan
      ref.invalidate(nutritionPlanControllerProvider);

      return currentState.copyWith(
        isGenerating: false,
        currentPlan: plan,
        errorMessage: null,
      );
    });

    return state.valueOrNull?.currentPlan;
  }

  /// Refresh content from backend
  Future<void> refreshContent() async {
    await _contentService.refreshFromBackend();
    ref.invalidateSelf();
  }
}