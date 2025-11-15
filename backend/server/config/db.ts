import postgres from 'postgres';
import { appConfig } from './appConfig';

const sql = postgres(appConfig.databaseUrl, {
  ssl: appConfig.isProduction ? { rejectUnauthorized: false } : undefined,
  max: 10,
  connect_timeout: 30,
});

export default sql;