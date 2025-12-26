import { NextFunction, Request, Response } from 'express';
import { verifyAccessToken, AuthTokenPayload } from '../services/token.service';
import { UserRole } from '../modules/auth/auth.types';

export interface AuthenticatedRequest extends Request {
  user?: AuthTokenPayload;
}

export const authGuard = (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  console.log(`[AuthGuard] Checking auth for ${req.method} ${req.path}`);
  const authHeader = req.headers.authorization;

  if (!authHeader) {
    console.log(`[AuthGuard] No Authorization header`);
    res.status(401).json({ error: 'Необходим заголовок Authorization' });
    return;
  }

  const [, token] = authHeader.split(' ');

  if (!token) {
    console.log(`[AuthGuard] No token in Authorization header`);
    res.status(401).json({ error: 'Не найден токен доступа' });
    return;
  }

  try {
    const payload = verifyAccessToken(token);
    req.user = payload;
    console.log(`[AuthGuard] Authenticated user: ${payload.sub}`);
    next();
  } catch (error: any) {
    console.log(`[AuthGuard] Token verification failed:`, error);
    
    if (error.name === 'TokenExpiredError') {
      res.status(401).json({ 
        error: 'Токен истек',
        code: 'TOKEN_EXPIRED',
        message: 'Используйте refresh token для получения нового access token',
        expiredAt: error.expiredAt
      });
      return;
    }
    
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

