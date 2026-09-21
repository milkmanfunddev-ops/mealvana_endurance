/**
 * Tests for the send-nutrition-plan-email Edge Function.
 *
 * These run against the REAL handler (`handler.ts`), with the caller check and
 * the Resend fetch injected. Nothing reaches the network.
 *
 * Covers the caller check (ai-cost ticket 01, mp-466), template rendering,
 * Resend API call assembly, validation of required fields, error handling and
 * edge cases.
 *
 * Run with:
 *   deno test --allow-env --allow-net --allow-read --allow-sys \
 *     supabase/functions/send-nutrition-plan-email/index.test.ts
 */

import {
  assertEquals,
  assertExists,
  assert,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';
import { handleSendEmail } from './handler.ts';

// ---------------------------------------------------------------------------
// Constants (mirrored from production)
// ---------------------------------------------------------------------------

const FROM_EMAIL = 'support@mealvana.io';
const DEFAULT_SUBJECT = 'Your Nutrition Plan from Mealvana Endurance';
const RESEND_API_URL = 'https://api.resend.com/emails';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface EmailPayload {
  recipientEmail?: string;
  senderName?: string;
  subject?: string;
  comments?: string;
  pdfAttachment?: string;
}

interface ResendRequestCapture {
  url: string;
  method: string;
  headers: Record<string, string>;
  body: {
    from: string;
    to: string;
    subject: string;
    html: string;
    attachments: Array<{ filename: string; content: string }>;
  };
}

// ---------------------------------------------------------------------------
// Harness — builds a POST request and calls the real handler
// ---------------------------------------------------------------------------

type FetchStub = (url: string | URL, init?: RequestInit) => Promise<Response>;

/** A caller check that always passes, standing in for a valid Supabase JWT. */
const signedIn = () => Promise.resolve({ ok: true as const });
/** A caller check that always fails, standing in for a missing/invalid token. */
const signedOut = () =>
  Promise.resolve({ ok: false as const, status: 401, error: 'unauthenticated' });

function emailRequest(payload: EmailPayload): Request {
  return new Request('https://example.com/send-nutrition-plan-email', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
}

function handleSignedIn(
  payload: EmailPayload,
  fakeFetch: FetchStub,
  apiKey = 'test-resend-api-key',
): Promise<Response> {
  return handleSendEmail(emailRequest(payload), {
    authenticate: signedIn,
    fetchFn: fakeFetch as typeof fetch,
    apiKey,
  });
}

// ---------------------------------------------------------------------------
// Fake fetch helpers
// ---------------------------------------------------------------------------

/** Captures the outgoing Resend request for assertion */
function capturingFetch(
  resendResponse: { id?: string; message?: string } = { id: 'email-id-123' },
  status = 200,
): { fakeFetch: FetchStub; captured: () => ResendRequestCapture | null } {
  let capture: ResendRequestCapture | null = null;

  const fakeFetch: FetchStub = (url, init) => {
    const body = init?.body ? JSON.parse(init.body as string) : {};
    const headers = (init?.headers as Record<string, string>) ?? {};
    capture = {
      url: url.toString(),
      method: init?.method ?? 'GET',
      headers,
      body,
    };
    return Promise.resolve(
      new Response(JSON.stringify(resendResponse), {
        status,
        headers: { 'Content-Type': 'application/json' },
      }),
    );
  };

  return { fakeFetch, captured: () => capture };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('send-nutrition-plan-email — caller check (ticket 01 / mp-466)', () => {
  const validPayload: EmailPayload = {
    recipientEmail: 'athlete@ironman.com',
    pdfAttachment: 'JVBERi0xLjQ...',
  };

  it('returns 401 when the caller is not signed in', async () => {
    const { fakeFetch } = capturingFetch();
    const res = await handleSendEmail(emailRequest(validPayload), {
      authenticate: signedOut,
      fetchFn: fakeFetch as typeof fetch,
      apiKey: 'k',
    });
    assertEquals(res.status, 401);
    const body = await res.json();
    assertEquals(body.success, false);
    assertEquals(body.error, 'unauthenticated');
  });

  it('sends NOTHING when the caller is not signed in', async () => {
    const { fakeFetch, captured } = capturingFetch();
    await handleSendEmail(emailRequest(validPayload), {
      authenticate: signedOut,
      fetchFn: fakeFetch as typeof fetch,
      apiKey: 'k',
    });
    assertEquals(captured(), null, 'Resend must not be called for an unsigned caller');
  });

  it('a signed-in caller still sends', async () => {
    const { fakeFetch, captured } = capturingFetch({ id: 'sent-1' });
    const res = await handleSignedIn(validPayload, fakeFetch);
    assertEquals(res.status, 200);
    assertEquals((await res.json()).success, true);
    assertEquals(captured()?.url, RESEND_API_URL);
  });

  it('CORS preflight is answered without a token', async () => {
    const res = await handleSendEmail(
      new Request('https://example.com/send-nutrition-plan-email', { method: 'OPTIONS' }),
      { authenticate: signedOut },
    );
    assertEquals(res.status, 200);
    assertEquals(res.headers.get('Access-Control-Allow-Origin'), '*');
  });
});

describe('send-nutrition-plan-email — input validation', () => {
  it('returns 400 when recipientEmail is missing', async () => {
    const { fakeFetch } = capturingFetch();
    const res = await handleSignedIn({ pdfAttachment: 'base64data' }, fakeFetch);
    assertEquals(res.status, 400);
    const body = await res.json();
    assertEquals(body.success, false);
    assert(body.error.includes('Recipient email'));
  });

  it('returns 400 when pdfAttachment is missing', async () => {
    const { fakeFetch } = capturingFetch();
    const res = await handleSignedIn({ recipientEmail: 'athlete@example.com' }, fakeFetch);
    assertEquals(res.status, 400);
    const body = await res.json();
    assertEquals(body.success, false);
    assert(body.error.includes('PDF attachment'));
  });

  it('returns 400 when both recipientEmail and pdfAttachment are missing', async () => {
    const { fakeFetch } = capturingFetch();
    const res = await handleSignedIn({}, fakeFetch);
    assertEquals(res.status, 400);
    // recipientEmail is checked first
    assert((await res.json()).error.includes('Recipient email'));
  });

  it('does NOT call Resend API when validation fails', async () => {
    const { fakeFetch, captured } = capturingFetch();
    await handleSignedIn({ pdfAttachment: 'data' /* no recipientEmail */ }, fakeFetch);
    assertEquals(captured(), null, 'Resend API should not be called when validation fails');
  });
});

describe('send-nutrition-plan-email — Resend API call assembly', () => {
  const validPayload: EmailPayload = {
    recipientEmail: 'athlete@ironman.com',
    pdfAttachment: 'JVBERi0xLjQ...', // fake base64
    senderName: 'Coach Lee',
    subject: 'Your Race Day Fuel Plan',
    comments: 'Great job on your long run!',
  };

  it('sends to correct Resend endpoint', async () => {
    const { fakeFetch, captured } = capturingFetch();
    await handleSignedIn(validPayload, fakeFetch);
    assertEquals(captured()?.url, RESEND_API_URL);
  });

  it('uses POST method', async () => {
    const { fakeFetch, captured } = capturingFetch();
    await handleSignedIn(validPayload, fakeFetch);
    assertEquals(captured()?.method, 'POST');
  });

  it('sends from support@mealvana.io', async () => {
    const { fakeFetch, captured } = capturingFetch();
    await handleSignedIn(validPayload, fakeFetch);
    assertEquals(captured()?.body.from, FROM_EMAIL);
  });

  it('sends to the provided recipientEmail', async () => {
    const { fakeFetch, captured } = capturingFetch();
    await handleSignedIn(validPayload, fakeFetch);
    assertEquals(captured()?.body.to, 'athlete@ironman.com');
  });

  it('uses the provided subject when supplied', async () => {
    const { fakeFetch, captured } = capturingFetch();
    await handleSignedIn(validPayload, fakeFetch);
    assertEquals(captured()?.body.subject, 'Your Race Day Fuel Plan');
  });

  it('uses the default subject when subject is omitted', async () => {
    const { fakeFetch, captured } = capturingFetch();
    await handleSignedIn({ recipientEmail: 'a@b.com', pdfAttachment: 'data' }, fakeFetch);
    assertEquals(captured()?.body.subject, DEFAULT_SUBJECT);
  });

  it('attaches PDF with filename nutrition-plan.pdf', async () => {
    const { fakeFetch, captured } = capturingFetch();
    await handleSignedIn(validPayload, fakeFetch);
    const attachments = captured()?.body.attachments;
    assertExists(attachments);
    assertEquals(attachments!.length, 1);
    assertEquals(attachments![0].filename, 'nutrition-plan.pdf');
    assertEquals(attachments![0].content, 'JVBERi0xLjQ...');
  });

  it('includes Bearer token in Authorization header', async () => {
    const { fakeFetch, captured } = capturingFetch();
    await handleSignedIn(validPayload, fakeFetch, 'my-test-api-key');
    assertEquals(captured()?.headers['Authorization'], 'Bearer my-test-api-key');
  });
});

describe('send-nutrition-plan-email — HTML template rendering', () => {
  it('renders senderName when provided', async () => {
    const { fakeFetch, captured } = capturingFetch();
    await handleSignedIn(
      { recipientEmail: 'a@b.com', pdfAttachment: 'data', senderName: 'Lee Martin' },
      fakeFetch,
    );
    const html = captured()?.body.html ?? '';
    assert(html.includes('Lee Martin'), 'HTML should contain sender name');
    assert(html.includes('From:'), 'HTML should contain From: label');
  });

  it('does NOT render senderName section when omitted', async () => {
    const { fakeFetch, captured } = capturingFetch();
    await handleSignedIn(
      { recipientEmail: 'a@b.com', pdfAttachment: 'data' /* no senderName */ },
      fakeFetch,
    );
    const html = captured()?.body.html ?? '';
    assert(
      !html.includes('<strong>From:</strong>'),
      'From section should be absent when senderName not provided',
    );
  });

  it('renders comments section when provided', async () => {
    const { fakeFetch, captured } = capturingFetch();
    await handleSignedIn(
      {
        recipientEmail: 'a@b.com',
        pdfAttachment: 'data',
        comments: 'Stay hydrated during the run!',
      },
      fakeFetch,
    );
    const html = captured()?.body.html ?? '';
    assert(html.includes('Stay hydrated during the run!'));
    assert(html.includes('Message:'));
  });

  it('does NOT render comments section when omitted', async () => {
    const { fakeFetch, captured } = capturingFetch();
    await handleSignedIn(
      { recipientEmail: 'a@b.com', pdfAttachment: 'data' /* no comments */ },
      fakeFetch,
    );
    const html = captured()?.body.html ?? '';
    assert(
      !html.includes('<strong>Message:</strong>'),
      'Message section should be absent when comments not provided',
    );
  });

  it('HTML always contains the Mealvana branding header', async () => {
    const { fakeFetch, captured } = capturingFetch();
    await handleSignedIn({ recipientEmail: 'a@b.com', pdfAttachment: 'data' }, fakeFetch);
    const html = captured()?.body.html ?? '';
    assert(html.includes('Nutrition Plan from Mealvana Endurance'));
    assert(html.includes('mealvana.io'));
    assert(html.includes('#381633'), 'Brand colour should be in HTML');
  });

  it('HTML contains the PDF description text', async () => {
    const { fakeFetch, captured } = capturingFetch();
    await handleSignedIn({ recipientEmail: 'a@b.com', pdfAttachment: 'data' }, fakeFetch);
    const html = captured()?.body.html ?? '';
    assert(html.includes('personalized nutrition plan attached as a PDF'));
  });
});

describe('send-nutrition-plan-email — success response', () => {
  it('returns 200 with emailId on success', async () => {
    const { fakeFetch } = capturingFetch({ id: 'resend-email-id-abc' });
    const res = await handleSignedIn(
      { recipientEmail: 'a@b.com', pdfAttachment: 'data' },
      fakeFetch,
    );
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.success, true);
    assertEquals(body.emailId, 'resend-email-id-abc');
    assertEquals(body.message, 'Email sent successfully');
  });
});

describe('send-nutrition-plan-email — error handling', () => {
  it('returns Resend error status when Resend API fails', async () => {
    const { fakeFetch } = capturingFetch({ message: 'Invalid API key' }, 401);
    const res = await handleSignedIn(
      { recipientEmail: 'a@b.com', pdfAttachment: 'data' },
      fakeFetch,
    );
    assertEquals(res.status, 401);
    const body = await res.json();
    assertEquals(body.success, false);
    assertEquals(body.error, 'Invalid API key');
  });

  it('returns 422 status code when Resend returns 422 (e.g. bad email format)', async () => {
    const { fakeFetch } = capturingFetch({ message: 'Invalid email address' }, 422);
    const res = await handleSignedIn(
      { recipientEmail: 'not-an-email', pdfAttachment: 'data' },
      fakeFetch,
    );
    assertEquals(res.status, 422);
    const body = await res.json();
    assertEquals(body.success, false);
    // NOTE: The function does NOT validate email format itself — it relies on
    // Resend to reject malformed addresses. This is a seam where a bad address
    // still reaches the API.
  });

  it('returns 500 when fetch throws (network error)', async () => {
    const fakeFetch: FetchStub = () => Promise.reject(new Error('connection refused'));
    const res = await handleSignedIn(
      { recipientEmail: 'a@b.com', pdfAttachment: 'data' },
      fakeFetch,
    );
    assertEquals(res.status, 500);
    const body = await res.json();
    assertEquals(body.success, false);
    assert(body.error.includes('connection refused'));
  });

  it('returns 500 when fetch throws a non-Error object', async () => {
    const fakeFetch: FetchStub = () => Promise.reject('string error');
    const res = await handleSignedIn(
      { recipientEmail: 'a@b.com', pdfAttachment: 'data' },
      fakeFetch,
    );
    assertEquals(res.status, 500);
    const body = await res.json();
    assertEquals(body.success, false);
    assertEquals(body.error, 'Unknown error occurred');
  });

  it('uses fallback error message when Resend response has no message field', async () => {
    // deno-lint-ignore no-explicit-any
    const { fakeFetch } = capturingFetch({} as any, 500); // empty body — no 'message' field
    const res = await handleSignedIn(
      { recipientEmail: 'a@b.com', pdfAttachment: 'data' },
      fakeFetch,
    );
    const body = await res.json();
    assertEquals(body.error, 'Failed to send email');
  });
});

describe('send-nutrition-plan-email — edge cases', () => {
  it('handles empty string recipientEmail as missing (returns 400)', async () => {
    const { fakeFetch } = capturingFetch();
    const res = await handleSignedIn({ recipientEmail: '', pdfAttachment: 'data' }, fakeFetch);
    assertEquals(res.status, 400);
  });

  it('handles empty string pdfAttachment as missing (returns 400)', async () => {
    const { fakeFetch } = capturingFetch();
    const res = await handleSignedIn({ recipientEmail: 'a@b.com', pdfAttachment: '' }, fakeFetch);
    assertEquals(res.status, 400);
  });

  it('sends large PDF attachments without truncation', async () => {
    // Generate a ~50KB fake base64 payload (realistic PDF size)
    const largePdf = 'A'.repeat(50 * 1024);
    const { fakeFetch, captured } = capturingFetch({ id: 'big-email' });

    const res = await handleSignedIn(
      { recipientEmail: 'a@b.com', pdfAttachment: largePdf },
      fakeFetch,
    );

    assertEquals(res.status, 200);
    assertEquals(
      captured()?.body.attachments[0].content.length,
      largePdf.length,
      'Large PDF content must not be truncated',
    );
  });
});
