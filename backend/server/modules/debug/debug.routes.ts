import { Router } from 'express';
import sql from '../../config/db';
import { asyncHandler } from '../../middleware/asyncHandler';

const router = Router();

/**
 * @swagger
 * tags:
 *   name: Debug
 *   description: Вспомогательные эндпоинты для проверки подключения к БД
 */

/**
 * @swagger
 * /debug/tracks:
 *   get:
 *     summary: Получить все треки (проверка подключения к БД)
 *     tags: [Debug]
 *     responses:
 *       200:
 *         description: Список треков
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '#/components/schemas/Track'
 *       500:
 *         description: Ошибка подключения/запроса к БД
 */
router.get('/tracks', asyncHandler(async (req, res) => {
  const rows = await sql`
    SELECT id, user_id, title, artist, album, duration, file_path, file_format, file_size, notes, is_public, created_at
    FROM tracks
    ORDER BY id
  `;
  res.json(rows);
}));

export default router;


