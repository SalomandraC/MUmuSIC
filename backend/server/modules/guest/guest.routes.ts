import { Router } from 'express';
import sql from '../../config/db';
import path from 'path';
import fs from 'fs';
import mime from 'mime-types';
import { asyncHandler } from '../../middleware/asyncHandler';
import { appConfig } from '../../config/appConfig';

const router = Router();

/**
 * @swagger
 * tags:
 *   name: Guest
 *   description: Треки для гостей
 */

/**
 * @swagger
 * /guest-tracks/health:
 *   get:
 *     summary: Проверка доступности файлового сервера
 *     tags: [Guest]
 *     responses:
 *       200:
 *         description: Статус файлового сервера
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 storageRoot:
 *                   type: string
 *                 exists:
 *                   type: boolean
 *                 filesCount:
 *                   type: integer
 *                 sampleFiles:
 *                   type: array
 *                   items:
 *                     type: string
 */
router.get('/health', asyncHandler(async (req, res) => {
  const storageRoot = appConfig.storageRoot;
  const exists = fs.existsSync(storageRoot);
  let filesCount = 0;
  let sampleFiles: string[] = [];

  if (exists) {
    try {
      const files = fs.readdirSync(storageRoot);
      filesCount = files.length;
      sampleFiles = files.slice(0, 5);
    } catch (error) {
      console.error('[GUEST-HEALTH] Error reading storage directory:', error);
    }
  }

  res.json({
    storageRoot,
    exists,
    filesCount,
    sampleFiles,
  });
}));

/**
 * @swagger
 * /guest-tracks:
 *   get:
 *     summary: Получить список активных гостевых треков
 *     tags: [Guest]
 *     responses:
 *       200:
 *         description: Список треков
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '#/components/schemas/GuestTrack'
 */
router.get('/', asyncHandler(async (req, res) => {
  console.log('[GUEST-LIST] Fetching active guest tracks');
  const rows = await sql`
    SELECT id, title, artist, file_path, file_format, duration, file_size, is_active, play_count, created_at
    FROM guest_tracks
    WHERE is_active = true
    ORDER BY id
  `;

  console.log(`[GUEST-LIST] Found ${rows.length} active tracks`);

  const baseUrl = `${req.protocol}://${req.get('host')}`;
  const withUrls = rows.map((r: any) => ({
    ...r,
    url: `${baseUrl}${r.file_path}`,
    streamUrl: `${baseUrl}/guest-tracks/${r.id}/stream`,
  }));

  res.json(withUrls);
}));

/**
 * @swagger
 * /guest-tracks/by-title/stream:
 *   get:
 *     summary: Потоковая передача гостевого трека по названию
 *     tags: [Guest]
 *     parameters:
 *       - in: query
 *         name: title
 *         required: true
 *         schema:
 *           type: string
 *         description: Название трека
 *         example: "404 Heart"
 *     responses:
 *       200:
 *         description: Аудиопоток
 *         content:
 *           audio/mpeg:
 *             schema:
 *               type: string
 *               format: binary
 *       400:
 *         description: Не указано название трека
 *       404:
 *         description: Трек не найден
 */
