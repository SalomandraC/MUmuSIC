import dotenv from 'dotenv';
import path from 'path';
import { z } from 'zod';

dotenv.config();

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(5050),
  SESSION_SECRET: z.string().min(8).default('dev-session-secret'),
  DATABASE_URL: z.string().url({ message: 'DATABASE_URL must be a valid URL' }).optional(),
  SUPABASE_URL: z.string().url({ message: 'SUPABASE_URL must be a valid URL' }).optional(),
  SUPABASE_ANON_KEY: z.string().optional(),
  SUPABASE_SERVICE_ROLE_KEY: z.string().optional(),
  JWT_ACCESS_SECRET: z.string().min(16).default('change-me-access-secret'),
  JWT_REFRESH_SECRET: z.string().min(16).default('change-me-refresh-secret'),
  ACCESS_TOKEN_TTL: z.union([z.string(), z.number()]).default('60m'),
  REFRESH_TOKEN_TTL: z.union([z.string(), z.number()]).default('7d'),
  STORAGE_ROOT: z.string().optional(),
});

const parsedEnv = envSchema.safeParse(process.env);

if (!parsedEnv.success) {
  console.error('Invalid environment configuration:', parsedEnv.error.flatten().fieldErrors);
  throw new Error('Environment validation failed. Check your .env file.');
}

const env = parsedEnv.data;

export const appConfig = {
  nodeEnv: env.NODE_ENV,
  isProduction: env.NODE_ENV === 'production',
  port: env.PORT,
  sessionSecret: env.SESSION_SECRET,
  databaseUrl: env.DATABASE_URL,
  supabase: {
    url: env.SUPABASE_URL,
    anonKey: env.SUPABASE_ANON_KEY,
    serviceRoleKey: env.SUPABASE_SERVICE_ROLE_KEY,
  },
  jwt: {
    accessSecret: env.JWT_ACCESS_SECRET,
    refreshSecret: env.JWT_REFRESH_SECRET,
    accessTtl: env.ACCESS_TOKEN_TTL,
    refreshTtl: env.REFRESH_TOKEN_TTL,
  },
  storageRoot: env.STORAGE_ROOT
    ? path.resolve(env.STORAGE_ROOT)
    : path.resolve(process.cwd(), '..', 'server', 'storage'),
} as const;

export type AppConfig = typeof appConfig;

