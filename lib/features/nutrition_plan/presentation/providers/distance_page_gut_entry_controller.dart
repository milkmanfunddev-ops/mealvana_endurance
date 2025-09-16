import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../../domain/run_parameters.dart';
import '../../domain/macro_targets.dart';
import '../../data/macro_repository.dart';
import '../../data/nutrition_plan_repository.dart';
import '../../application/llm_nutrition_plan_service.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../../shared/services/analytics_service.dart';
import '../../../auth/application/auth_service.dart';
import 'nutrition_plan_controller.dart';

part 'distance_page_gut_entry_controller.g.dart';

/// State for both distance page and adjust macros screens
class DistancePageGutEntryState {
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
  final String? planId; // UUID v4 for threading North-Star metric events

  const DistancePageGutEntryState({
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
    this.planId,
  });

  DistancePageGutEntryState copyWith({
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
    String? planId,
  }) {
    return DistancePageGutEntryState(
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
      
      // Adjust macros fields
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
      
      // Shared fields
      errorMessage: errorMessage ?? this.errorMessage,
      planId: planId ?? this.planId,
    );
  }
}

/// Controller for distance page gut entry screen
/// FOA COMPLIANT: Contains ALL business logic, no UI concerns
@riverpod
class DistancePageGutEntryController extends _$DistancePageGutEntryController {
  ContentService get _contentService => ref.read(contentServiceProvider);

  @override
  FutureOr<DistancePageGutEntryState> build() async {
    // Track screen view
    AnalyticsService.trackScreenViewed('Main Nutrition Plan Screen');
    
    // Load content synchronously from in-memory cache
    final title = _contentService.getValue(ContentKeys.mainScreenTitle, defaultValue: 'Mealvana Endurance');
    final distanceLabel = _contentService.getValue(ContentKeys.mainScreenDistanceLabel, defaultValue: 'Distance');
    final paceLabel = _contentService.getValue(ContentKeys.mainScreenPaceLabel, defaultValue: 'Average pace');
    final preRunLabel = _contentService.getValue(ContentKeys.mainScreenPreRunLabel, defaultValue: 'Time before run');
    final gutTrainingLabel = _contentService.getValue(ContentKeys.mainScreenGutTrainingLabel, defaultValue: 'Gut training level');
    final generateButtonText = _contentService.getValue(ContentKeys.mainScreenGenerateButton, defaultValue: 'Generate Plan');
    final tipsText = _contentService.getValue(ContentKeys.mainScreenTipsText, defaultValue: 'We will create a personalized nutrition plan based on your run details');
    
    // Validation messages
    final distanceValidationRequired = _contentService.getValue(ContentKeys.validationRequired, defaultValue: 'Required');
    final distanceValidationNumber = _contentService.getValue(ContentKeys.validationInvalidNumber, defaultValue: 'Please enter a valid number');
    final distanceValidationRange = _contentService.getValue(ContentKeys.validationDistanceRange, defaultValue: 'Distance must be between 0 and 200');
    final paceValidationRequired = _contentService.getValue(ContentKeys.validationRequired, defaultValue: 'Required');
    final paceValidationFormat = _contentService.getValue(ContentKeys.validationPaceFormat, defaultValue: 'Format: 8:30 or 8.5');
    final errorGeneric = _contentService.getValue(ContentKeys.errorGeneric, defaultValue: 'Something went wrong. Please try again.');

    // Adjust macros content
    final adjustMacrosTitle = _contentService.getValue('adjust_macros.screen_title', defaultValue: 'Adjust Your Macros');
    final shortRunBanner = _contentService.getValue('adjust_macros.banner.short_run', defaultValue: 'For this duration, during-run carbs are optional');
    final longRunBanner = _contentService.getValue('adjust_macros.banner.long_run', defaultValue: 'Target at least {amount}g carbs during your run');
    final preRunSectionTitle = _contentService.getValue('adjust_macros.sections.pre_run', defaultValue: 'Pre-Run');
    final duringRunSectionTitle = _contentService.getValue('adjust_macros.sections.during_run', defaultValue: 'During Run');
    final postRunSectionTitle = _contentService.getValue('adjust_macros.sections.post_run', defaultValue: 'Post-Run (within 30 min)');
    final createPlanButton = _contentService.getValue('adjust_macros.actions.create_plan', defaultValue: 'Create Plan');
    final resetAllButton = _contentService.getValue('adjust_macros.actions.reset_all', defaultValue: 'Reset All');
    final helpTitle = _contentService.getValue('adjust_macros.help_content.title', defaultValue: 'Nutrition Science & Guidance');
    final helpOverview = _contentService.getValue('adjust_macros.help_content.overview', defaultValue: 'These targets are based on ISSN guidelines and sports nutrition research tailored to your run parameters.');
    final helpPreRun = _contentService.getValue('adjust_macros.help_content.pre_run', defaultValue: 'Pre-run fueling optimizes energy stores and prevents GI distress during exercise.');
    final helpDuringRun = _contentService.getValue('adjust_macros.help_content.during_run', defaultValue: 'During-run nutrition maintains blood glucose and delays fatigue during longer efforts.');
    final helpPostRun = _contentService.getValue('adjust_macros.help_content.post_run', defaultValue: 'Post-run nutrition accelerates glycogen replenishment and muscle protein synthesis.');
    final helpValidation = _contentService.getValue('adjust_macros.help_content.validation', defaultValue: 'Warning indicators show values outside research-backed ranges but won\'t prevent plan creation.');

    // Load cached macro targets
    final repository = await ref.read(macroRepositoryProvider.future);
    final cachedTargets = await repository.getCachedMacroTargets();

    return DistancePageGutEntryState(
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
      isGeneratingMacros: false,
      
      adjustMacrosTitle: adjustMacrosTitle,
      shortRunBanner: shortRunBanner,
      longRunBanner: longRunBanner,
      preRunSectionTitle: preRunSectionTitle,
      duringRunSectionTitle: duringRunSectionTitle,
      postRunSectionTitle: postRunSectionTitle,
      createPlanButton: createPlanButton,
      resetAllButton: resetAllButton,
      helpTitle: helpTitle,
      helpOverview: helpOverview,
      helpPreRun: helpPreRun,
      helpDuringRun: helpDuringRun,
      helpPostRun: helpPostRun,
      helpValidation: helpValidation,
      isCreatingPlan: false,
      macroTargets: cachedTargets,
    );
  }

