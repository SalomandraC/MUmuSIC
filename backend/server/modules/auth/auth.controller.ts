import { Request, Response } from 'express';
import { AuthService } from './auth.service';
import {
  changePasswordSchema,
  guestSessionValidateSchema,
  loginSchema,
  refreshTokenSchema,
  registerSchema,
  resetPasswordConfirmSchema,
  resetPasswordRequestSchema,
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

  static async createGuestSession(req: Request, res: Response) {
    const session = await AuthService.createGuestSession();
    res.status(201).json(session);
  }

  static async validateGuestSession(req: Request, res: Response) {
    const payload = guestSessionValidateSchema.parse(req.body);
    const session = await AuthService.validateGuestSession(payload);
    res.json(session);
  }

  static async changePassword(req: AuthenticatedRequest, res: Response) {
    const payload = changePasswordSchema.parse(req.body);
    const userId = Number(req.user?.sub);

    if (!userId) {
      res.status(401).json({ error: 'Необходима аутентификация' });
      return;
    }

    const user = await AuthService.changePassword({
      ...payload,
      userId,
    });

    res.json({ user });
  }

  static async resetPasswordRequest(req: Request, res: Response) {
    const payload = resetPasswordRequestSchema.parse(req.body);
    const result = await AuthService.resetPasswordRequest(payload);
    res.json(result);
  }

  static async resetPasswordConfirm(req: Request, res: Response) {
    const payload = resetPasswordConfirmSchema.parse(req.body);
    const result = await AuthService.resetPasswordConfirm(payload);
    res.json(result);
  }
}

