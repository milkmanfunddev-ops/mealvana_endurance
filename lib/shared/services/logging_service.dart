import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'report/report.dart';

/// Legacy logging surface. Every method is a thin alias onto [Report]; see
/// [PrettyAppLogger]. New code calls `Report` directly.
abstract class AppLogger {
  void debug(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  });

  void info(String message, {String? context, Map<String, dynamic>? data});

  void warning(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  });

  void error(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  });

  void fatal(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  });

  void api(
    String message, {
    String? endpoint,
    int? statusCode,
    Map<String, dynamic>? requestData,
    Map<String, dynamic>? responseData,
    Duration? duration,
    dynamic error,
  });

  void database(
    String message, {
    String? operation,
    String? table,
    Map<String, dynamic>? data,
    Duration? duration,
    dynamic error,
  });

  void navigation(
    String message, {
    String? from,
    String? to,
    Map<String, dynamic>? parameters,
  });

  void userAction(
    String message, {
    String? action,
    String? screen,
    Map<String, dynamic>? data,
  });

  void nutritionPlan(
    String message, {
    String? planId,
    String? phase,
    Map<String, dynamic>? data,
    dynamic error,
  });

  void analytics(
    String message, {
    String? event,
    Map<String, dynamic>? properties,
  });
}

/// The legacy logger surface, forwarding to [Report] (glossary: CONTEXT.md
/// § Error reporting). `error` and `fatal` are Faults, `warning` is Degraded,
/// `info` and `debug` are structured logs; Report also writes the console and
/// the debug screen's log, which this class used to do itself. The name is
/// kept so the two tests that construct it compile; deleted with the last
/// caller (ticket 10 of `.scratch/sentry/`).
class PrettyAppLogger implements AppLogger {
  PrettyAppLogger({Report? report}) : _report = report;

  final Report? _report;

  Report get _r => _report ?? SentryReport.global;

  @override
  void debug(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _r.debug(
      message,
      area: context,
      data: error == null ? data : {...?data, 'error': error.toString()},
    );
  }

  @override
  void info(String message, {String? context, Map<String, dynamic>? data}) {
    _r.info(message, area: context, data: data);
  }

  @override
  void warning(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _r.degraded(
      error ?? LoggedFault(message, context: context),
      stackTrace: stackTrace,
      area: context,
      extra: data,
      message: error == null ? null : message,
    );
  }

  @override
  void error(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _r.fault(
      error ?? LoggedFault(message, context: context),
      stackTrace: stackTrace,
      area: context,
      extra: data,
      message: error == null ? null : message,
    );
  }

  @override
  void fatal(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _r.fault(
      error ?? LoggedFault(message, context: context),
      stackTrace: stackTrace,
      area: context,
      tags: const {'fatal': 'true'},
      extra: data,
      message: error == null ? null : message,
    );
  }

  @override
  void api(
    String message, {
    String? endpoint,
    int? statusCode,
    Map<String, dynamic>? requestData,
    Map<String, dynamic>? responseData,
    Duration? duration,
    dynamic error,
  }) {
    final data = <String, dynamic>{};
    if (endpoint != null) data['endpoint'] = endpoint;
    if (statusCode != null) data['status_code'] = statusCode;
    if (requestData != null) data['request'] = requestData;
    if (responseData != null) data['response'] = responseData;
    if (duration != null) data['duration_ms'] = duration.inMilliseconds;

    if (error != null) {
      this.error(message, context: 'API', data: data, error: error);
    } else if (statusCode != null && statusCode >= 400) {
      warning(message, context: 'API', data: data);
    } else {
      debug(message, context: 'API', data: data);
    }
  }

  @override
  void database(
    String message, {
    String? operation,
    String? table,
    Map<String, dynamic>? data,
    Duration? duration,
    dynamic error,
  }) {
    final logData = <String, dynamic>{};
    if (operation != null) logData['operation'] = operation;
    if (table != null) logData['table'] = table;
    if (data != null) logData['data'] = data;
    if (duration != null) logData['duration_ms'] = duration.inMilliseconds;

    if (error != null) {
      this.error(message, context: 'DATABASE', data: logData, error: error);
    } else {
      debug(message, context: 'DATABASE', data: logData);
    }
  }

  @override
  void navigation(
    String message, {
    String? from,
    String? to,
    Map<String, dynamic>? parameters,
  }) {
    final data = <String, dynamic>{};
    if (from != null) data['from'] = from;
    if (to != null) data['to'] = to;
    if (parameters != null) data['parameters'] = parameters;

    debug(message, context: 'NAVIGATION', data: data);
  }

  @override
  void userAction(
    String message, {
    String? action,
    String? screen,
    Map<String, dynamic>? data,
  }) {
    final logData = <String, dynamic>{};
    if (action != null) logData['action'] = action;
    if (screen != null) logData['screen'] = screen;
    if (data != null) logData.addAll(data);

    info(message, context: 'USER_ACTION', data: logData);
  }

  @override
  void nutritionPlan(
    String message, {
    String? planId,
    String? phase,
    Map<String, dynamic>? data,
    dynamic error,
  }) {
    final logData = <String, dynamic>{};
    if (planId != null) logData['plan_id'] = planId;
    if (phase != null) logData['phase'] = phase;
    if (data != null) logData.addAll(data);

    if (error != null) {
      this.error(
        message,
        context: 'NUTRITION_PLAN',
        data: logData,
        error: error,
      );
    } else {
      debug(message, context: 'NUTRITION_PLAN', data: logData);
    }
  }

  @override
  void analytics(
    String message, {
    String? event,
    Map<String, dynamic>? properties,
  }) {
    final data = <String, dynamic>{};
    if (event != null) data['event'] = event;
    if (properties != null) data['properties'] = properties;

    debug(message, context: 'ANALYTICS', data: data);
  }
}

/// Logger implementation that swallows all messages.
class NoopAppLogger implements AppLogger {
  const NoopAppLogger();

  @override
  void analytics(
    String message, {
    String? event,
    Map<String, dynamic>? properties,
  }) {}

  @override
  void api(
    String message, {
    String? endpoint,
    int? statusCode,
    Map<String, dynamic>? requestData,
    Map<String, dynamic>? responseData,
    Duration? duration,
    dynamic error,
  }) {}

  @override
  void database(
    String message, {
    String? operation,
    String? table,
    Map<String, dynamic>? data,
    Duration? duration,
    dynamic error,
  }) {}

  @override
  void debug(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) {}

  @override
  void error(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) {}

  @override
  void fatal(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) {}

  @override
  void info(String message, {String? context, Map<String, dynamic>? data}) {}

  @override
  void navigation(
    String message, {
    String? from,
    String? to,
    Map<String, dynamic>? parameters,
  }) {}

  @override
  void nutritionPlan(
    String message, {
    String? planId,
    String? phase,
    Map<String, dynamic>? data,
    dynamic error,
  }) {}

  @override
  void userAction(
    String message, {
    String? action,
    String? screen,
    Map<String, dynamic>? data,
  }) {}

  @override
  void warning(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) {}
}

/// Provider exposing the legacy logger surface, aliased onto [Report].
final Provider<AppLogger> appLoggerProvider = Provider<AppLogger>((ref) {
  return PrettyAppLogger(report: ref.watch(reportProvider));
});
