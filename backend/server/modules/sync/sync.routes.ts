import { Router } from 'express';
import { asyncHandler } from '../../middleware/asyncHandler';
import { authGuard } from '../../middleware/authGuard';
import { SyncController } from './sync.controller';

const router = Router();

console.log('[SyncRoutes] Initializing sync routes...');

/**
 * @swagger
 * tags:
 *   name: Sync
 *   description: Синхронизация плейлистов пользователя
 */

/**
 * @swagger
 * /sync/data:
 *   get:
 *     summary: Получить все данные пользователя для синхронизации
 *     tags: [Sync]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Данные пользователя
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/SyncData'
 *       401:
 *         description: Необходима аутентификация
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.get('/data', authGuard, asyncHandler(SyncController.getData));
console.log('[SyncRoutes] ✓ GET /data registered');

/**
 * @swagger
 * /sync/upload:
 *   post:
 *     summary: Загрузить все данные пользователя на сервер
 *     tags: [Sync]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/SyncData'
 *     responses:
 *       200:
 *         description: Данные успешно сохранены
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 *       401:
 *         description: Необходима аутентификация
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.post('/upload', authGuard, asyncHandler(SyncController.uploadData));


/**
 * @swagger
 * /sync/playlists:
 *   post:
 *     summary: Синхронизировать только плейлисты
 *     tags: [Sync]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: array
 *             items:
 *               $ref: '#/components/schemas/UserPlaylist'
 *     responses:
 *       200:
 *         description: Плейлисты успешно сохранены
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 *       401:
 *         description: Необходима аутентификация
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.post('/playlists', authGuard, asyncHandler(SyncController.uploadPlaylists));
console.log('[SyncRoutes] ✓ POST /playlists registered');

export default router;

