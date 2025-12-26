import { Router } from 'express';
import { asyncHandler } from '../../middleware/asyncHandler';
import { authGuard } from '../../middleware/authGuard';
import { TracksController } from './tracks.controller';

const router = Router();

router.post('/', 
  authGuard, 
  TracksController.upload, 
  asyncHandler(TracksController.create)
);

router.get('/', authGuard, asyncHandler(TracksController.getUserTracks));

router.get('/:id', asyncHandler(TracksController.getTrack));

router.delete('/:id', authGuard, asyncHandler(TracksController.deleteTrack));

export default router;