router.get('/by-title/stream', asyncHandler(async (req, res) => {
  const title = req.query.title as string;
  
  if (!title || typeof title !== 'string' || title.trim() === '') {
    console.log('[GUEST-STREAM-BY-TITLE] Missing or invalid title parameter');
    res.status(400).json({ error: 'Не указано название трека' });
    return;
  }

  console.log(`[GUEST-STREAM-BY-TITLE] Request for track title="${title}"`);
  
  const result = await sql`
    SELECT id, file_path, file_format, title
    FROM guest_tracks
    WHERE LOWER(TRIM(title)) = LOWER(TRIM(${title})) AND is_active = true
    LIMIT 1
  `;

  console.log(`[GUEST-STREAM-BY-TITLE] DB query result:`, result.length > 0 ? { id: result[0].id, title: result[0].title, file_path: result[0].file_path } : 'not found');

  if (result.length === 0) {
    console.log(`[GUEST-STREAM-BY-TITLE] Track with title="${title}" not found in DB or not active`);
    res.status(404).json({ error: 'Трек не найден' });
    return;
  }

  const track = result[0];
  // Убираем /storage из начала пути, если есть
  const relativePath = track.file_path.startsWith('/storage/') 
    ? track.file_path.replace('/storage/', '')
    : track.file_path.startsWith('/')
    ? track.file_path.slice(1)
    : track.file_path;
  
  const absPath = path.resolve(appConfig.storageRoot, relativePath);
  
  console.log(`[GUEST-STREAM-BY-TITLE] Path resolution:`, {
    dbPath: track.file_path,
    relativePath,
    storageRoot: appConfig.storageRoot,
    absPath,
    exists: fs.existsSync(absPath)
  });

  if (!fs.existsSync(absPath)) {
    console.error(`[GUEST-STREAM-BY-TITLE] File not found: ${absPath}`);
    console.error(`[GUEST-STREAM-BY-TITLE] Storage root: ${appConfig.storageRoot}`);
    console.error(`[GUEST-STREAM-BY-TITLE] Relative path: ${relativePath}`);
    res.status(404).json({ error: 'Файл не найден' });
    return;
  }

  const contentType = mime.lookup(track.file_format || path.extname(absPath)) || 'audio/mpeg';
  res.setHeader('Content-Type', contentType.toString());
  const stat = fs.statSync(absPath);
  res.setHeader('Content-Length', stat.size.toString());
  res.setHeader('Accept-Ranges', 'bytes');

  console.log(`[GUEST-STREAM-BY-TITLE] Streaming file: ${absPath} (${stat.size} bytes, ${contentType})`);

  const stream = fs.createReadStream(absPath);
  stream.on('error', (err) => {
    console.error(`[GUEST-STREAM-BY-TITLE] Stream error for ${absPath}:`, err);
    if (!res.headersSent) {
      res.status(500).json({ error: 'Ошибка чтения файла' });
    }
  });
  stream.pipe(res);
}));

/**
 * @swagger
 * /guest-tracks/{id}/stream:
 *   get:
 *     summary: Потоковая передача гостевого трека
 *     tags: [Guest]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Аудиопоток
 *         content:
 *           audio/mpeg:
 *             schema:
 *               type: string
 *               format: binary
 *       404:
 *         description: Трек не найден
 */
router.get('/:id/stream', asyncHandler(async (req, res) => {
  const id = Number(req.params.id);
  console.log(`[GUEST-STREAM] Request for track id=${id}`);
  
  const result = await sql`
    SELECT id, file_path, file_format
    FROM guest_tracks
    WHERE id = ${id} AND is_active = true
    LIMIT 1
  `;

  console.log(`[GUEST-STREAM] DB query result:`, result.length > 0 ? { id: result[0].id, file_path: result[0].file_path } : 'not found');

  if (result.length === 0) {
    console.log(`[GUEST-STREAM] Track id=${id} not found in DB or not active`);
    res.status(404).json({ error: 'Трек не найден' });
    return;
  }

  const track = result[0];
  // Убираем /storage из начала пути, если есть
  const relativePath = track.file_path.startsWith('/storage/') 
    ? track.file_path.replace('/storage/', '')
    : track.file_path.startsWith('/')
    ? track.file_path.slice(1)
    : track.file_path;
  
  const absPath = path.resolve(appConfig.storageRoot, relativePath);
  
  console.log(`[GUEST-STREAM] Path resolution:`, {
    dbPath: track.file_path,
    relativePath,
    storageRoot: appConfig.storageRoot,
    absPath,
    exists: fs.existsSync(absPath)
  });

  if (!fs.existsSync(absPath)) {
    console.error(`[GUEST-STREAM] File not found: ${absPath}`);
    console.error(`[GUEST-STREAM] Storage root: ${appConfig.storageRoot}`);
    console.error(`[GUEST-STREAM] Relative path: ${relativePath}`);
    res.status(404).json({ error: 'Файл не найден' });
    return;
  }

  const contentType = mime.lookup(track.file_format || path.extname(absPath)) || 'audio/mpeg';
  res.setHeader('Content-Type', contentType.toString());
  const stat = fs.statSync(absPath);
  res.setHeader('Content-Length', stat.size.toString());
  res.setHeader('Accept-Ranges', 'bytes');

  console.log(`[GUEST-STREAM] Streaming file: ${absPath} (${stat.size} bytes, ${contentType})`);

  const stream = fs.createReadStream(absPath);
  stream.on('error', (err) => {
    console.error(`[GUEST-STREAM] Stream error for ${absPath}:`, err);
    if (!res.headersSent) {
      res.status(500).json({ error: 'Ошибка чтения файла' });
    }
  });
  stream.pipe(res);
}));

export default router;


