import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { appConfig } from './appConfig';

let supabaseServiceClient: SupabaseClient | null = null;
let supabasePublicClient: SupabaseClient | null = null;

export const getSupabaseServiceClient = () => {
  if (!appConfig.supabase.url || !appConfig.supabase.serviceRoleKey) {
    throw new Error('Supabase service configuration is missing. Provide SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY.');
  }

  if (!supabaseServiceClient) {
    supabaseServiceClient = createClient(appConfig.supabase.url, appConfig.supabase.serviceRoleKey);
  }

  return supabaseServiceClient;
};

export const getSupabasePublicClient = () => {
  if (!appConfig.supabase.url || !appConfig.supabase.anonKey) {
    throw new Error('Supabase public configuration is missing. Provide SUPABASE_URL and SUPABASE_ANON_KEY.');
  }

  if (!supabasePublicClient) {
    supabasePublicClient = createClient(appConfig.supabase.url, appConfig.supabase.anonKey);
  }

  return supabasePublicClient;
};

