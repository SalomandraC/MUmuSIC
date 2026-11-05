import pino from 'pino';
import { appConfig } from '../config/appConfig';

// JSON-логи в production и в Docker, читаемые цветные — при локальной разработке
export const logger = pino({
  level: appConfig.logLevel,
  redact: {
    paths: ['req.headers.authorization', 'req.headers.cookie', 'req.query.token'],
    censor: '[скрыто]',
  },
  transport:
    appConfig.nodeEnv === 'development'
      ? { target: 'pino-pretty', options: { colorize: true, translateTime: 'HH:MM:ss', ignore: 'pid,hostname' } }
      : undefined,
});
