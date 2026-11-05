import { Request, Response } from 'express';
import { AuthService } from './auth.service';
import {
  loginSchema,
  logoutSchema,
  refreshTokenSchema,
  registerSchema,
} from './auth.validators';
import { AuthenticatedRequest } from '../../middleware/authGuard';

// User-Agent пишется в refresh_tokens, чтобы потом можно было показать список сессий
const deviceOf = (req: Request) => (req.get('user-agent') ?? '').slice(0, 255) || null;

export class AuthController {
  static async register(req: Request, res: Response) {
    const payload = registerSchema.parse(req.body);
    const result = await AuthService.register(payload, deviceOf(req));
    res.status(201).json(result);
  }

  static async login(req: Request, res: Response) {
    const payload = loginSchema.parse(req.body);
    const result = await AuthService.login(payload, deviceOf(req));
    res.json(result);
  }

  static async refreshToken(req: Request, res: Response) {
    const { refreshToken } = refreshTokenSchema.parse(req.body);
    const tokens = await AuthService.refreshTokens(refreshToken, deviceOf(req));
    res.json(tokens);
  }

  static async me(req: AuthenticatedRequest, res: Response) {
    const userId = Number(req.user?.sub);
    if (!userId) {
      res.status(401).json({ error: 'Необходима аутентификация' });
      return;
    }

    const user = await AuthService.getProfile(userId);
    res.json({ user });
  }

  static async logout(req: Request, res: Response) {
    const { refreshToken, allDevices } = logoutSchema.parse(req.body ?? {});
    const result = await AuthService.logout(refreshToken, allDevices);
    res.json(result);
  }
}

