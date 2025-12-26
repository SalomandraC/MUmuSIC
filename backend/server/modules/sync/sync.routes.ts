import { Router } from 'express';
import { asyncHandler } from '../../middleware/asyncHandler';
import { authGuard } from '../../middleware/authGuard';
import { SyncController } from './sync.controller';

const router = Router();

router.get('/data', authGuard, asyncHandler(SyncController.getData));

router.post('/upload', authGuard, asyncHandler(SyncController.uploadData));

router.post('/playlists', authGuard, asyncHandler(SyncController.uploadPlaylists));

export default router;

