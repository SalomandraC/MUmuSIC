import { Router } from 'express';
import { checkAuth, login, logout, register } from '../api/auth';
import { asyncHandler } from '../middleware/asyncHandler';

const router = Router();

router.post('/register', asyncHandler(register));

router.post('/login', asyncHandler(login));

router.post('/logout', asyncHandler(logout));

router.get('/checkAuth', asyncHandler(checkAuth));

export default router;

