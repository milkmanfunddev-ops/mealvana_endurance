// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:riverpod_annotation/riverpod_annotation.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../domain/carb_loading_plan_simple.dart';
// import '../../../shared/services/logging_service.dart';

// part 'carb_loading_edge_service.g.dart';

// /// Response from the carb loading edge function
// class CarbLoadingEdgeResponse {
//   final bool success;
//   final Map<String, dynamic>? plan;
//   final String? error;
//   final Map<String, dynamic> metadata;

//   const CarbLoadingEdgeResponse({
//     required this.success,
//     this.plan,
//     this.error,
//     required this.metadata,
//   });

//   factory CarbLoadingEdgeResponse.fromJson(Map<String, dynamic> json) {
//     return CarbLoadingEdgeResponse(
//       success: json['success'] ?? false,
//       plan: json['plan'] as Map<String, dynamic>?,
//       error: json['error'] as String?,
//       metadata: json['metadata'] as Map<String, dynamic>? ?? {},
//     );
//   }
// }

// @riverpod
// CarbLoadingEdgeService carbLoadingEdgeService(Ref ref) {
//   return CarbLoadingEdgeService(
//     logger: AppLogger.instance,
//   );
// }

// /// Service for calling the carb loading edge function
// class CarbLoadingEdgeService {
//   const CarbLoadingEdgeService({
//     required this.logger,
//   });

//   final LoggingService logger;

//   /// Call Supabase Edge Function for carb loading calculations
//   Future<CarbLoadingEdgeResponse> calculateCarbLoading({
//     required DateTime raceDate,
//     required RaceDistance raceDistance,
//     required TrainingVolume trainingVolume,
//     required double bodyWeightPounds,
//     String? userId,
//   }) async {
//     try {
//       // Prepare request data
//       final requestData = {
//         'raceDate': raceDate.toIso8601String(),
//         'raceDistance': raceDistance.value,
//         'trainingVolume': trainingVolume.value,
//         'bodyWeightPounds': bodyWeightPounds,
//         if (userId != null) 'userId': userId,
//       };

//       logger.info('Calling carb loading edge function',
//         context: 'CARB_LOADING_EDGE_FUNCTION',
//         data: requestData
//       );

//       // Make HTTP request to edge function
//       final response = await http.post(
//         Uri.parse('https://wvmvsodrvbkxfydabqed.supabase.co/functions/v1/carb-loading'),
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind2bXZzb2RydmJreGZ5ZGFicWVkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUyOTMxMDcsImV4cCI6MjA3MDg2OTEwN30.pG2IYdEIIFS8_zPxzr6pZplzWQqvD13dvslrpFMAPCk',
//         },
//         body: jsonEncode(requestData),
//       );

//       if (response.statusCode == 200) {
//         final responseData = jsonDecode(response.body) as Map<String, dynamic>;

//         logger.info('Edge function call successful',
//           context: 'CARB_LOADING_EDGE_FUNCTION',
//           data: {
//             'success': responseData['success'],
//             'has_plan': responseData['plan'] != null,
//           }
//         );

//         return CarbLoadingEdgeResponse.fromJson(responseData);
//       } else {
//         logger.error('Edge function HTTP error',
//           context: 'CARB_LOADING_EDGE_FUNCTION',
//           error: 'HTTP ${response.statusCode}: ${response.body}'
//         );

//         return CarbLoadingEdgeResponse(
//           success: false,
//           error: 'Edge function HTTP error: ${response.statusCode}',
//           metadata: {},
//         );
//       }
//     } catch (e, stackTrace) {
//       logger.error('Failed to call carb loading edge function',
//         context: 'CARB_LOADING_EDGE_FUNCTION',
//         error: e,
//         stackTrace: stackTrace
//       );

//       return CarbLoadingEdgeResponse(
//         success: false,
//         error: 'Network error: ${e.toString()}',
//         metadata: {},
//       );
//     }
//   }

//   /// Get enhanced carb targets with edge function calculations
//   Future<Map<String, dynamic>> getEnhancedCarbTargets({
//     required DateTime raceDate,
//     required RaceDistance raceDistance,
//     required TrainingVolume trainingVolume,
//     required double bodyWeightPounds,
//     String? userId,
//   }) async {
//     final response = await calculateCarbLoading(
//       raceDate: raceDate,
//       raceDistance: raceDistance,
//       trainingVolume: trainingVolume,
//       bodyWeightPounds: bodyWeightPounds,
//       userId: userId,
//     );

//     if (response.success && response.plan != null) {
//       return response.plan!;
//     } else {
//       logger.warning('Edge function failed, using fallback calculations',
//         context: 'CARB_LOADING_EDGE_FUNCTION',
//         data: {'error': response.error}
//       );

//       // Fallback to local calculations if edge function fails
//       return _calculateFallbackTargets(
//         raceDistance: raceDistance,
//         trainingVolume: trainingVolume,
//         bodyWeightPounds: bodyWeightPounds,
//       );
//     }
//   }

//   /// Fallback calculations if edge function is unavailable
//   Map<String, dynamic> _calculateFallbackTargets({
//     required RaceDistance raceDistance,
//     required TrainingVolume trainingVolume,
//     required double bodyWeightPounds,
//   }) {
//     final bodyWeightKg = bodyWeightPounds * 0.453592;
//     final baseCarbs = 10.0; // Use 10g/kg as base for edge function parity
//     final raceMultiplier = CarbLoadingPlan.getRaceDistanceMultiplier(raceDistance);
//     final volumeMultiplier = CarbLoadingPlan.getTrainingVolumeMultiplier(trainingVolume);
//     final carbsPerKg = baseCarbs * raceMultiplier * volumeMultiplier;
//     final totalCarbsG = (bodyWeightKg * carbsPerKg).round();

//     return {
//       'bodyWeightKg': bodyWeightKg,
//       'targetCarbsGPerKg': carbsPerKg,
//       'dayMinusTwo': {
//         'totalCarbsG': (totalCarbsG * 0.85).round(),
//         'carbsGPerKg': carbsPerKg * 0.85,
//       },
//       'dayMinusOne': {
//         'totalCarbsG': totalCarbsG,
//         'carbsGPerKg': carbsPerKg,
//       },
//       'raceDay': {
//         'totalCarbsG': (totalCarbsG * 0.6).round(),
//         'carbsGPerKg': carbsPerKg * 0.6,
//       },
//       'notes': 'Fallback calculation - edge function unavailable',
//     };
//   }
// }