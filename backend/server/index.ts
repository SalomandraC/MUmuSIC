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
import syncRoutes from './modules/sync/sync.routes';
import tracksRoutes from './modules/tracks/tracks.routes';
import topChartRoutes from './modules/top-chart/top-chart.routes';

// Проверка загрузки маршрута
console.log('[Server] TopChart routes loaded:', typeof topChartRoutes);

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

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec, {
  customCss: '.swagger-ui .topbar { display: none }',
  customSiteTitle: 'Study Practice API Documentation'
}));

// Роуты
app.use('/auth', authRoutes);

app.use('/storage', express.static(appConfig.storageRoot, {
  setHeaders: (res) => {
    res.setHeader('Accept-Ranges', 'bytes');
    res.setHeader('Cache-Control', 'public, max-age=3600');
  }
}));
app.use('/sync', syncRoutes);

app.use('/tracks', tracksRoutes);

app.use('/top-charts', topChartRoutes);

app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use(notFoundHandler);

app.use(errorHandler);

app.listen(Number(appConfig.port), '0.0.0.0', () => {
  console.log(`Server running on http://localhost:${appConfig.port}`);
  console.log(`Swagger docs available at http://localhost:${appConfig.port}/api-docs`);
  console.log(`Storage root: ${appConfig.storageRoot}`);
  console.log(`Storage exists: ${require('fs').existsSync(appConfig.storageRoot)}`);
});
