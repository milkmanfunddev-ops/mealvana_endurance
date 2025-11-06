import 'dart:convert';
import 'package:flutter/material.dart';

/// Represents a feature that users can vote for
class Feature {
  const Feature({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });

  final String id; // e.g., 'shopping_list'
  final String name; // e.g., 'Automated Shopping List'
  final String description; // e.g., 'Generate a grocery list...'
  final IconData icon;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Feature &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Survey response model
class FeatureSurveyResponse {
  const FeatureSurveyResponse({
    required this.id,
    required this.deviceId,
    required this.selectedFeatures,
    required this.votedAt,
  });

  final String id; // UUID
  final String deviceId;
  final List<Feature> selectedFeatures; // Exactly 3
  final DateTime votedAt;

  /// Convert to JSON for Mixpanel
  Map<String, dynamic> toMixpanelProperties() => {
        'selected_features': selectedFeatures.map((f) => f.id).toList(),
        'total_votes': selectedFeatures.length,
        'survey_version': 'features_v1',
        'device_id': deviceId,
        'timestamp': votedAt.toIso8601String(),
      };

  /// Convert to Drift database format
  Map<String, dynamic> toDatabaseJson() => {
        'id': id,
        'device_id': deviceId,
        'selected_features':
            jsonEncode(selectedFeatures.map((f) => f.id).toList()),
        'voted_at': votedAt.toIso8601String(),
      };

  /// Create from database row
  factory FeatureSurveyResponse.fromDatabase(
    Map<String, dynamic> row,
    List<Feature> allFeatures,
  ) {
    final selectedIds = (jsonDecode(row['selected_features']) as List)
        .map((e) => e as String)
        .toList();

    return FeatureSurveyResponse(
      id: row['id'],
      deviceId: row['device_id'],
      selectedFeatures:
          allFeatures.where((f) => selectedIds.contains(f.id)).toList(),
      votedAt: DateTime.parse(row['voted_at']),
    );
  }
}

/// Controller state
class FeatureSurveyState {
  const FeatureSurveyState({
    required this.availableFeatures,
    required this.selectedFeatures,
    required this.hasVoted,
    this.previousVotes,
    this.isSubmitting = false,
  });

  final List<Feature> availableFeatures; // All 5 features
  final List<Feature> selectedFeatures; // User's current selections (0-3)
  final bool hasVoted; // Has user already voted?
  final FeatureSurveyResponse? previousVotes; // Their previous submission
  final bool isSubmitting;

  bool get canSubmit => selectedFeatures.length == 3 && !isSubmitting;

  FeatureSurveyState copyWith({
    List<Feature>? availableFeatures,
    List<Feature>? selectedFeatures,
    bool? hasVoted,
    FeatureSurveyResponse? previousVotes,
    bool? isSubmitting,
  }) {
    return FeatureSurveyState(
      availableFeatures: availableFeatures ?? this.availableFeatures,
      selectedFeatures: selectedFeatures ?? this.selectedFeatures,
      hasVoted: hasVoted ?? this.hasVoted,
      previousVotes: previousVotes ?? this.previousVotes,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

/// Pre-defined features (can be moved to ContentService later)
class FeatureDefinitions {
  static const List<Feature> allFeatures = [
    Feature(
      id: 'shopping_list',
      name: 'Automated Shopping List',
      description:
          'Generate a grocery list based on the meals and products in your plan.',
      icon: Icons.shopping_cart,
    ),
    Feature(
      id: 'coach_sharing',
      name: 'Coach/Nutritionist Sharing',
      description:
          'Securely share your Mealvana Endurance plan with your personal coach or dietitian for easier collaboration.',
      icon: Icons.share,
    ),
    Feature(
      id: 'recipe_inspiration',
      name: 'Daily Recipe Inspiration',
      description:
          'Quick, healthy meal and snack ideas designed to provide general nutrition to complement your current training fueling plan (beyond race-day fueling).',
      icon: Icons.restaurant_menu,
    ),
    Feature(
      id: 'calorie_tracker',
      name: 'Total Calorie Tracker',
      description:
          'A simple tool to view and track your overall daily caloric intake.',
      icon: Icons.analytics,
    ),
    Feature(
      id: 'dietary_filters',
      name: 'Advanced Dietary Filters',
      description:
          'Expand personalization to support specific dietary needs, such as adding options for vegan/vegetarian, low-FODMAP, or other common food allergies/intolerances.',
      icon: Icons.filter_list,
    ),
  ];
}
