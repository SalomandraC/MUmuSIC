import path from 'path';
import { NextFunction, Request, Response } from 'express';
import { verifyAccessToken, verifyMediaToken } from '../services/token.service';

export type StorageAccess = 'public' | 'private' | 'deny';

export interface StorageCredentials {
  /** sub из access-токена в заголовке Authorization */
  userId?: number;
  /** Разобранный ?token= из подписанной ссылки */
  media?: { sub: number; path: string };
}

/**
 * Приводит путь запроса к виду внутри STORAGE_ROOT: 'users/3/track.mp3'.
 * null — путь некорректный (выход за корень, скрытые файлы вроде .tmp).
 */
export const normalizeStoragePath = (rawPath: string): string | null => {
  let decoded: string;
  try {
    decoded = decodeURIComponent(rawPath);
  } catch {
    return null;
  }
  if (decoded.includes('\0') || decoded.includes('\\')) return null;

  const normalized = path.posix.normalize('/' + decoded).replace(/^\/+/, '');
  if (!normalized || normalized.startsWith('..')) return null;

  const segments = normalized.split('/');
  if (segments.some((segment) => segment.startsWith('.'))) return null;
  return normalized;
};

/**
 * Правило доступа к файлам:
 * - users/{id}/... — только владелец: access-токен этого пользователя
 *   или подписанная ссылка, выданная именно на этот файл;
 * - всё остальное (общие треки гостей и NFC) — публично.
 */
export const resolveStorageAccess = (relPath: string, creds: StorageCredentials): StorageAccess => {
  const segments = relPath.split('/');
  if (segments[0] !== 'users') return 'public';

  const ownerId = Number(segments[1]);
  if (!Number.isInteger(ownerId) || ownerId <= 0 || segments.length < 3) return 'deny';

  if (creds.userId === ownerId) return 'private';
  if (creds.media && Number(creds.media.sub) === ownerId && creds.media.path === relPath) return 'private';
  return 'deny';
};

const readCredentials = (req: Request): StorageCredentials => {
  const creds: StorageCredentials = {};

  const [scheme, bearer] = (req.headers.authorization ?? '').split(' ');
  if (scheme === 'Bearer' && bearer) {
    try {
      creds.userId = Number(verifyAccessToken(bearer).sub);
    } catch {
      // Невалидный заголовок не даёт доступа, но и не мешает проверить ?token
    }
  }

  const token = typeof req.query.token === 'string' ? req.query.token : undefined;
  if (token) {
    try {
      const media = verifyMediaToken(token);
      creds.media = { sub: Number(media.sub), path: media.path };
    } catch {
      // Просроченная или поддельная ссылка
    }
  }

  return creds;
};

/**
 * Ставится перед express.static('/storage'). На чужие и несуществующие личные
 * файлы отвечает одинаково 404, чтобы по ответу нельзя было перебирать id.
 */
export const storageGuard = (req: Request, res: Response, next: NextFunction) => {
  const relPath = normalizeStoragePath(req.path);
  if (!relPath) {
    res.status(404).json({ error: 'Файл не найден' });
    return;
  }

  const access = resolveStorageAccess(relPath, readCredentials(req));
  if (access === 'deny') {
    res.status(404).json({ error: 'Файл не найден' });
    return;
  }

  res.locals.storageAccess = access;
  next();
};
