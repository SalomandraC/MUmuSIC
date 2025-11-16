import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(5050),
  SESSION_SECRET: z.string().min(8).default('dev-session-secret'),
  DATABASE_URL: z.string().url({ message: 'DATABASE_URL must be a valid URL' }),
  SUPABASE_URL: z.string().url({ message: 'SUPABASE_URL must be a valid URL' }).optional(),
  SUPABASE_ANON_KEY: z.string().optional(),
  SUPABASE_SERVICE_ROLE_KEY: z.string().optional(),
  JWT_ACCESS_SECRET: z.string().min(16).default('change-me-access-secret'),
  JWT_REFRESH_SECRET: z.string().min(16).default('change-me-refresh-secret'),
  PASSWORD_RESET_SECRET: z.string().min(16).default('change-me-reset-secret'),
  ACCESS_TOKEN_TTL: z.union([z.string(), z.number()]).default('15m'),
  REFRESH_TOKEN_TTL: z.union([z.string(), z.number()]).default('7d'),
  PASSWORD_RESET_TOKEN_TTL: z.union([z.string(), z.number()]).default('1h'),
  GUEST_SESSION_TTL_MINUTES: z.coerce.number().default(60 * 24),
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
  passwordReset: {
    secret: env.PASSWORD_RESET_SECRET,
    ttl: env.PASSWORD_RESET_TOKEN_TTL,
  },
  guestSessions: {
    ttlMinutes: env.GUEST_SESSION_TTL_MINUTES,
  },
} as const;

export type AppConfig = typeof appConfig;

