/**
 * The one redaction rule for provider and database errors that reach a log,
 * Sentry, or an error answer.
 *
 * Ruling (Lee, 2026-10-09, testing-wave develop-2026-10 tickets 76 and 84):
 * log only the HTTP status and the error code, never the description or the
 * body. The app side (ticket 84) mirrors this rule.
 *
 * Why:
 *  - Finding 69-012: Garmin's token endpoint answered a dead refresh with
 *    `{"error":"invalid_grant","error_description":"Invalid refresh token: eyJ…"}`,
 *    and the base64 in the description decodes to JSON holding the refresh
 *    token value and the Garmin guid. garmin-backfill printed that body into
 *    the function logs. Any free-text field of a provider answer can carry a
 *    token, so none is kept.
 *  - A PostgREST error's `details` can read "Failing row contains (…)" for a
 *    constraint violation, which is the whole row, tokens included; `hint`
 *    is free text too. Only `code` and `message` are kept.
 */

/** What a provider's refusal may say in a log: its status and error code. */
export interface ProviderErrorSummary {
  status: number;
  error_code: string | null;
}

/** What a database (or thrown) error may say in a log. */
export interface DbErrorSummary {
  code: string | null;
  message: string | null;
}

/** An error code is a short token-shaped word; anything else may be free text. */
const ERROR_CODE_PATTERN = /^[A-Za-z0-9_.-]{1,64}$/;

/** Fields read for a code, in order. Free-text fields are never read. */
const ERROR_CODE_FIELDS = ['error', 'errorCode', 'code'] as const;

/**
 * Reduces a provider's error answer to `{status, error_code}`.
 *
 * `error_code` is the first of `error`, `errorCode` or `code` whose value is a
 * string matching `^[A-Za-z0-9_.-]{1,64}$`; otherwise `null` (a non-JSON
 * body, a code with spaces, or a body with only `error_description`,
 * `message` or `errorMessage`). Never returns any other part of the body.
 */
export function providerErrorSummary(
  status: number,
  body: string,
): ProviderErrorSummary {
  return { status, error_code: errorCodeOf(body) };
}

function errorCodeOf(body: string): string | null {
  let parsed: unknown;
  try {
    parsed = JSON.parse(body);
  } catch (_) {
    // Not JSON (an HTML gateway page, plain text): no code to keep.
    return null;
  }
  if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
    return null;
  }
  const record = parsed as Record<string, unknown>;
  for (const field of ERROR_CODE_FIELDS) {
    const value = record[field];
    if (typeof value === 'string' && ERROR_CODE_PATTERN.test(value)) {
      return value;
    }
  }
  return null;
}

/**
 * Reduces a PostgREST error to its `code` and `message`, never `details` or
 * `hint`. A thrown `Error` gives `name: message` (a fetch failure's message
 * is kept, nothing else). Anything else gives nulls.
 */
export function dbErrorSummary(err: unknown): DbErrorSummary {
  if (err instanceof SyntaxError) {
    // A JSON parse error quotes the start of the text it refused, which for
    // a token endpoint is the response body. Keep the name only.
    return { code: null, message: 'SyntaxError (message withheld: may quote the body)' };
  }
  if (err instanceof Error) {
    return { code: null, message: `${err.name}: ${err.message}` };
  }
  if (err !== null && typeof err === 'object') {
    const record = err as Record<string, unknown>;
    return {
      code: typeof record.code === 'string' ? record.code : null,
      message: typeof record.message === 'string' ? record.message : null,
    };
  }
  return { code: null, message: null };
}
