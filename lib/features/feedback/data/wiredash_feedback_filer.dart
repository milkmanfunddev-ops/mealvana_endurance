// The Wiredash SDK (2.6.x) has no public headless submit: `lib/wiredash.dart`
// exports only the widget and `WiredashController.show()`, and the live
// submitter behind the widget is reachable only through a
// `@visibleForTesting` getter that throws in release. What it does have is a
// self-contained service graph (`WiredashServices`) that the widget itself
// builds; a second, private graph filed against the same project posts to
// the same `api.wiredash.io/sdk/sendFeedback` endpoint with the same
// project/secret, install id (shared prefs), device metadata and retry queue
// as a shaken report. That is the path this file takes. It is an
// implementation import, so `wiredash` is pinned exactly in pubspec.yaml
// and this file is the only place that reads `package:wiredash/src/`.
// ignore_for_file: implementation_imports

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:wiredash/src/core/services/services.dart'
    show WiredashServices;
import 'package:wiredash/src/feedback/data/feedback_submitter.dart'
    show SubmissionState;
import 'package:wiredash/src/metadata/session_meta_data.dart'
    show SessionMetaData;
import 'package:wiredash/wiredash.dart';

import '../../../shared/services/app_config.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/support/support_identity.dart';
import '../domain/typed_feedback.dart';

/// Files feedback the athlete typed to Vana into the Wiredash inbox, silently
/// (no UI), so it sits next to shaken reports (mp-245 clause 6, ticket 26).
///
/// The seam: `VanaChatController` calls [file] when a `feedback_saved` part
/// arrives; tests substitute a fake for the SDK.
abstract class WiredashFeedbackFiler {
  Future<void> file(TypedFeedback feedback);
}

final wiredashFeedbackFilerProvider = Provider<WiredashFeedbackFiler>((ref) {
  final config = ref.watch(appConfigProvider);
  final deps = ref.watch(appExternalDepsProvider);
  return WiredashSdkFeedbackFiler(
    projectId: config.wiredashProjectId,
    secret: config.wiredashSecret,
    logger: deps.logger,
    currentUser: () => deps.supabaseClient.auth.currentUser,
  );
});

/// Files through the Wiredash SDK's own submitter: real device metadata, the
/// app's install id, and the SDK's persisted retry queue when offline.
///
/// No label is attached: the hidden `Bug Report` label on the root widget
/// marks the screenshot path; typed feedback is identified by the custom
/// metadata below (`source`, `sentiment`, `about`, `conversation_id`).
class WiredashSdkFeedbackFiler implements WiredashFeedbackFiler {
  WiredashSdkFeedbackFiler({
    required this.projectId,
    required this.secret,
    required AppLogger logger,
    required this.currentUser,
    @visibleForTesting WiredashServices Function()? servicesFactory,
  }) : _logger = logger,
       _services = servicesFactory ?? WiredashServices.new;

  final String projectId;
  final String secret;
  final AppLogger _logger;

  /// Supabase's current user, read at filing time (id + email for the entry).
  final User? Function() currentUser;
  final WiredashServices Function() _services;

  static const _context = 'WIREDASH_FEEDBACK_FILER';
  static const source = 'vana_chat';

  @override
  Future<void> file(TypedFeedback feedback) async {
    final services = _services();
    try {
      services.updateWidget(
        Wiredash(
          projectId: projectId,
          secret: secret,
          feedbackOptions: const WiredashFeedbackOptions(
            email: EmailPrompt.hidden,
            screenshot: ScreenshotPrompt.hidden,
          ),
          child: const SizedBox.shrink(),
        ),
      );
      final dispatcher = WidgetsBinding.instance.platformDispatcher;
      services.wiredashModel.sessionMetaData = SessionMetaData(
        appLocale: dispatcher.locale,
        appBrightness: dispatcher.platformBrightness,
      );
      final user = currentUser();
      services.wiredashModel.customizableMetaData = services
          .wiredashModel
          .customizableMetaData
          .copyWith(
            userId: user?.id,
            userEmail: resolveSupportEmail([user?.email]),
            custom: {
              'source': source,
              'sentiment': feedback.sentiment,
              'about': feedback.about,
              if (feedback.conversationId != null)
                'conversation_id': feedback.conversationId,
            },
          );

      final model = services.feedbackModel..feedbackMessage = feedback.message;
      final item = await model.createFeedback();
      final state = await services.feedbackSubmitter.submit(item);
      _logger.info(
        'Typed feedback filed to Wiredash',
        context: _context,
        data: {
          'state': state.name,
          'about': feedback.about,
          'sentiment': feedback.sentiment,
          'conversationId': feedback.conversationId,
        },
      );
      if (state != SubmissionState.submitted &&
          state != SubmissionState.pending) {
        throw StateError('wiredash submission state: ${state.name}');
      }
    } finally {
      services.dispose();
    }
  }
}
