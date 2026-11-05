import crypto from 'crypto';
import fs from 'fs';
import express, { Application, Request } from 'express';
import cors from 'cors';
import pinoHttp from 'pino-http';
import swaggerUi from 'swagger-ui-express';
import { swaggerSpec } from './swagger';
import { appConfig } from './config/appConfig';
import sql from './config/db';
import { logger } from './utils/logger';
import authRoutes from './modules/auth/auth.routes';
import { errorHandler, notFoundHandler } from './middleware/errorHandler';
import { storageGuard } from './middleware/storageGuard';
import syncRoutes from './modules/sync/sync.routes';
import tracksRoutes from './modules/tracks/tracks.routes';
import topChartRoutes from './modules/top-chart/top-chart.routes';
import guestRoutes from './modules/guest/guest.routes';

const allowedOrigins = [
  'http://localhost:3000',
  'http://localhost:5050',
  'https://f4x1pn2ft.localto.net',
  'http://d91098wj.beget.tech',
  ...appConfig.corsOrigins,
];

// Берём X-Request-Id от nginx, если он есть, иначе создаём свой.
// Тот же id возвращается клиенту, чтобы по нему найти запрос в логах
const requestId = (req: Request) => {
  const header = req.headers['x-request-id'];
  const incoming = Array.isArray(header) ? header[0] : header;
  return incoming && /^[\w-]{1,128}$/.test(incoming) ? incoming : crypto.randomUUID();
};

// Подписанный ?token= не должен попадать в логи
const stripToken = (url: string) => url.replace(/([?&]token=)[^&]+/, '$1[скрыто]');

const READY_TIMEOUT_MS = 2000;

const withTimeout = <T>(promise: Promise<T>, ms: number) =>
  Promise.race([
    promise,
    new Promise<never>((_, reject) => setTimeout(() => reject(new Error(`timeout ${ms}ms`)), ms)),
  ]);

export interface AppState {
  /** true после SIGTERM: /ready отвечает 503, чтобы балансировщик перестал слать запросы */
  shuttingDown: boolean;
}

export const createApp = (state: AppState = { shuttingDown: false }): Application => {
  const app = express();

  // За nginx: правильные req.ip и req.protocol (нужны для URL в ответах и rate limit)
  app.set('trust proxy', 1);

  app.use(
    pinoHttp({
      logger,
      genReqId: (req, res) => {
        const id = requestId(req as Request);
        res.setHeader('X-Request-Id', id);
        return id;
      },
      customLogLevel: (_req, res, err) => {
        if (err || res.statusCode >= 500) return 'error';
        if (res.statusCode >= 400) return 'warn';
        return 'info';
      },
      // Проверки балансировщика каждые несколько секунд только засоряют лог
      autoLogging: { ignore: (req) => req.url === '/health' || req.url === '/ready' },
      serializers: {
        req: (req) => ({ id: req.id, method: req.method, url: stripToken(req.url ?? '') }),
        res: (res) => ({ statusCode: res.statusCode }),
      },
    })
  );

  app.use(cors({
    origin: (origin, callback) => {
      if (appConfig.nodeEnv === 'development') {
        return callback(null, true);
      }

      if (!origin) {
        return callback(null, true);
      }

      if (allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        callback(new Error('Not allowed by CORS'));
      }
    },
    methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: [
      'Content-Type',
      'Authorization',
      'localtonet-skip-warning',
      'Range',
      'Accept-Ranges',
      'Content-Range',
      'Accept',
      'X-Request-Id'
    ],
    exposedHeaders: [
      'Content-Range',
      'Accept-Ranges',
      'Content-Length',
      'Content-Type',
      'X-Request-Id'
    ],
    credentials: true,
    optionsSuccessStatus: 200
  }));

  app.options('*', cors());

  app.use(express.json());
  app.use(express.urlencoded({ extended: true }));

  app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec, {
    customCss: '.swagger-ui .topbar { display: none }',
    customSiteTitle: 'Study Practice API Documentation'
  }));

  // Процесс жив. Ничего внешнего не проверяет, чтобы Docker не перезапускал
  // контейнер из-за временно недоступной базы
  app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
  });

  // Готов принимать трафик: есть база и хранилище. По нему балансировщик
  // и docker compose решают, слать ли запросы в эту копию
  app.get('/ready', async (req, res) => {
    if (state.shuttingDown) {
      res.status(503).json({ status: 'shutting_down' });
      return;
    }

    const checks: Record<string, 'ok' | string> = {};
    try {
      await withTimeout(sql`SELECT 1`, READY_TIMEOUT_MS);
      checks.database = 'ok';
    } catch (error) {
      checks.database = (error as Error).message;
    }
    checks.storage = fs.existsSync(appConfig.storageRoot) ? 'ok' : 'not found';

    const ready = Object.values(checks).every((value) => value === 'ok');
    res.status(ready ? 200 : 503).json({ status: ready ? 'ready' : 'not_ready', checks });
  });

  // Роуты
  app.use('/auth', authRoutes);

  // Личные файлы (users/{id}/...) — только владельцу, общие треки — всем
  app.use('/storage', storageGuard, express.static(appConfig.storageRoot, {
    dotfiles: 'deny',
    index: false,
    setHeaders: (res) => {
      res.setHeader('Accept-Ranges', 'bytes');
      res.setHeader(
        'Cache-Control',
        res.locals.storageAccess === 'private' ? 'private, max-age=3600' : 'public, max-age=3600'
      );
    }
  }));
  app.use('/sync', syncRoutes);

  app.use('/tracks', tracksRoutes);

  app.use('/top-charts', topChartRoutes);

  app.use('/guest-tracks', guestRoutes);

  app.use(notFoundHandler);

  app.use(errorHandler);

  return app;
};
