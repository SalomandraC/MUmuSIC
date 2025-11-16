import dotenv from 'dotenv';
dotenv.config();
import express, { Application } from 'express';
import cors from 'cors';
import session from 'express-session';
import morgan from 'morgan';
import swaggerUi from 'swagger-ui-express';
import { swaggerSpec } from './config/swagger';
import authRoutes from './routes/auth.routes';
import { errorHandler, notFoundHandler } from './middleware/errorHandler';
import filesRoutes from './routes/files.routes';

const app: Application = express();

// Конфигурация
const PORT = process.env.PORT || 5000;
const SESSION_SECRET = process.env.SESSION_SECRET || 'change-this-secret-in-production';
const NODE_ENV = process.env.NODE_ENV || 'development';

const allowedOrigins = [
  'http://localhost:3000',
  'https://f4x1pn2ft.localto.net',
  'http://d91098wj.beget.tech'
];

// Middleware
if (NODE_ENV === 'development') {
  app.use(morgan('dev'));
} else {
  app.use(morgan('combined'));
}

app.use(session({
  secret: SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: NODE_ENV === 'production', 
    httpOnly: true,
    maxAge: 24 * 60 * 60 * 1000 * 10 
  }
}));

app.use(cors({
  origin: (origin, callback) => {
    if (!origin) return callback(null, true);

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
    'localtonet-skip-warning'
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
app.use('/', authRoutes);
app.use('/', filesRoutes);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Обработка 404
app.use(notFoundHandler);

// Централизованная обработка ошибок
app.use(errorHandler);

// Запуск сервера
app.listen(Number(PORT), '0.0.0.0', () => {
  console.log(`🚀 Server running on http://0.0.0.0:${PORT}`);
  console.log(`📚 Swagger docs available at http://0.0.0.0:${PORT}/api-docs`);
  console.log(`🌍 Environment: ${NODE_ENV}`);
});
