"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.appConfig = void 0;
const dotenv_1 = __importDefault(require("dotenv"));
const path_1 = __importDefault(require("path"));
const zod_1 = require("zod");
dotenv_1.default.config();
const envSchema = zod_1.z.object({
    NODE_ENV: zod_1.z.enum(['development', 'test', 'production']).default('development'),
    PORT: zod_1.z.coerce.number().default(5050),
    SESSION_SECRET: zod_1.z.string().min(8).default('dev-session-secret'),
    DATABASE_URL: zod_1.z.string().url({ message: 'DATABASE_URL must be a valid URL' }).optional(),
    SUPABASE_URL: zod_1.z.string().url({ message: 'SUPABASE_URL must be a valid URL' }).optional(),
    SUPABASE_ANON_KEY: zod_1.z.string().optional(),
    SUPABASE_SERVICE_ROLE_KEY: zod_1.z.string().optional(),
    JWT_ACCESS_SECRET: zod_1.z.string().min(16).default('change-me-access-secret'),
    JWT_REFRESH_SECRET: zod_1.z.string().min(16).default('change-me-refresh-secret'),
    ACCESS_TOKEN_TTL: zod_1.z.union([zod_1.z.string(), zod_1.z.number()]).default('60m'),
    REFRESH_TOKEN_TTL: zod_1.z.union([zod_1.z.string(), zod_1.z.number()]).default('7d'),
    STORAGE_ROOT: zod_1.z.string().optional(),
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
    storageRoot: env.STORAGE_ROOT
        ? path_1.default.resolve(env.STORAGE_ROOT)
        : path_1.default.resolve(process.cwd(), '..', 'server', 'storage'),
};