  /// Load user preferences from the user profile
  Future<void> loadUserPreferences() async {
    // TODO: Load user profile when auth service method is available
    // For now, use default gut training level
    print('🔍 DEBUG: Loading user preferences (TODO: implement when auth service available)');
  }

  /// Generate macro targets by calling the generate-macros edge function
  Future<void> generateMacros({
    required String distanceText,
    required String paceText,
    required int timeBeforeRunMinutes,
    required GutTraining gutTraining,
    required DistanceUnit distanceUnit,
    required PaceUnit paceUnit,
    SweatRateCat? sweatRateCat,
    double? temperatureC,
    double? humidityPct,
  }) async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    print('🚀 DEBUG: Starting macro generation...');
    print('🔍 DEBUG: Distance: $distanceText ${distanceUnit.name}');
    print('🔍 DEBUG: Pace: $paceText ${paceUnit.name}');
    print('🔍 DEBUG: Time before run: ${timeBeforeRunMinutes}min');
    print('🔍 DEBUG: Gut training: ${gutTraining.name}');
    print('🔍 DEBUG: Temperature: ${temperatureC}°C');
    print('🔍 DEBUG: Humidity: ${humidityPct}%');
    print('🔍 DEBUG: Sweat rate: ${sweatRateCat?.name}');

    // Set loading state
    state = AsyncData(currentState.copyWith(
      isGeneratingMacros: true, 
      errorMessage: null,
    ));

