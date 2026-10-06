import 'dart:async';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:intl/intl.dart';
import '../../../content/application/content_service.dart';
import '../../domain/share_form_data.dart';
import '../../domain/share_result.dart';
import '../../application/pdf_generator_service.dart';
import '../../application/email_service.dart';
import '../../../nutrition_plan/domain/nutrition_plan.dart';
import '../../../../shared/services/analytics/analytics_tracker.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/database/database_provider.dart';
import '../../../../shared/services/report/report.dart';

part 'share_form_controller.g.dart';

class ShareFormState {
  const ShareFormState({
    required this.recipientEmail,
    required this.senderName,
    required this.subject,
    required this.comments,
    this.isSending = false,
    this.lastResult,
  });

  final String recipientEmail;
  final String senderName;
  final String subject;
  final String comments;
  final bool isSending;
  final ShareResult? lastResult;

  ShareFormState copyWith({
    String? recipientEmail,
    String? senderName,
    String? subject,
    String? comments,
    bool? isSending,
    ShareResult? lastResult,
  }) {
    return ShareFormState(
      recipientEmail: recipientEmail ?? this.recipientEmail,
      senderName: senderName ?? this.senderName,
      subject: subject ?? this.subject,
      comments: comments ?? this.comments,
      isSending: isSending ?? this.isSending,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

@riverpod
class ShareFormController extends _$ShareFormController {
  ContentService get _contentService => ref.read(contentServiceProvider);
  PdfGeneratorService get _pdfService => ref.read(pdfGeneratorServiceProvider);
  EmailService get _emailService => ref.read(emailServiceProvider);
  AnalyticsTracker get _analytics => ref.read(analyticsTrackerProvider);
  AppDatabase get _database => ref.read(appDatabaseProvider);

  @override
  FutureOr<ShareFormState> build(NutritionPlan nutritionPlan) async {
    final database = _database;
    final contentService = _contentService;

    // Get sender name from database
    final user = await database.userDao.getCurrentUserProfile();
    final userEntry = user != null
        ? await (database.select(
            database.userProfilesTable,
          )..where((u) => u.id.equals(user.id))).getSingleOrNull()
        : null;
    final senderName = userEntry?.senderName ?? '';

    final activityDate = nutritionPlan.runDateTime != null
        ? DateFormat('MMMM d, yyyy').format(nutritionPlan.runDateTime!)
        : 'TBD';

    final defaultSubjectTemplate = contentService.getValue(
      'sharing.subject_default',
      defaultValue: 'Nutrition Plan on {date}',
    );
    final defaultSubject = defaultSubjectTemplate.replaceAll(
      '{date}',
      activityDate,
    );

    final defaultComments = contentService.getValue(
      'sharing.comments_default',
      defaultValue: "Here's my nutrition plan from Mealvana Endurance",
    );

    return ShareFormState(
      recipientEmail: '',
      senderName: senderName,
      subject: defaultSubject,
      comments: defaultComments,
    );
  }

  void updateRecipientEmail(String email) {
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncValue.data(currentState.copyWith(recipientEmail: email));
    }
  }

  void updateSenderName(String name) {
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncValue.data(currentState.copyWith(senderName: name));
    }
  }

  void updateSubject(String subject) {
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncValue.data(currentState.copyWith(subject: subject));
    }
  }

  void updateComments(String comments) {
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncValue.data(currentState.copyWith(comments: comments));
    }
  }

  Future<ShareResult> sendPlan(NutritionPlan nutritionPlan) async {
    final currentState = state.value;
    if (currentState == null) {
      return ShareResult.failure(error: 'Form not initialized');
    }

    state = AsyncValue.data(currentState.copyWith(isSending: true));

    // Read before the first await: the screen can leave mid-send and dispose
    // this provider, but the send and its bookkeeping still finish.
    final report = ref.read(reportProvider);
    final pdfService = _pdfService;
    final emailService = _emailService;
    final analytics = _analytics;
    final database = _database;

    try {
      final pdfBytes = await pdfService.generateNutritionPlanPdf(
        nutritionPlan: nutritionPlan,
        sentDate: DateTime.now(),
        senderName: currentState.senderName.isNotEmpty
            ? currentState.senderName
            : null,
      );

      final formData = ShareFormData(
        recipientEmail: currentState.recipientEmail,
        senderName: currentState.senderName.isNotEmpty
            ? currentState.senderName
            : null,
        subject: currentState.subject.isNotEmpty ? currentState.subject : null,
        comments: currentState.comments.isNotEmpty
            ? currentState.comments
            : null,
      );

      final result = await emailService.sendNutritionPlanEmail(
        formData: formData,
        pdfBytes: pdfBytes,
      );

      if (result.success) {
        // Save sender name to database if provided
        if (currentState.senderName.isNotEmpty) {
          final user = await database.userDao.getCurrentUserProfile();
          if (user != null) {
            await (database.update(
              database.userProfilesTable,
            )..where((u) => u.id.equals(user.id))).write(
              UserProfilesTableCompanion(
                senderName: Value(currentState.senderName),
                updatedAt: Value(DateTime.now()),
              ),
            );
          }
        }

        await analytics.track(
          'plan_shared',
          properties: {
            'plan_id': nutritionPlan.id,
            'has_sender_name': currentState.senderName.isNotEmpty,
            'has_comments': currentState.comments.isNotEmpty,
          },
        );
      } else {
        await analytics.track(
          'plan_share_failed',
          properties: {
            'plan_id': nutritionPlan.id,
            'error_message': result.error ?? 'Unknown error',
          },
        );
      }

      if (ref.mounted) {
        state = AsyncValue.data(
          currentState.copyWith(isSending: false, lastResult: result),
        );
      }

      return result;
    } catch (e, stackTrace) {
      report.fault(
        e,
        stackTrace: stackTrace,
        area: 'sharing',
        message: 'Plan share failed before the email was sent',
        extra: {'planId': nutritionPlan.id},
      );
      await analytics.track(
        'plan_share_failed',
        properties: {
          'plan_id': nutritionPlan.id,
          'error_message': e.toString(),
        },
      );

      final errorResult = ShareResult.failure(error: e.toString());
      if (ref.mounted) {
        state = AsyncValue.data(
          currentState.copyWith(isSending: false, lastResult: errorResult),
        );
      }
      return errorResult;
    }
  }

  bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }
}
