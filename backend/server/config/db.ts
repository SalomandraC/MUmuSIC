import postgres from 'postgres';
import { appConfig } from './appConfig';

if (!appConfig.databaseUrl) {
  throw new Error('DATABASE_URL is required but not set in environment variables');
}

const sql = postgres(appConfig.databaseUrl!, {
  ssl: appConfig.isProduction ? { rejectUnauthorized: false } : undefined,
  max: 10,
  connect_timeout: 30,
});

export default sql;