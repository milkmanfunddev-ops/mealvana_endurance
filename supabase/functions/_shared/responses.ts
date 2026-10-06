/**
 * Standardized response helpers for Edge Functions.
 *
 * Error answers also report (ticket 12, .scratch/sentry/spec.md §"Edge
 * functions"): `serverError()` captures the error it is given;
 * `errorResponse()` captures when handed an error object or a 5xx status and
 * leaves a breadcrumb for a 4xx without one.
 */

import { corsHeaders } from './cors.ts';
import { captureEdgeError, captureEdgeMessage, edgeBreadcrumb } from './sentry.ts';

/**
 * Create a JSON response with CORS headers
 */
export function jsonResponse<T>(data: T, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

/**
 * Create a success response
 */
export function successResponse<T extends Record<string, unknown>>(data: T): Response {
  return jsonResponse({ success: true, ...data });
}

/**
 * Create an error response.
 *
 * `cause` is the underlying error, when there is one. With a cause, or with a
 * 5xx status, the answer is reported to Sentry; a 4xx with no cause is an
 * expected rejection and only leaves a breadcrumb.
 */
export function errorResponse(
  message: string,
  status = 400,
  details?: string,
  additionalData?: Record<string, unknown>,
  cause?: unknown
): Response {
  if (cause !== undefined && cause !== null) {
    captureEdgeError(cause, { message, extra: { status, details } });
  } else if (status >= 500) {
    captureEdgeMessage(message, { extra: { status, details } });
  } else {
    edgeBreadcrumb(message, { status, details });
  }
  return jsonResponse(
    {
      success: false,
      error: message,
      details,
      ...additionalData,
    },
    status
  );
}

/**
 * Create a validation error response
 */
export function validationError(message: string, fields?: string[]): Response {
  return errorResponse(message, 400, fields?.join(', '));
}

/**
 * Create a not found response
 */
export function notFoundResponse(resource: string): Response {
  return errorResponse(`${resource} not found`, 404);
}

/**
 * Create an internal server error response. Captures `error`.
 *
 * `publicMessage` replaces `String(error)` in the body when the caller does
 * not want the raw error text leaving the function.
 */
export function serverError(
  error: unknown,
  fallbackToAlgorithm = false,
  publicMessage?: string
): Response {
  console.error('[SERVER_ERROR]', error);
  captureEdgeError(error, { extra: { fallback_to_algorithm: fallbackToAlgorithm } });
  return jsonResponse(
    {
      success: false,
      error: publicMessage ?? String(error),
      fallback_to_algorithm: fallbackToAlgorithm,
    },
    500
  );
}
