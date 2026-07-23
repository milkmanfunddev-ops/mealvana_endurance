import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/logging_service.dart';
import '../../formula_kit/application/default_formula_selector.dart';
import '../../formula_kit/data/during_workout_templates_repository.dart';
import '../../formula_kit/data/formula_pins_repository.dart';
import '../../formula_kit/data/post_workout_templates_repository.dart';
import '../../formula_kit/domain/formula_pin.dart';

/// Seeds a new user with real system-formula pins at onboarding completion so
/// they start out "formula-first" with owned, editable formulas for their
/// primary sport — instead of relying only on the ephemeral generation-time
/// safety net (plan Phase 1 #3).
///
/// Best-effort: any failure is logged and swallowed so it can never block
/// onboarding. Idempotent — [FormulaPinsRepository.pin] returns the existing
/// pin if one is already active, so re-running is safe.
class OnboardingFormulaPinService {
  OnboardingFormulaPinService(
    this._duringRepo,
    this._postRepo,
    this._pinsRepo, {
    AppLogger? logger,
  }) : _logger = logger ?? const NoopAppLogger();

  final DuringWorkoutTemplatesRepository _duringRepo;
  final PostWorkoutTemplatesRepository _postRepo;
  final FormulaPinsRepository _pinsRepo;
  final AppLogger _logger;

  /// Priority order for choosing a single primary sport when the user selected
  /// several. Running is the app's default discipline.
  static const List<String> _sportPriority = ['running', 'cycling', 'swimming'];

  /// Pick the primary sport from the user's selected set.
  static String primarySport(Set<String> selectedSports) {
    for (final sport in _sportPriority) {
      if (selectedSports.contains(sport)) return sport;
    }
    return selectedSports.isNotEmpty ? selectedSports.first : 'running';
  }

  /// Select best-fit during + after system formulas for the primary sport and
  /// write real pins. Before-phase is intentionally skipped — its system
  /// templates are time-window based (no activity/priority best-fit), and the
  /// before phase is handled holistically by the before-phase pin-first work.
  Future<void> autoPinDefaults({
    required String userId,
    required Set<String> selectedSports,
    String? diet,
    List<String> allergies = const [],
  }) async {
    try {
      final sport = primarySport(selectedSports);

      final duringTemplates = await _duringRepo.getAll();
      final duringId = DefaultFormulaSelector.selectDuring(
        duringTemplates,
        activityType: sport,
        diet: diet,
        allergies: allergies,
      );
      if (duringId != null) {
        await _pinsRepo.pin(
          userId: userId,
          templateId: duringId,
          kind: TemplateKind.duringSystem,
        );
      }

      final postTemplates = await _postRepo.getAll();
      final postId = DefaultFormulaSelector.selectPost(
        postTemplates,
        activityType: sport,
        diet: diet,
        allergies: allergies,
      );
      if (postId != null) {
        await _pinsRepo.pin(
          userId: userId,
          templateId: postId,
          kind: TemplateKind.postSystem,
        );
      }

      _logger.info(
        'Auto-pinned default formulas at onboarding',
        context: 'ONBOARDING_FORMULA_PIN',
        data: {
          'sport': sport,
          'during_pinned': duringId != null,
          'post_pinned': postId != null,
        },
      );
    } catch (e, stackTrace) {
      // Best-effort only: never block onboarding on pin seeding.
      _logger.warning(
        'Auto-pin default formulas failed (non-fatal)',
        context: 'ONBOARDING_FORMULA_PIN',
        data: {'error': e.toString()},
      );
      _logger.debug('$stackTrace', context: 'ONBOARDING_FORMULA_PIN');
    }
  }
}

/// Riverpod provider for [OnboardingFormulaPinService].
final onboardingFormulaPinServiceProvider =
    Provider<OnboardingFormulaPinService>((ref) {
      return OnboardingFormulaPinService(
        ref.watch(duringWorkoutTemplatesRepositoryProvider),
        ref.watch(postWorkoutTemplatesRepositoryProvider),
        ref.watch(formulaPinsRepositoryProvider),
        logger: ref.watch(appLoggerProvider),
      );
    });
