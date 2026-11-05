import { Request, Response, NextFunction } from 'express';
import { ZodError } from 'zod';
import { logger } from '../utils/logger';

export interface AppError extends Error {
  statusCode?: number;
  issues?: unknown;
}

export const errorHandler = (
  err: AppError | ZodError,
  req: Request,
  res: Response,
  next: NextFunction
) => {
  if (err instanceof ZodError) {
    res.status(400).json({
      error: 'Ошибка валидации',
      issues: err.issues,
    });
    return;
  }

  const statusCode = err.statusCode || 500;
  const message = err.message || 'Внутренняя ошибка сервера';

  // req.log добавляет pino-http (с id запроса); без него — общий логгер
  const log = (req as Request & { log?: typeof logger }).log ?? logger;
  if (statusCode >= 500) {
    log.error({ err, path: req.path, method: req.method }, message);
  } else {
    log.warn({ statusCode, path: req.path, method: req.method }, message);
  }

  res.status(statusCode).json({
    // Текст внутренних ошибок (SQL, файловая система) клиенту в production не показываем
    error: statusCode >= 500 && process.env.NODE_ENV === 'production' ? 'Внутренняя ошибка сервера' : message,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
  return;
};

export const notFoundHandler = (req: Request, res: Response) => {
  res.status(404).json({
    error: `Маршрут ${req.method} ${req.path} не найден`,
  });
};
