import { Router } from 'express';
import { asyncHandler } from '../../middleware/asyncHandler';
import { authGuard } from '../../middleware/authGuard';
import { TracksController } from './tracks.controller';

const router = Router();

console.log('[TracksRoutes] Initializing tracks routes...');

/**
 * @swagger
 * tags:
 *   name: Tracks
 *   description: Управление загруженными аудиотреками пользователя
 */

/**
 * @swagger
 * /tracks:
 *   post:
 *     summary: Загрузить новый трек
 *     tags: [Tracks]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             required:
 *               - file
 *             properties:
 *               file:
 *                 type: string
 *                 format: binary
 *                 description: Аудиофайл (mp3, wav, m4a, flac)
 *               title:
 *                 type: string
 *                 description: Название трека
 *               artist:
 *                 type: string
 *                 description: Исполнитель
 *               album:
 *                 type: string
 *                 description: Альбом
 *               duration:
 *                 type: integer
 *                 description: Длительность в секундах
 *               notes:
 *                 type: string
 *                 description: Заметки
 *               is_public:
 *                 type: boolean
 *                 description: Публичный доступ
 *     responses:
 *       201:
 *         description: Трек успешно загружен
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/TrackResponse'
 *       400:
 *         description: Ошибка валидации
 *       401:
 *         description: Необходима аутентификация
 */
// Тестовый роут для проверки
router.post('/test', (req, res) => {
  console.log('[TracksRoutes] TEST POST /test called');
  res.json({ message: 'Test route works!' });
});

router.post('/', 
  (req, res, next) => {
    console.log(`[TracksRoutes] POST / middleware called`);
    console.log(`  Path: ${req.path}`);
    console.log(`  Method: ${req.method}`);
    console.log(`  Content-Type: ${req.headers['content-type']}`);
    next();
  },
  authGuard, 
  (req, res, next) => {
    console.log(`[TracksRoutes] After authGuard, calling multer`);
    next();
  },
  TracksController.upload, 
  (req, res, next) => {
    console.log(`[TracksRoutes] After multer, calling controller`);
    next();
  },
  asyncHandler(TracksController.create)
);
console.log('[TracksRoutes] ✓ POST / registered');

/**
 * @swagger
 * /tracks:
 *   get:
 *     summary: Получить список треков пользователя
 *     tags: [Tracks]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Список треков
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 tracks:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/TrackResponse'
 *       401:
 *         description: Необходима аутентификация
 */
router.get('/', authGuard, asyncHandler(TracksController.getUserTracks));

/**
 * @swagger
 * /tracks/{id}:
 *   get:
 *     summary: Получить информацию о треке
 *     tags: [Tracks]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Информация о треке
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/TrackResponse'
 *       404:
 *         description: Трек не найден
 */
router.get('/:id', asyncHandler(TracksController.getTrack));

/**
 * @swagger
 * /tracks/{id}:
 *   delete:
 *     summary: Удалить трек
 *     tags: [Tracks]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     responses:
 *       204:
 *         description: Трек успешно удален
 *       404:
 *         description: Трек не найден
 *       401:
 *         description: Необходима аутентификация
 */
router.delete('/:id', authGuard, asyncHandler(TracksController.deleteTrack));

console.log('[TracksRoutes] Routes initialized:');
console.log('  POST /');
console.log('  GET /');
console.log('  GET /:id');
console.log('  DELETE /:id');

export default router;

