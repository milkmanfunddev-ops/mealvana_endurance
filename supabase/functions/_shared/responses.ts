/**
 * Standardized response helpers for Edge Functions
 */

import { corsHeaders } from './cors.ts';

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
 * Create an error response
 */
export function errorResponse(
  message: string,
  status = 400,
  details?: string,
  additionalData?: Record<string, unknown>
): Response {
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
 * Create an internal server error response
 */
export function serverError(error: unknown, fallbackToAlgorithm = false): Response {
  console.error('[SERVER_ERROR]', error);
  return jsonResponse(
    {
      success: false,
      error: String(error),
      fallback_to_algorithm: fallbackToAlgorithm,
    },
    500
  );
}
