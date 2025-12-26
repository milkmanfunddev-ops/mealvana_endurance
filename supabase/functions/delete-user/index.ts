import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"
};
/**
 * Delete User Edge Function
 *
 * Completely deletes a user account including:
 * 1. All data from public.users table (CASCADE deletes related data)
 * 2. The auth.users entry (actual Supabase auth account)
 *
 * Requires: Valid JWT token from authenticated user
 * The user can only delete their own account.
 */ serve(async (req)=>{
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders
    });
  }
  try {
    // Get the authorization header
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({
        success: false,
        message: "Missing authorization header"
      }), {
        status: 401,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    // Create a Supabase client with the user's JWT to verify identity
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    // Client with user's JWT to get their user ID
    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: authHeader
        }
      }
    });
    // Get the authenticated user
    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) {
      console.error("Auth error:", userError);
      return new Response(JSON.stringify({
        success: false,
        message: "Invalid or expired authentication token"
      }), {
        status: 401,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    const userId = user.id;
    console.log(`Deleting user account: ${userId}`);
    // Create admin client with service role key for deletion operations
    const adminClient = createClient(supabaseUrl, supabaseServiceKey);
    // Step 1: Delete from public.users table
    // This will CASCADE delete all related data (food_preferences, activities, events, etc.)
    const { error: publicDeleteError } = await adminClient.from("users").delete().eq("id", userId);
    if (publicDeleteError) {
      console.error("Error deleting from public.users:", publicDeleteError);
    // Continue anyway - user might not have a public.users entry
    } else {
      console.log(`Deleted user from public.users: ${userId}`);
    }
    // Step 2: Delete from auth.users using Admin API
    // This completely removes the authentication account
    const { error: authDeleteError } = await adminClient.auth.admin.deleteUser(userId);
    if (authDeleteError) {
      console.error("Error deleting from auth.users:", authDeleteError);
      return new Response(JSON.stringify({
        success: false,
        message: `Failed to delete auth account: ${authDeleteError.message}`
      }), {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    console.log(`Successfully deleted auth account: ${userId}`);
    return new Response(JSON.stringify({
      success: true,
      message: "Account deleted successfully",
      deleted_user_id: userId
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (error) {
    console.error("Unexpected error:", error);
    return new Response(JSON.stringify({
      success: false,
      message: "Internal server error"
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
});
