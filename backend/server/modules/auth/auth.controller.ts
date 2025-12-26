import { Request, Response } from 'express';
import { AuthService } from './auth.service';
import {
  loginSchema,
  refreshTokenSchema,
  registerSchema,
} from './auth.validators';
import { AuthenticatedRequest } from '../../middleware/authGuard';

export class AuthController {
  static async register(req: Request, res: Response) {
    const payload = registerSchema.parse(req.body);
    const result = await AuthService.register(payload);
    res.status(201).json(result);
  }

  static async login(req: Request, res: Response) {
    const payload = loginSchema.parse(req.body);
    const result = await AuthService.login(payload);
    res.json(result);
  }

  static async refreshToken(req: Request, res: Response) {
    const { refreshToken } = refreshTokenSchema.parse(req.body);
    const tokens = await AuthService.refreshTokens(refreshToken);
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
    const result = await AuthService.logout();
    res.json(result);
  }
}

