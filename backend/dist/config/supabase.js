"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getSupabasePublicClient = exports.getSupabaseServiceClient = void 0;
const supabase_js_1 = require("@supabase/supabase-js");
const appConfig_1 = require("./appConfig");
let supabaseServiceClient = null;
let supabasePublicClient = null;
const getSupabaseServiceClient = () => {
    if (!appConfig_1.appConfig.supabase.url || !appConfig_1.appConfig.supabase.serviceRoleKey) {
        throw new Error('Supabase service configuration is missing. Provide SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY.');
    }
    if (!supabaseServiceClient) {
        supabaseServiceClient = (0, supabase_js_1.createClient)(appConfig_1.appConfig.supabase.url, appConfig_1.appConfig.supabase.serviceRoleKey);
    }
    return supabaseServiceClient;
};
exports.getSupabaseServiceClient = getSupabaseServiceClient;
const getSupabasePublicClient = () => {
    if (!appConfig_1.appConfig.supabase.url || !appConfig_1.appConfig.supabase.anonKey) {
        throw new Error('Supabase public configuration is missing. Provide SUPABASE_URL and SUPABASE_ANON_KEY.');
    }
    if (!supabasePublicClient) {
        supabasePublicClient = (0, supabase_js_1.createClient)(appConfig_1.appConfig.supabase.url, appConfig_1.appConfig.supabase.anonKey);
    }
    return supabasePublicClient;
};
exports.getSupabasePublicClient = getSupabasePublicClient;
