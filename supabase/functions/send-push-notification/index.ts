import { serve } from 'https://deno.land/std@0.131.0/http/server.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface PushNotificationRequest {
  // Target users - at least one required
  external_user_ids?: string[];  // Device IDs or Supabase user IDs
  onesignal_user_ids?: string[]; // OneSignal player IDs

  // Notification content
  title: string;
  message: string;

  // Optional data payload for deep linking
  data?: Record<string, string>;

  // Optional: Target specific segments (OneSignal segments)
  segments?: string[];
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const ONESIGNAL_APP_ID = Deno.env.get('ONESIGNAL_APP_ID');
    const ONESIGNAL_REST_API_KEY = Deno.env.get('ONESIGNAL_REST_API_KEY');

    if (!ONESIGNAL_APP_ID || !ONESIGNAL_REST_API_KEY) {
      console.error('OneSignal credentials not configured');
      return new Response(
        JSON.stringify({ error: 'OneSignal not configured' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    const body: PushNotificationRequest = await req.json();
    const { external_user_ids, onesignal_user_ids, title, message, data, segments } = body;

    // Validate required fields
    if (!title || !message) {
      return new Response(
        JSON.stringify({ error: 'title and message are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Build OneSignal API request
    // https://documentation.onesignal.com/reference/create-notification
    const notificationPayload: Record<string, unknown> = {
      app_id: ONESIGNAL_APP_ID,
      headings: { en: title },
      contents: { en: message },
    };

    // Add data payload if provided
    if (data) {
      notificationPayload.data = data;
    }

    // Target by external user IDs (device IDs)
    if (external_user_ids && external_user_ids.length > 0) {
      notificationPayload.include_aliases = {
        external_id: external_user_ids,
      };
      notificationPayload.target_channel = 'push';
    }
    // Target by OneSignal player IDs
    else if (onesignal_user_ids && onesignal_user_ids.length > 0) {
      notificationPayload.include_subscription_ids = onesignal_user_ids;
    }
    // Target by segments
    else if (segments && segments.length > 0) {
      notificationPayload.included_segments = segments;
    }
    // No target specified - send to all subscribed users
    else {
      notificationPayload.included_segments = ['Subscribed Users'];
    }

    console.log('Sending push notification:', JSON.stringify(notificationPayload, null, 2));

    // Send to OneSignal API
    const response = await fetch('https://onesignal.com/api/v1/notifications', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Basic ${ONESIGNAL_REST_API_KEY}`,
      },
      body: JSON.stringify(notificationPayload),
    });

    const result = await response.json();

    if (!response.ok) {
      console.error('OneSignal API error:', result);
      return new Response(
        JSON.stringify({ error: 'Failed to send notification', details: result }),
        {
          status: response.status,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    console.log('Push notification sent successfully:', result);

    return new Response(
      JSON.stringify({
        success: true,
        notification_id: result.id,
        recipients: result.recipients,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Error sending push notification:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
