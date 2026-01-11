import { Router } from 'express';
import { asyncHandler } from '../../middleware/asyncHandler';
import { TopChartController } from './top-chart.controller';

const router = Router();

router.get('/', asyncHandler(TopChartController.getActiveTopCharts));
router.get('/:id/stream', asyncHandler(TopChartController.streamTrack));

export default router;