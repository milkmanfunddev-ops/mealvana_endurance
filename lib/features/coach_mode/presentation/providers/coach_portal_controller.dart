import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'coach_portal_controller.g.dart';

/// Navigation sections in the coach portal sidebar
enum PortalSection {
  athletes,
  reports,
  messages,
}

/// Controller for coach portal UI state (selected athlete, active section)
@riverpod
class CoachPortalController extends _$CoachPortalController {
  @override
  CoachPortalState build() {
    return const CoachPortalState();
  }

  void selectAthlete(String relationshipId) {
    state = state.copyWith(
      selectedRelationshipId: relationshipId,
      activeSection: PortalSection.athletes,
    );
  }

  void setSection(PortalSection section) {
    state = state.copyWith(activeSection: section);
  }
}

/// Portal UI state - tracks which athlete/section is selected
class CoachPortalState {
  final String? selectedRelationshipId;
  final PortalSection activeSection;

  const CoachPortalState({
    this.selectedRelationshipId,
    this.activeSection = PortalSection.athletes,
  });

  CoachPortalState copyWith({
    String? selectedRelationshipId,
    PortalSection? activeSection,
  }) {
    return CoachPortalState(
      selectedRelationshipId:
          selectedRelationshipId ?? this.selectedRelationshipId,
      activeSection: activeSection ?? this.activeSection,
    );
  }
}
