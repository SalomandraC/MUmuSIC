import { NextFunction, Request, Response } from 'express';
import { verifyAccessToken, AuthTokenPayload } from '../services/token.service';
import { UserRole } from '../modules/auth/auth.types';

export interface AuthenticatedRequest extends Request {
  user?: AuthTokenPayload;
}

export const authGuard = (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const authHeader = req.headers.authorization;

  if (!authHeader) {
    res.status(401).json({ error: 'Необходим заголовок Authorization' });
    return;
  }

  const [, token] = authHeader.split(' ');

  if (!token) {
    res.status(401).json({ error: 'Не найден токен доступа' });
    return;
  }

  try {
    const payload = verifyAccessToken(token);
    req.user = payload;
    next();
  } catch (error) {
    res.status(401).json({ error: 'Недействительный или истекший токен' });
  }
};

export const roleGuard = (roles: UserRole[]) => {
  return (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    if (!req.user) {
      res.status(401).json({ error: 'Необходима аутентификация' });
      return;
    }

    if (!roles.includes(req.user.role)) {
      res.status(403).json({ error: 'Недостаточно прав' });
      return;
    }

    next();
  };
};

