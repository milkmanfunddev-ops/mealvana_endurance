import 'dart:convert';
import 'dart:typed_data';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/share_form_data.dart';
import '../domain/share_result.dart';
import '../../../shared/services/report/report.dart';

part 'email_service.g.dart';

@riverpod
EmailService emailService(Ref ref) {
  return EmailService(
    Supabase.instance.client,
    report: ref.watch(reportProvider),
  );
}

class EmailService {
  EmailService(this._supabase, {Report? report}) : _reportOverride = report;

  final SupabaseClient _supabase;
  final Report? _reportOverride;

  Report get _report => _reportOverride ?? SentryReport.global;

  Future<ShareResult> sendNutritionPlanEmail({
    required ShareFormData formData,
    required Uint8List pdfBytes,
  }) async {
    try {
      final pdfBase64 = base64Encode(pdfBytes);

      final requestBody = {
        'recipientEmail': formData.recipientEmail,
        if (formData.senderName != null) 'senderName': formData.senderName,
        if (formData.subject != null) 'subject': formData.subject,
        if (formData.comments != null) 'comments': formData.comments,
        'pdfAttachment': pdfBase64,
      };

      final response = await _supabase.functions.invoke(
        'send-nutrition-plan-email',
        body: requestBody,
      );

      if (response.status >= 200 && response.status < 300) {
        final data = response.data as Map<String, dynamic>;

        if (data['success'] == true) {
          return ShareResult.success(
            message: data['message'] as String? ?? 'Email sent successfully',
          );
        } else {
          return ShareResult.failure(
            error: data['error'] as String? ?? 'Failed to send email',
          );
        }
      } else {
        return ShareResult.failure(error: 'Server error: ${response.status}');
      }
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'sharing',
        message: 'Nutrition plan email send failed',
      );
      return ShareResult.failure(error: 'Failed to send email: $e');
    }
  }
}
