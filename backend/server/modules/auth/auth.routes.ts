import { Router } from 'express';
import { asyncHandler } from '../../middleware/asyncHandler';
import { authGuard } from '../../middleware/authGuard';
import { AuthController } from './auth.controller';

const router = Router();

router.post('/register', asyncHandler(AuthController.register));

router.post('/login', asyncHandler(AuthController.login));

router.post('/logout', asyncHandler(AuthController.logout));

router.get('/me', authGuard, asyncHandler(AuthController.me));

router.post('/refresh-token', asyncHandler(AuthController.refreshToken));

export default router;

