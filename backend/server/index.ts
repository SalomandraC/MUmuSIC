import dotenv from 'dotenv';
dotenv.config();
import express, { Application } from 'express';
import cors from 'cors';
import morgan from 'morgan';
import swaggerUi from 'swagger-ui-express';
import { swaggerSpec } from './swagger';
import { appConfig } from './config/appConfig';
import authRoutes from './modules/auth/auth.routes';
import { errorHandler, notFoundHandler } from './middleware/errorHandler';
import debugRoutes from './modules/debug/debug.routes';
import guestRoutes from './modules/guest/guest.routes';
import filesRoutes from './modules/files/files.routes';
import syncRoutes from './modules/sync/sync.routes';
import tracksRoutes from './modules/tracks/tracks.routes';

const app: Application = express();

const allowedOrigins = [
  'http://localhost:3000',
  'http://localhost:5050',
  'https://f4x1pn2ft.localto.net',
  'http://d91098wj.beget.tech'
];

// Middleware
if (appConfig.nodeEnv === 'development') {
  app.use(morgan('dev'));
} else {
  app.use(morgan('combined'));
}

// Логирование ВСЕХ запросов для отладки
app.use((req, res, next) => {
  if (req.method === 'POST' && (req.path === '/tracks' || req.path.startsWith('/tracks'))) {
    console.log(`\n[EARLY] POST ${req.path} request`);
    console.log(`  Original URL: ${req.originalUrl}`);
    console.log(`  Base URL: ${req.baseUrl}`);
  }
  next();
});

// Логирование всех запросов для отладки
app.use((req, res, next) => {
  if (req.path === '/tracks' && req.method === 'POST') {
    console.log(`\n[GlobalMiddleware] POST /tracks request received`);
    console.log(`  Path: ${req.path}`);
    console.log(`  Original URL: ${req.originalUrl}`);
    console.log(`  Base URL: ${req.baseUrl}`);
    console.log(`  Content-Type: ${req.headers['content-type']}`);
    console.log(`  Authorization: ${req.headers.authorization ? 'present' : 'missing'}`);
  }
  next();
});

app.use(cors({
  origin: (origin, callback) => {
    if (appConfig.nodeEnv === 'development') {
      return callback(null, true);
    }

    // В production используем строгий список
    if (!origin) {
      // Для мобильных приложений origin может отсутствовать
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
    'Accept'
  ],
  exposedHeaders: [
    'Content-Range',
    'Accept-Ranges',
    'Content-Length',
    'Content-Type'
  ],
  credentials: true,
  optionsSuccessStatus: 200
}));

app.options('*', cors());

// Body parsers (но не для multipart/form-data, которое обрабатывает multer)
// Важно: пропускаем multipart/form-data, чтобы multer мог обработать его первым
app.use((req, res, next) => {
  const contentType = req.headers['content-type'] || '';
  if (contentType.includes('multipart/form-data')) {
    // Пропускаем multipart запросы - их обработает multer
    console.log('[BodyParser] Skipping multipart/form-data for:', req.method, req.path);
    return next();
  }
  next();
});
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec, {
  customCss: '.swagger-ui .topbar { display: none }',
  customSiteTitle: 'Study Practice API Documentation'
}));

// Middleware для логирования входящих запросов (только для проблемных путей)
app.use((req, res, next) => {
  if (req.path.startsWith('/tracks') || req.path.startsWith('/sync')) {
    console.log(`\n[RequestMiddleware] ${req.method} ${req.path}`);
    console.log(`  Original URL: ${req.originalUrl}`);
    console.log(`  Base URL: ${req.baseUrl}`);
    console.log(`  Content-Type: ${req.headers['content-type']}`);
    console.log(`  Authorization: ${req.headers.authorization ? 'present' : 'missing'}`);
  }
  next();
});

// Роуты
console.log('[Server] Registering routes...');
app.use('/auth', authRoutes);
console.log('[Server] ✓ /auth registered');
app.use('/debug', debugRoutes);
console.log('[Server] ✓ /debug registered');
// Раздача статических файлов из папки storage (для путей вида /storage/*.mp3)
app.use('/storage', (req, res, next) => {
  console.log(`[Storage] ${req.method} ${req.path}`);
  console.log(`  Original URL: ${req.originalUrl}`);
  console.log(`  Storage root: ${appConfig.storageRoot}`);
  next();
}, express.static(appConfig.storageRoot, {
  setHeaders: (res, path) => {
    console.log(`[Storage] Serving file: ${path}`);
    res.setHeader('Accept-Ranges', 'bytes');
    res.setHeader('Cache-Control', 'public, max-age=3600');
  }
}));
console.log('[Server] ✓ /storage registered');
// Гостевые треки
app.use('/guest-tracks', guestRoutes);
console.log('[Server] ✓ /guest-tracks registered');
// Синхронизация данных пользователя
app.use('/sync', syncRoutes);
console.log('[Server] ✓ /sync registered');
// Управление загруженными треками (должен быть до filesRoutes, чтобы не конфликтовать)
app.use('/tracks', (req, res, next) => {
  console.log(`[TracksRouter] ${req.method} ${req.path} -> tracksRoutes`);
  next();
}, tracksRoutes);
console.log('[Server] ✓ /tracks registered');
// Files API (upload/list/delete under /files) and direct serving under /:accountId/:fileName
app.use('/', (req, res, next) => {
  if (req.path.startsWith('/tracks')) {
    console.log(`[FilesRouter] WARNING: /tracks request reached filesRoutes! This should not happen.`);
  }
  next();
}, filesRoutes);
console.log('[Server] ✓ / filesRoutes registered (catch-all, must be last)');

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Обработка 404
app.use(notFoundHandler);

// Централизованная обработка ошибок
app.use(errorHandler);

// Запуск сервера
app.listen(Number(appConfig.port), '0.0.0.0', () => {
  console.log(`Server running on http://localhost:${appConfig.port}`);
  console.log(`Swagger docs available at http://localhost:${appConfig.port}/api-docs`);
  console.log(`Storage root: ${appConfig.storageRoot}`);
  console.log(`Storage exists: ${require('fs').existsSync(appConfig.storageRoot)}`);
});
