"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.appConfig = void 0;
const dotenv_1 = __importDefault(require("dotenv"));
const zod_1 = require("zod");
dotenv_1.default.config();
const envSchema = zod_1.z.object({
    NODE_ENV: zod_1.z.enum(['development', 'test', 'production']).default('development'),
    PORT: zod_1.z.coerce.number().default(5000),
    SESSION_SECRET: zod_1.z.string().min(8).default('dev-session-secret'),
    DATABASE_URL: zod_1.z.string().url({ message: 'DATABASE_URL must be a valid URL' }),
    SUPABASE_URL: zod_1.z.string().url({ message: 'SUPABASE_URL must be a valid URL' }).optional(),
    SUPABASE_ANON_KEY: zod_1.z.string().optional(),
    SUPABASE_SERVICE_ROLE_KEY: zod_1.z.string().optional(),
    JWT_ACCESS_SECRET: zod_1.z.string().min(16).default('change-me-access-secret'),
    JWT_REFRESH_SECRET: zod_1.z.string().min(16).default('change-me-refresh-secret'),
    PASSWORD_RESET_SECRET: zod_1.z.string().min(16).default('change-me-reset-secret'),
    ACCESS_TOKEN_TTL: zod_1.z.union([zod_1.z.string(), zod_1.z.number()]).default('15m'),
    REFRESH_TOKEN_TTL: zod_1.z.union([zod_1.z.string(), zod_1.z.number()]).default('7d'),
    PASSWORD_RESET_TOKEN_TTL: zod_1.z.union([zod_1.z.string(), zod_1.z.number()]).default('1h'),
    GUEST_SESSION_TTL_MINUTES: zod_1.z.coerce.number().default(60 * 24), // 24 hours
});
const parsedEnv = envSchema.safeParse(process.env);
if (!parsedEnv.success) {
    console.error('Invalid environment configuration:', parsedEnv.error.flatten().fieldErrors);
    throw new Error('Environment validation failed. Check your .env file.');
}
const env = parsedEnv.data;
exports.appConfig = {
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
};
