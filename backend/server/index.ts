import dotenv from 'dotenv';
dotenv.config();
import fs from 'fs';
import { AppState, createApp } from './app';
import { appConfig } from './config/appConfig';
import sql from './config/db';
import { logger } from './utils/logger';

// Сколько ждать завершения текущих запросов после SIGTERM (docker stop даёт 10 с)
const SHUTDOWN_TIMEOUT_MS = 8000;
// Пауза между «/ready = 503» и закрытием сокета, чтобы nginx успел убрать копию
const DRAIN_DELAY_MS = appConfig.nodeEnv === 'production' ? 2000 : 0;

const state: AppState = { shuttingDown: false };
const app = createApp(state);

const server = app.listen(Number(appConfig.port), '0.0.0.0', () => {
  logger.info(
    {
      port: appConfig.port,
      storageRoot: appConfig.storageRoot,
      storageExists: fs.existsSync(appConfig.storageRoot),
    },
    `Server running on http://localhost:${appConfig.port}, docs at /api-docs`
  );
});

const shutdown = (signal: string) => {
  if (state.shuttingDown) return;
  state.shuttingDown = true;
  logger.info({ signal }, 'Получен сигнал остановки, дожидаемся текущих запросов');

  const forceExit = setTimeout(() => {
    logger.error('Запросы не завершились вовремя, выходим принудительно');
    process.exit(1);
  }, SHUTDOWN_TIMEOUT_MS + DRAIN_DELAY_MS);
  forceExit.unref();

  setTimeout(() => {
    // Новые соединения не принимаются, текущие запросы дорабатывают
    server.close(async (error) => {
      try {
        await sql.end({ timeout: 5 });
      } catch (dbError) {
        logger.error({ err: dbError }, 'Ошибка при закрытии пула БД');
      }
      logger.info('Сервер остановлен');
      process.exit(error ? 1 : 0);
    });
    // keep-alive соединения без активных запросов иначе держат close до таймаута
    server.closeIdleConnections();
  }, DRAIN_DELAY_MS);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

process.on('unhandledRejection', (reason) => {
  logger.error({ err: reason }, 'Необработанный rejection');
});
