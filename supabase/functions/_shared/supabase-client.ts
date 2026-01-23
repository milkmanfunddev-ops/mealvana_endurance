/**
 * Supabase client factory for Edge Functions
 */

import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

/**
 * Create a Supabase client with service role (admin) privileges
 * Use this for server-side operations that need full access
 */
export function createServiceClient(): SupabaseClient {
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
}

/**
 * Create a Supabase client with anon key
 * Use this for operations that should respect RLS
 */
export function createAnonClient(): SupabaseClient {
  return createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
}

/**
 * Get environment variables with validation
 */
export function getEnvVar(name: string, required = true): string {
  const value = Deno.env.get(name);
  if (required && !value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value ?? '';
}