    state = await AsyncValue.guard(() async {
      try {
        // Parse and validate input
        final distance = double.tryParse(distanceText) ?? 5.0;
        final paceString = paceText.trim();
        
        // Parse pace (e.g., "8:30" -> 8.5 minutes per mile)
        final paceParts = paceString.split(':');
        final paceMinutes = paceParts.length == 2
            ? (double.tryParse(paceParts[0]) ?? 8.0) + 
              ((double.tryParse(paceParts[1]) ?? 30.0) / 60.0)
            : double.tryParse(paceString) ?? 8.5;

        print('📊 DEBUG: Parsed distance: ${distance}mi');
        print('📊 DEBUG: Parsed pace: ${paceMinutes}min/mi');
        
        // Generate plan_id for North-Star metric threading
        const uuid = Uuid();
        final planId = uuid.v4();
        
        print('🆔 DEBUG: Generated plan_id: $planId');

        // Track plan flow started - North-Star metric entry point
        await AnalyticsService.trackPlanFlowStarted(
          planId: planId,
          screen: 'Adjust Your Macros',
          activityType: 'running', // Could be parameterized later
          distanceMi: distance,
          durationMin: distance * paceMinutes, // Calculate duration
          timeBeforeRunMin: timeBeforeRunMinutes.toDouble(),
          gutTrainingLevel: gutTraining.name,
          sweatRateLevel: sweatRateCat?.name ?? 'medium',
          temperatureC: temperatureC ?? 20.0, // Default temp
          humidityPct: humidityPct ?? 50.0, // Default humidity
        );

        print('🎯 DEBUG: Calling generateMacroTargets directly...');

        // Call generate-macros edge function directly
        await _generateMacroTargets(
          distanceMiles: distance,
          paceMinutesPerMile: paceMinutes,
          timeBeforeRunMinutes: timeBeforeRunMinutes,
          gutTraining: gutTraining,
          sweatRateCat: sweatRateCat,
          temperatureC: temperatureC,
          humidityPct: humidityPct,
        );

        print('💾 DEBUG: MacroTargets generated successfully');

        // Get the generated macro targets from cache to track analytics
        final repository = await ref.read(macroRepositoryProvider.future);
        final macroTargets = await repository.getCachedMacroTargets();
        
        print('✅ DEBUG: Macro targets generated successfully!');

        // Update state to not generating and include macro targets with planId
        return currentState.copyWith(
          isGeneratingMacros: false,
          errorMessage: null,
          macroTargets: macroTargets,
          planId: planId, // Thread plan_id for North-Star metric
        );

      } catch (error, stackTrace) {
        print('❌ DEBUG: Error generating macro targets: $error');
        
        // Track the error
        AnalyticsService.trackError(
          errorType: 'Macro Targets Generation Error',
          errorMessage: error.toString(),
          screenName: 'Distance Page Gut Entry',
          additionalContext: {
            'Distance': distanceText,
            'Pace': paceText,
          },
        );
        
        // Track macro generation failed
        AnalyticsService.trackNutritionPlanGenerationFailed(
          errorMessage: error.toString(),
          distanceMiles: double.tryParse(distanceText) ?? 5.0,
          paceMinutesPerMile: double.tryParse(paceText) ?? 8.5,
        );
        
        rethrow; // Re-throw so the screen can handle it
      }
    });
  }

  /// Generate macro targets by calling the generate-macros edge function
  Future<void> _generateMacroTargets({
    required double distanceMiles,
    required double paceMinutesPerMile,
    required int timeBeforeRunMinutes,
    required GutTraining gutTraining,
    SweatRateCat? sweatRateCat,
    double? temperatureC,
    double? humidityPct,
  }) async {
    // Track macro generation started
    AnalyticsService.trackNutritionPlanGenerationStarted(
      distanceMiles: distanceMiles,
      paceMinutesPerMile: paceMinutesPerMile,
      timeBeforeRunHours: timeBeforeRunMinutes / 60.0,
      gutTrainingLevel: gutTraining.name,
    );

    // Get user profile data
    final authService = ref.read(authServiceProvider);
    final userProfile = await authService.getCurrentUser();
    
    // Calculate user metrics with fallbacks to reasonable defaults
    final age = userProfile?.age ?? 30;
    final gender = userProfile?.gender.name ?? 'other';
    final weightKg = userProfile != null 
        ? userProfile.weightPounds * 0.453592  // Convert lbs to kg
        : 70.0; // Default 70kg if no profile
    final heightCm = userProfile != null
        ? userProfile.totalHeightInches * 2.54  // Convert inches to cm  
        : 170.0; // Default 170cm if no profile
        
    print('🔍 DEBUG: User profile - Age: $age, Gender: $gender, Weight: ${weightKg.toStringAsFixed(1)}kg, Height: ${heightCm.toStringAsFixed(0)}cm');
    
    final requestData = {
      'age': age,
      'gender': gender,
      'weight': weightKg,
      'weight_unit': 'kg',
      'height': heightCm,
      'height_unit': 'cm',
      'run_pace': paceMinutesPerMile,
      'run_distance': distanceMiles,
      'run_pace_unit': 'min_per_mile',
      'run_distance_unit': 'mi',
      'time_before_run_min': timeBeforeRunMinutes,
      'gut_training': userProfile?.gutTraining.name ?? gutTraining.name, // Use user's preference if available
      'carb_source': 'dual', // Default to dual-source carbs
      'sweat_sodium': 'medium', // Default sweat sodium
      'drink_sodium_mg_per_l': 500, // Default sports drink sodium
      'optional_sweat_rate_lph': null, // Use category-based approach
      'sweat_rate_category': sweatRateCat?.name ?? 'medium',
      'temp_c': temperatureC,
      'humidity_pct': humidityPct,
    };

    // Call the generate-macros edge function
    final supabase = Supabase.instance.client;
    final response = await supabase.functions.invoke(
      'generate-macros',
      body: requestData,
    );

    if (response.status >= 400) {
      final data = response.data as Map<String, dynamic>?;
      throw Exception(data?['message'] ?? 'Failed to generate macro targets');
    }

    // Parse the response
    final data = response.data as Map<String, dynamic>;
    
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to generate macro targets');
    }

    final macrosData = data['macros'] as Map<String, dynamic>;
    
    // Debug: Log the raw response data to help identify type issues
    print('🔍 DEBUG: Edge function response keys: ${macrosData.keys.toList()}');
    print('🔍 DEBUG: Sample values and types:');
    final sampleKeys = ['pre_run_carbs_g', 'during_rate_g_per_h', 'duration_h', 'MET'];
    for (final key in sampleKeys) {
      if (macrosData.containsKey(key)) {
        print('  $key: ${macrosData[key]} (${macrosData[key].runtimeType})');
      }
    }
    
    // Helper function to safely convert to double
    double toDouble(dynamic value, [String fieldName = 'unknown']) {
      try {
        if (value == null) return 0.0;
        if (value is double) return value;
        if (value is int) return value.toDouble();
        if (value is String) return double.tryParse(value) ?? 0.0;
        return (value as num).toDouble();
      } catch (e) {
        print('❌ DEBUG: Error converting field "$fieldName" with value "$value" (${value.runtimeType}) to double: $e');
        return 0.0;
      }
    }
    
    // Helper function to safely convert list to List<double>
    List<double> toDoubleList(dynamic value, [List<double> defaultValue = const [30, 60]]) {
      if (value == null) return defaultValue;
      if (value is List) {
        return value.map((e) => toDouble(e)).toList();
      }
      return defaultValue;
    }
    
    // Convert edge function response to MacroTargets with correct field names
    final macroTargets = MacroTargets(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      preRun: PreRunMacros(
        carbsG: toDouble(macrosData['pre_run_carbs_g'], 'pre_run_carbs_g'),
        proteinG: toDouble(macrosData['pre_run_protein_g_optional'], 'pre_run_protein_g_optional'),
        fatCapG: toDouble(macrosData['pre_run_fat_g_cap'], 'pre_run_fat_g_cap'),
        fluidsMl: toDouble(macrosData['pre_run_water_ml'], 'pre_run_water_ml'),
        sodiumMg: toDouble(macrosData['pre_run_sodium_mg'], 'pre_run_sodium_mg'),
      ),
      duringRun: DuringRunMacros(
        carbRateGPerH: toDouble(macrosData['during_rate_g_per_h'], 'during_rate_g_per_h'),
        carbTotalG: toDouble(macrosData['during_total_g'], 'during_total_g'),
        fluidRateMlPerH: toDouble(macrosData['during_water_rate_ml_per_h'], 'during_water_rate_ml_per_h'),
        fluidTotalMl: toDouble(macrosData['during_water_total_ml'], 'during_water_total_ml'),
        sodiumRateMgPerH: toDouble(macrosData['during_sodium_rate_mg_per_h'], 'during_sodium_rate_mg_per_h'),
        sodiumTotalMg: toDouble(macrosData['during_sodium_total_mg'], 'during_sodium_total_mg'),
        massNormRateGPerH: toDouble(macrosData['during_mass_norm_rate_g_per_h'], 'during_mass_norm_rate_g_per_h'),
        absClampRangeGPerH: toDoubleList(macrosData['during_abs_clamp_range_g_per_h']),
      ),
      postRun: PostRunMacros(
        carbsG: toDouble(macrosData['post_run_carbs_g'], 'post_run_carbs_g'),
        proteinG: toDouble(macrosData['post_run_protein_g'], 'post_run_protein_g'),
        fluidsMl: toDouble(macrosData['post_run_water_ml'], 'post_run_water_ml'),
        sodiumMg: toDouble(macrosData['post_run_sodium_mg'], 'post_run_sodium_mg'),
      ),
      metrics: RunMetrics(
        distanceMi: toDouble(macrosData['distance_mi'], 'distance_mi'),
        distanceKm: toDouble(macrosData['distance_km'], 'distance_km'),
        durationH: toDouble(macrosData['duration_h'], 'duration_h'),
        durationMin: toDouble(macrosData['duration_min'], 'duration_min'),
        paceMinPerMile: toDouble(macrosData['pace_min_per_mile'], 'pace_min_per_mile'),
        speedMph: toDouble(macrosData['speed_mph'], 'speed_mph'),
        caloriesNetKcal: toDouble(macrosData['calories_net_kcal'], 'calories_net_kcal'),
        caloriesGrossKcal: toDouble(macrosData['calories_gross_kcal'], 'calories_gross_kcal'),
        met: toDouble(macrosData['MET'], 'MET'),
      ),
      calculationRule: macrosData['pre_run_carbs_rule'] ?? 'Generated from edge function',
      timestamp: DateTime.now(),
      isUserModified: false,
    );

    // Cache the macro targets
    final repository = await ref.read(macroRepositoryProvider.future);
    await repository.saveMacroTargets(macroTargets);

    // Track successful macro generation
    AnalyticsService.trackNutritionPlanGenerated(
      distanceMiles: distanceMiles,
      paceMinutesPerMile: paceMinutesPerMile,
      totalCalories: macroTargets.metrics.caloriesNetKcal.round(),
      totalCarbs: (macroTargets.preRun.carbsG + macroTargets.duringRun.carbTotalG + macroTargets.postRun.carbsG).round(),
      beforeRunItems: 1, // Simplified for now
      duringRunItems: 1,
      afterRunItems: 1,
      isFirstPlan: true, // Could be enhanced to check if this is actually first plan
    );
  }

  /// Update a specific macro value and recalculate linked values
  Future<void> updateMacroValue({
    required MacroSection section,
    required MacroField field, 
    required double newValue,
  }) async {
    final repository = await ref.read(macroRepositoryProvider.future);
    final cachedTargets = await repository.getCachedMacroTargets();
    
    if (cachedTargets == null) return;
    
    // Track macro adjustment using documented macros_changed event
    final oldValue = _getFieldCurrentValue(cachedTargets, field);
    AnalyticsService.trackMacrosChanged(
      planId: 'pre_generation', // No actual plan exists yet - this is pre-generation editing
      screen: 'adjust_macros_screen',
      experimentVariant: 'auto_items_v1', // Default variant
      macro: '${section.name}_${field.name}', // e.g., "preRun_carbsG"
      oldValue: oldValue ?? 0.0,
      newValue: newValue,
    );

    try {
      final updatedTargets = await repository.updateMacroTargets(
        cachedTargets,
        section,
        field,
        newValue,
      );

      // Track successful update
      AnalyticsService.track('Macro Value Updated Successfully', properties: {
        'Section': section.name,
        'Field': field.name,
        'Final Value': newValue,
      });

      // Refresh state with updated targets
      final currentState = state.valueOrNull;
      if (currentState != null) {
        state = AsyncData(currentState.copyWith(macroTargets: updatedTargets));
      }

    } catch (error, stackTrace) {
      // Track error
      AnalyticsService.trackError(
        errorType: 'Macro Update Error',
        errorMessage: error.toString(),
        screenName: 'Adjust Macros',
        additionalContext: {
          'Section': section.name,
          'Field': field.name,
          'Attempted Value': newValue,
        },
      );
      
      rethrow;
    }
  }

  /// Reset all values to the original recommended values
  Future<void> resetToRecommended() async {
    final repository = await ref.read(macroRepositoryProvider.future);
    final cachedTargets = await repository.getCachedMacroTargets();
    
    if (cachedTargets == null) return;

    // Track reset action
    AnalyticsService.track('Macro Values Reset', properties: {
      'Previous Modifications Count': _countModifiedFields(cachedTargets),
    });

    try {
      // Get the original macro targets that were stored when first generated
      final originalTargets = await repository.getOriginalMacroTargets();
      
      if (originalTargets != null) {
        // Use the original targets with updated ID and timestamp to replace current
        final restoredTargets = originalTargets.copyWith(
          id: cachedTargets.id, // Keep the current ID
          timestamp: DateTime.now(), // Update timestamp
          isUserModified: false,
          modifiedFields: [],
        );
        
        // Save the restored targets back to cache
        await repository.saveMacroTargets(restoredTargets);
        
        // Track successful reset
        AnalyticsService.track('Macro Values Reset Successfully');
        
        // Update state with the restored targets
        final currentState = state.valueOrNull;
        if (currentState != null) {
          state = AsyncData(currentState.copyWith(macroTargets: restoredTargets));
        }
      } else {
        // Fallback: if no original targets found, just clear modification flags
        print('DEBUG: No original targets found, falling back to clearing modification flags');
        final fallbackTargets = cachedTargets.copyWith(
          isUserModified: false,
          modifiedFields: [],
        );
        
        await repository.saveMacroTargets(fallbackTargets);
        
        final currentState = state.valueOrNull;
        if (currentState != null) {
          state = AsyncData(currentState.copyWith(macroTargets: fallbackTargets));
        }
      }
      
    } catch (error, stackTrace) {
      // Track error
      AnalyticsService.trackError(
        errorType: 'Macro Reset Error',
        errorMessage: error.toString(),
        screenName: 'Adjust Macros',
      );
      
      rethrow;
    }
  }

  /// Save all macro changes from the adjust macros screen
  Future<void> saveAllMacroChanges({
    // Pre-run values
    required double preRunCarbs,
    required double preRunProtein, 
    required double preRunFluids,
    required double preRunSodium,
    // During-run values
    required double duringRunCarbs,
    required double duringRunFluids,
    required double duringRunSodium,
    // Post-run values
    required double postRunCarbs,
    required double postRunProtein,
    required double postRunFluids,
    required double postRunSodium,
  }) async {
    try {
      // Update all values in sequence
      await updateMacroValue(
        section: MacroSection.preRun,
        field: MacroField.preRunCarbs,
        newValue: preRunCarbs,
      );
      await updateMacroValue(
        section: MacroSection.preRun,
        field: MacroField.preRunProtein,
        newValue: preRunProtein,
      );
      await updateMacroValue(
        section: MacroSection.preRun,
        field: MacroField.preRunFluids,
        newValue: preRunFluids,
      );
      await updateMacroValue(
        section: MacroSection.preRun,
        field: MacroField.preRunSodium,
        newValue: preRunSodium,
      );
      
      // During-run values
      await updateMacroValue(
        section: MacroSection.duringRun,
        field: MacroField.duringRunCarbTotal,
        newValue: duringRunCarbs,
      );
      await updateMacroValue(
        section: MacroSection.duringRun,
        field: MacroField.duringRunFluidTotal,
        newValue: duringRunFluids,
      );
      await updateMacroValue(
        section: MacroSection.duringRun,
        field: MacroField.duringRunSodiumTotal,
        newValue: duringRunSodium,
      );
      
      // Post-run values
      await updateMacroValue(
        section: MacroSection.postRun,
        field: MacroField.postRunCarbs,
        newValue: postRunCarbs,
      );
      await updateMacroValue(
        section: MacroSection.postRun,
        field: MacroField.postRunProtein,
        newValue: postRunProtein,
      );
      await updateMacroValue(
        section: MacroSection.postRun,
        field: MacroField.postRunFluids,
        newValue: postRunFluids,
      );
      await updateMacroValue(
        section: MacroSection.postRun,
        field: MacroField.postRunSodium,
        newValue: postRunSodium,
      );
      
      // Track successful save
      AnalyticsService.track('All Macro Changes Saved Successfully');
      
    } catch (error, stackTrace) {
      // Track error
      AnalyticsService.trackError(
        errorType: 'Save All Macros Error',
        errorMessage: error.toString(),
        screenName: 'Adjust Macros',
      );
      
      rethrow;
    }
  }

  /// Create nutrition plan with adjusted values
  Future<void> createNutritionPlan() async {
    final repository = await ref.read(macroRepositoryProvider.future);
    final macroTargets = await repository.getCachedMacroTargets();
    
    if (macroTargets == null) return;

    final currentState = state.valueOrNull;
    if (currentState == null) return;

    // Set creating plan state
    state = AsyncData(currentState.copyWith(isCreatingPlan: true));

    final modifiedFieldsCount = _countModifiedFields(macroTargets);
    
    // Track plan creation start
    AnalyticsService.timeEvent('Nutrition Plan Created from Adjusted Macros');
    AnalyticsService.track('Nutrition Plan Creation Started from Adjusted Macros', properties: {
      'Distance (miles)': macroTargets.metrics.distanceMi,
      'Duration (hours)': macroTargets.metrics.durationH,
      'Modified Fields Count': modifiedFieldsCount,
    });

    state = await AsyncValue.guard(() async {
      try {
        // Call the LLM service with adjusted macro targets
        final llmService = ref.read(llmNutritionPlanServiceProvider);
        final nutritionPlan = await llmService.generateLLMNutritionPlanFromMacros(
          macroTargets: macroTargets,
        );

        if (nutritionPlan != null) {
          // Track successful plan creation
          AnalyticsService.track('Nutrition Plan Created from Adjusted Macros', properties: {
            'Distance (miles)': macroTargets.metrics.distanceMi,
            'Duration (hours)': macroTargets.metrics.durationH,
            'Total Calories': macroTargets.metrics.caloriesNetKcal.round(),
            'Pre Run Carbs (g)': macroTargets.preRun.carbsG,
            'During Run Carbs (g)': macroTargets.duringRun.carbTotalG,
            'Post Run Carbs (g)': macroTargets.postRun.carbsG,
            'Modified Fields Count': modifiedFieldsCount,
            'Plan Type': 'LLM Generated',
          });

          // Use setGeneratedPlan to mark as unsaved and save temporarily with planId
          await ref.read(nutritionPlanControllerProvider.notifier).setGeneratedPlan(
            nutritionPlan, 
            planId: currentState.planId, // Get planId from state
          );
          
          return currentState.copyWith(isCreatingPlan: false);
        } else {
          // LLM service returned null, indicating fallback needed
          throw Exception('LLM service failed, fallback to algorithm needed');
        }
        
      } catch (error, stackTrace) {
        // Track error
        AnalyticsService.trackError(
          errorType: 'Plan Creation Error',
          errorMessage: error.toString(),
          screenName: 'Adjust Macros',
          additionalContext: {
            'Distance (miles)': macroTargets.metrics.distanceMi,
            'Modified Fields Count': modifiedFieldsCount,
          },
        );
        
        rethrow;
      }
    });
  }

  /// Helper method to get current value of a field
  double? _getFieldCurrentValue(MacroTargets? macroTargets, MacroField field) {
    if (macroTargets == null) return null;
    
    switch (field) {
      // Pre-run fields
      case MacroField.preRunCarbs:
        return macroTargets.preRun.carbsG;
      case MacroField.preRunProtein:
        return macroTargets.preRun.proteinG;
      case MacroField.preRunFatCap:
        return macroTargets.preRun.fatCapG;
      case MacroField.preRunFluids:
        return macroTargets.preRun.fluidsFlOz;
      case MacroField.preRunSodium:
        return macroTargets.preRun.sodiumMg;
      
      // During-run fields
      case MacroField.duringRunCarbTotal:
        return macroTargets.duringRun.carbTotalG;
      case MacroField.duringRunFluidTotal:
        return macroTargets.duringRun.fluidTotalFlOz;
      case MacroField.duringRunSodiumTotal:
        return macroTargets.duringRun.sodiumTotalMg;
      
      // Post-run fields
      case MacroField.postRunCarbs:
        return macroTargets.postRun.carbsG;
      case MacroField.postRunProtein:
        return macroTargets.postRun.proteinG;
      case MacroField.postRunFluids:
        return macroTargets.postRun.fluidsFlOz;
      case MacroField.postRunSodium:
        return macroTargets.postRun.sodiumMg;
      
      // Unused fields for this implementation
      default:
        return null;
    }
  }

  /// Helper method to count modified fields
  int _countModifiedFields(MacroTargets macroTargets) {
    return macroTargets.modifiedFields.length;
  }

  /// Refresh content from backend
  Future<void> refreshContent() async {
    await _contentService.refreshFromBackend();
    ref.invalidateSelf();
  }
}