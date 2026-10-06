import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/report/report.dart';
import '../../../shared/services/supabase/supabase_client_provider.dart';

part 'report_pipeline_probe.g.dart';

/// Fires one report of each class so a device run can prove the pipeline
/// end to end: `Report` to Sentry, the Mixpanel fan-out, and the edge
/// wrapper. Driven from the debug screen; every report it sends lands in the
/// `debug` area with a `probe` tag so the events are easy to find and never
/// mistaken for a real failure.
class ReportPipelineProbe {
  ReportPipelineProbe({
    required Report report,
    required Future<void> Function() invokeEdgeWithBadPayload,
  }) : _report = report,
       _invokeEdge = invokeEdgeWithBadPayload;

  final Report _report;
  final Future<void> Function() _invokeEdge;

  /// The `area` tag on every probe report.
  static const String area = 'debug';

  /// The edge function the bad-payload probe calls. Its handler reads the
  /// body as JSON inside its own try, and answers a parse failure through
  /// `errorResponse(..., 400, ..., cause)`, which captures the cause.
  static const String edgeFunction = 'get-foods';

  /// A Fault that no allow-list entry downgrades: a Sentry `error`.
  Future<void> fault() => _report.fault(
    ReportProbeFault('Debug screen: deliberate Fault'),
    stackTrace: StackTrace.current,
    area: area,
    tags: const {'probe': 'fault'},
  );

  /// A Degraded raised directly: a Sentry `warning`.
  Future<void> degraded() => _report.degraded(
    ReportProbeDegraded('Debug screen: deliberate Degraded'),
    stackTrace: StackTrace.current,
    area: area,
    tags: const {'probe': 'degraded'},
  );

  /// A Note and then a Fault, so the Fault's breadcrumb trail carries the
  /// Note. The `debug` area is not a promoted one, so the Note alone sends
  /// no event.
  Future<void> noteThenFault() async {
    await _report.note(
      'Debug screen: note before the Fault',
      area: area,
      data: const {'probe': 'note'},
    );
    await _report.fault(
      ReportProbeFault('Debug screen: Fault after a Note'),
      stackTrace: StackTrace.current,
      area: area,
      tags: const {'probe': 'note_then_fault'},
    );
  }

  /// Calls [edgeFunction] with a body that is not JSON. The expected answer
  /// is a 4xx refusal, which the edge wrapper has already captured under
  /// `edge-dev`; the app records only a Note so the app project gets no
  /// event of its own.
  Future<EdgeProbeOutcome> edgeBadPayload() async {
    try {
      await _invokeEdge();
    } on FunctionException catch (e) {
      await _report.note(
        'Debug screen: edge probe refused as expected',
        area: area,
        data: {'function': edgeFunction, 'status': e.status},
      );
      return EdgeProbeOutcome.refused(e.status);
    } catch (e, st) {
      await _report.degraded(
        e,
        stackTrace: st,
        area: area,
        tags: const {'probe': 'edge'},
        message: 'Debug screen: edge probe never reached the function',
      );
      return const EdgeProbeOutcome.unreachable();
    }
    return const EdgeProbeOutcome.accepted();
  }
}

/// What the edge probe got back. Only [EdgeProbeKind.refused] is the path
/// that captures an edge event.
enum EdgeProbeKind {
  /// The function refused the payload with a 4xx; one edge event is due.
  refused,

  /// The function answered 2xx, so nothing was captured.
  accepted,

  /// The call never reached the function; a Degraded was reported here.
  unreachable,
}

class EdgeProbeOutcome {
  const EdgeProbeOutcome.refused(int this.status)
    : kind = EdgeProbeKind.refused;
  const EdgeProbeOutcome.accepted()
    : kind = EdgeProbeKind.accepted,
      status = null;
  const EdgeProbeOutcome.unreachable()
    : kind = EdgeProbeKind.unreachable,
      status = null;

  final EdgeProbeKind kind;
  final int? status;
}

class ReportProbeFault implements Exception {
  const ReportProbeFault(this.message);
  final String message;
  @override
  String toString() => message;
}

class ReportProbeDegraded implements Exception {
  const ReportProbeDegraded(this.message);
  final String message;
  @override
  String toString() => message;
}

@riverpod
ReportPipelineProbe reportPipelineProbe(Ref ref) {
  return ReportPipelineProbe(
    report: ref.read(reportProvider),
    invokeEdgeWithBadPayload: () => ref
        .read(supabaseClientProvider)
        .functions
        .invoke(ReportPipelineProbe.edgeFunction, body: 'not json'),
  );
}
