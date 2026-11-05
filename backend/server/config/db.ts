import postgres from 'postgres';
import { appConfig } from './appConfig';

if (!appConfig.databaseUrl) {
  throw new Error('DATABASE_URL is required but not set in environment variables');
}

const sql = postgres(appConfig.databaseUrl!, {
  ssl: appConfig.databaseSsl ? { rejectUnauthorized: false } : undefined,
  max: appConfig.databasePoolMax,
  connect_timeout: 30,
});

export default sql;
