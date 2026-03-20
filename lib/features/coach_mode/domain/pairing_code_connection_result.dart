import 'coach_athlete_relationship.dart';

/// Specific reasons why connecting via pairing code can fail.
enum PairingCodeConnectFailureReason {
  noUserProfile,
  notApprovedCoach,
  invalidCodeFormat,
  codeNotFound,
  codeAlreadyUsed,
  codeExpired,
  selfConnectionNotAllowed,
  relationshipAlreadyExists,
  unknown,
}

/// Result of attempting to connect a coach to an athlete via pairing code.
class PairingCodeConnectResult {
  const PairingCodeConnectResult._({this.relationship, this.failureReason});

  final CoachAthleteRelationship? relationship;
  final PairingCodeConnectFailureReason? failureReason;

  bool get isSuccess => relationship != null;

  static PairingCodeConnectResult success(
    CoachAthleteRelationship relationship,
  ) => PairingCodeConnectResult._(relationship: relationship);

  static PairingCodeConnectResult failure(
    PairingCodeConnectFailureReason reason,
  ) => PairingCodeConnectResult._(failureReason: reason);
}
