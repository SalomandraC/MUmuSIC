import dotenv from 'dotenv';
import path from 'path';
import { z } from 'zod';

dotenv.config();

// Значения-заглушки из старых версий конфига: с ними токены можно подделать,
// поэтому сервер отказывается стартовать, даже если они прописаны в .env
const KNOWN_WEAK_SECRETS = new Set([
  'change-me-access-secret',
  'change-me-refresh-secret',
  'dev-session-secret',
]);

const jwtSecret = (name: string) =>
  z
    .string({ message: `${name} обязателен: задайте его в .env` })
    .min(32, { message: `${name} должен быть не короче 32 символов` })
    .refine((value) => !KNOWN_WEAK_SECRETS.has(value), {
      message: `${name} совпадает с известным значением по умолчанию`,
    });

const envSchema = z
  .object({
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    PORT: z.coerce.number().default(5050),
    LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).optional(),
    SESSION_SECRET: z.string().min(8).default('dev-session-secret'),
    DATABASE_URL: z.string().url({ message: 'DATABASE_URL must be a valid URL' }).optional(),
    // require — SSL с самоподписанным сертификатом (Supabase), disable — без SSL (Postgres в Docker).
    // По умолчанию: require в production, disable в остальных режимах
    DATABASE_SSL: z.enum(['require', 'disable']).optional(),
    DATABASE_POOL_MAX: z.coerce.number().int().positive().default(10),
    SUPABASE_URL: z.string().url({ message: 'SUPABASE_URL must be a valid URL' }).optional(),
    SUPABASE_ANON_KEY: z.string().optional(),
    SUPABASE_SERVICE_ROLE_KEY: z.string().optional(),
    JWT_ACCESS_SECRET: jwtSecret('JWT_ACCESS_SECRET'),
    JWT_REFRESH_SECRET: jwtSecret('JWT_REFRESH_SECRET'),
    ACCESS_TOKEN_TTL: z.union([z.string(), z.number()]).default('60m'),
    REFRESH_TOKEN_TTL: z.union([z.string(), z.number()]).default('7d'),
    // Срок жизни подписанных ссылок на личные файлы (/storage/users/...?token=...)
    MEDIA_TOKEN_TTL: z.union([z.string(), z.number()]).default('7d'),
    STORAGE_ROOT: z.string().optional(),
    // Дополнительные разрешённые CORS-источники через запятую
    CORS_ORIGINS: z.string().optional(),
  })
  .refine((env) => env.JWT_ACCESS_SECRET !== env.JWT_REFRESH_SECRET, {
    message: 'JWT_ACCESS_SECRET и JWT_REFRESH_SECRET должны различаться',
    path: ['JWT_REFRESH_SECRET'],
  });

const parsedEnv = envSchema.safeParse(process.env);

if (!parsedEnv.success) {
  console.error('Invalid environment configuration:', z.flattenError(parsedEnv.error).fieldErrors);
  throw new Error('Environment validation failed. Check your .env file.');
}

const env = parsedEnv.data;
const isProduction = env.NODE_ENV === 'production';

export const appConfig = {
  nodeEnv: env.NODE_ENV,
  isProduction,
  port: env.PORT,
  logLevel: env.LOG_LEVEL ?? (env.NODE_ENV === 'test' ? 'silent' : 'info'),
  sessionSecret: env.SESSION_SECRET,
  databaseUrl: env.DATABASE_URL,
  databaseSsl: (env.DATABASE_SSL ?? (isProduction ? 'require' : 'disable')) === 'require',
  databasePoolMax: env.DATABASE_POOL_MAX,
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
    mediaTtl: env.MEDIA_TOKEN_TTL,
  },
  corsOrigins: (env.CORS_ORIGINS ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean),
  storageRoot: env.STORAGE_ROOT
    ? path.resolve(env.STORAGE_ROOT)
    : path.resolve(process.cwd(), '..', 'server', 'storage'),
} as const;

export type AppConfig = typeof appConfig;
