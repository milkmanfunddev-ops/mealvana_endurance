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
    // Get sender name from database
    final user = await _database.getCurrentUserProfile();
    final userEntry = user != null
        ? await (_database.select(_database.userProfilesTable)
            ..where((u) => u.id.equals(user.id))
          ).getSingleOrNull()
        : null;
    final senderName = userEntry?.senderName ?? '';

    final activityDate = nutritionPlan.runDateTime != null
        ? DateFormat('MMMM d, yyyy').format(nutritionPlan.runDateTime!)
        : 'TBD';

    final defaultSubjectTemplate = _contentService.getValue(
      'sharing.subject_default',
      defaultValue: 'Nutrition Plan on {date}',
    );
    final defaultSubject = defaultSubjectTemplate
        .replaceAll('{date}', activityDate);

    final defaultComments = _contentService.getValue(
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

    try {
      final pdfBytes = await _pdfService.generateNutritionPlanPdf(
        nutritionPlan: nutritionPlan,
        sentDate: DateTime.now(),
        senderName: currentState.senderName.isNotEmpty ? currentState.senderName : null,
      );

      final formData = ShareFormData(
        recipientEmail: currentState.recipientEmail,
        senderName: currentState.senderName.isNotEmpty ? currentState.senderName : null,
        subject: currentState.subject.isNotEmpty ? currentState.subject : null,
        comments: currentState.comments.isNotEmpty ? currentState.comments : null,
      );

      final result = await _emailService.sendNutritionPlanEmail(
        formData: formData,
        pdfBytes: pdfBytes,
      );

      if (result.success) {
        // Save sender name to database if provided
        if (currentState.senderName.isNotEmpty) {
          final user = await _database.getCurrentUserProfile();
          if (user != null) {
            await (_database.update(_database.userProfilesTable)
              ..where((u) => u.id.equals(user.id))
            ).write(
              UserProfilesTableCompanion(
                senderName: Value(currentState.senderName),
                updatedAt: Value(DateTime.now()),
              ),
            );
          }
        }

        await _analytics.track('plan_shared', properties: {
          'plan_id': nutritionPlan.id,
          'has_sender_name': currentState.senderName.isNotEmpty,
          'has_comments': currentState.comments.isNotEmpty,
        });
      } else {
        await _analytics.track('plan_share_failed', properties: {
          'plan_id': nutritionPlan.id,
          'error_message': result.error ?? 'Unknown error',
        });
      }

      state = AsyncValue.data(currentState.copyWith(
        isSending: false,
        lastResult: result,
      ));

      return result;
    } catch (e) {
      await _analytics.track('plan_share_failed', properties: {
        'plan_id': nutritionPlan.id,
        'error_message': e.toString(),
      });

      final errorResult = ShareResult.failure(error: e.toString());
      state = AsyncValue.data(currentState.copyWith(
        isSending: false,
        lastResult: errorResult,
      ));
      return errorResult;
    }
  }

  bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }
}
