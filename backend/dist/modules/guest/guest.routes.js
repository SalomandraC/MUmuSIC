"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const db_1 = __importDefault(require("../../config/db"));
const path_1 = __importDefault(require("path"));
const fs_1 = __importDefault(require("fs"));
const mime_types_1 = __importDefault(require("mime-types"));
const asyncHandler_1 = require("../../middleware/asyncHandler");
const appConfig_1 = require("../../config/appConfig");
const router = (0, express_1.Router)();
/**
 * Обработка Range-запросов для потоковой передачи
 * @param req - Express request
 * @param res - Express response
 * @param filePath - Путь к файлу
 * @param contentType - MIME-тип файла
 * @returns Объект с информацией о диапазоне или null, если Range не указан
 */
function handleRangeRequest(req, res, filePath, contentType) {
    const stat = fs_1.default.statSync(filePath);
    const fileSize = stat.size;
    const range = req.headers.range;
    if (!range) {
        // Обычный запрос без Range
        res.setHeader('Content-Type', contentType);
        res.setHeader('Content-Length', fileSize.toString());
        res.setHeader('Accept-Ranges', 'bytes');
        return null;
    }
    // Парсинг Range заголовка (например, "bytes=0-1023" или "bytes=1024-")
    const parts = range.replace(/bytes=/, '').split('-');
    const start = parseInt(parts[0], 10);
    const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;
    // Валидация диапазона
    if (start >= fileSize || end >= fileSize || start > end) {
        res.status(416).setHeader('Content-Range', `bytes */${fileSize}`);
        res.end();
        return null;
    }
    const chunkSize = (end - start) + 1;
    // Установка заголовков для частичного контента
    res.status(206); // Partial Content
    res.setHeader('Content-Range', `bytes ${start}-${end}/${fileSize}`);
    res.setHeader('Accept-Ranges', 'bytes');
    res.setHeader('Content-Length', chunkSize.toString());
    res.setHeader('Content-Type', contentType);
    return { start, end, fileSize };
}
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
router.get('/health', (0, asyncHandler_1.asyncHandler)(async (req, res) => {
    const storageRoot = appConfig_1.appConfig.storageRoot;
    const exists = fs_1.default.existsSync(storageRoot);
    let filesCount = 0;
    let sampleFiles = [];
    if (exists) {
        try {
            const files = fs_1.default.readdirSync(storageRoot);
            filesCount = files.length;
            sampleFiles = files.slice(0, 5);
        }
        catch (error) {
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
router.get('/', (0, asyncHandler_1.asyncHandler)(async (req, res) => {
    console.log('[GUEST-LIST] Fetching active guest tracks');
    const rows = await (0, db_1.default) `
    SELECT id, title, artist, file_path, file_format, duration, file_size, is_active, play_count, created_at
    FROM guest_tracks
    WHERE is_active = true
    ORDER BY id
  `;
    console.log(`[GUEST-LIST] Found ${rows.length} active tracks`);
    const baseUrl = `${req.protocol}://${req.get('host')}`;
    const withUrls = rows.map((r) => ({
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
router.get('/by-title/stream', (0, asyncHandler_1.asyncHandler)(async (req, res) => {
    const title = req.query.title;
    if (!title || typeof title !== 'string' || title.trim() === '') {
        console.log('[GUEST-STREAM-BY-TITLE] Missing or invalid title parameter');
        res.status(400).json({ error: 'Не указано название трека' });
        return;
    }
    console.log(`[GUEST-STREAM-BY-TITLE] Request for track title="${title}"`);
    const result = await (0, db_1.default) `
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
    const absPath = path_1.default.resolve(appConfig_1.appConfig.storageRoot, relativePath);
    console.log(`[GUEST-STREAM-BY-TITLE] Path resolution:`, {
        dbPath: track.file_path,
        relativePath,
        storageRoot: appConfig_1.appConfig.storageRoot,
        absPath,
        exists: fs_1.default.existsSync(absPath)
    });
    if (!fs_1.default.existsSync(absPath)) {
        console.error(`[GUEST-STREAM-BY-TITLE] File not found: ${absPath}`);
        console.error(`[GUEST-STREAM-BY-TITLE] Storage root: ${appConfig_1.appConfig.storageRoot}`);
        console.error(`[GUEST-STREAM-BY-TITLE] Relative path: ${relativePath}`);
        res.status(404).json({ error: 'Файл не найден' });
        return;
    }
    const contentType = mime_types_1.default.lookup(track.file_format || path_1.default.extname(absPath)) || 'audio/mpeg';
    const rangeInfo = handleRangeRequest(req, res, absPath, contentType.toString());
    if (rangeInfo === null && res.headersSent) {
        return;
    }
    const stat = fs_1.default.statSync(absPath);
    const logMessage = rangeInfo
        ? `[GUEST-STREAM-BY-TITLE] Streaming range ${rangeInfo.start}-${rangeInfo.end} of ${absPath} (${stat.size} bytes, ${contentType})`
        : `[GUEST-STREAM-BY-TITLE] Streaming full file: ${absPath} (${stat.size} bytes, ${contentType})`;
    console.log(logMessage);
    const streamOptions = rangeInfo
        ? { start: rangeInfo.start, end: rangeInfo.end }
        : {};
    const stream = fs_1.default.createReadStream(absPath, streamOptions);
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
 * /guest-tracks/nfc/stream:
 *   get:
 *     summary: Потоковая передача трека из папки NFC по названию
 *     tags: [Guest]
 *     parameters:
 *       - in: query
 *         name: title
 *         required: true
 *         schema:
 *           type: string
 *         description: Название трека (без расширения или с расширением)
 *         example: "Veter"
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
router.get('/nfc/stream', (0, asyncHandler_1.asyncHandler)(async (req, res) => {
    const title = req.query.title;
    if (!title || typeof title !== 'string' || title.trim() === '') {
        console.log('[NFC-STREAM] Missing or invalid title parameter');
        res.status(400).json({ error: 'Не указано название трека' });
        return;
    }
    console.log(`[NFC-STREAM] Request for track title="${title}"`);
    // Путь к папке NFC
    const nfcDir = path_1.default.resolve(appConfig_1.appConfig.storageRoot, 'nfc');
    if (!fs_1.default.existsSync(nfcDir)) {
        console.error(`[NFC-STREAM] NFC directory not found: ${nfcDir}`);
        res.status(404).json({ error: 'Папка NFC не найдена' });
        return;
    }
    // Получаем список файлов в папке NFC
    const files = fs_1.default.readdirSync(nfcDir);
    console.log(`[NFC-STREAM] Files in NFC directory:`, files);
    // Очищаем title от невидимых символов и пробелов
    let cleanedTitle = title.trim();
    // Удаляем невидимые/контрольные символы в начале (коды < 32)
    while (cleanedTitle.length > 0 && cleanedTitle.charCodeAt(0) < 32) {
        cleanedTitle = cleanedTitle.substring(1);
    }
    cleanedTitle = cleanedTitle.trim();
    // Удаляем префикс "en" если есть
    if (cleanedTitle.length >= 2 && cleanedTitle.substring(0, 2).toLowerCase() === 'en') {
        cleanedTitle = cleanedTitle.substring(2).trim();
    }
    console.log(`[NFC-STREAM] Cleaned title: "${cleanedTitle}" (original: "${title}")`);
    // Ищем файл по названию (без учета регистра и расширения)
    const titleLower = cleanedTitle.toLowerCase();
    const audioExtensions = ['.mp3', '.wav', '.m4a', '.aac', '.ogg', '.flac'];
    const foundFile = files.find(file => {
        const fileNameWithoutExt = path_1.default.parse(file).name.toLowerCase();
        const fileLower = file.toLowerCase();
        const fileExt = path_1.default.extname(file).toLowerCase();
        // 1. Точное совпадение имени файла без расширения
        if (fileNameWithoutExt === titleLower) {
            return true;
        }
        // 2. Точное совпадение полного имени файла
        if (fileLower === titleLower) {
            return true;
        }
        // 3. Проверяем все возможные аудио расширения
        for (const ext of audioExtensions) {
            if (fileLower === `${titleLower}${ext}`) {
                return true;
            }
        }
        // 4. Гибкий поиск: если имя файла начинается с title или содержит title
        // Например, "Dream" найдет "Dreams" или "enDreams"
        if (fileNameWithoutExt.startsWith(titleLower) || titleLower.startsWith(fileNameWithoutExt)) {
            return true;
        }
        // 5. Если файл начинается с "en", проверяем без этого префикса
        if (fileNameWithoutExt.startsWith('en') && fileNameWithoutExt.substring(2) === titleLower) {
            return true;
        }
        // 6. Если title начинается с "en", проверяем файл без этого префикса
        if (titleLower.startsWith('en') && fileNameWithoutExt === titleLower.substring(2)) {
            return true;
        }
        return false;
    });
    if (!foundFile) {
        console.log(`[NFC-STREAM] Track with title="${cleanedTitle}" (original: "${title}") not found in NFC directory`);
        console.log(`[NFC-STREAM] Available files:`, files);
        console.log(`[NFC-STREAM] Searched for (lowercase): "${titleLower}"`);
        res.status(404).json({
            error: 'Трек не найден в папке NFC',
            requestedTitle: cleanedTitle,
            originalTitle: title,
            availableFiles: files
        });
        return;
    }
    const absPath = path_1.default.resolve(nfcDir, foundFile);
    console.log(`[NFC-STREAM] Path resolution:`, {
        requestedTitle: title,
        foundFile,
        nfcDir,
        absPath,
        exists: fs_1.default.existsSync(absPath)
    });
    if (!fs_1.default.existsSync(absPath)) {
        console.error(`[NFC-STREAM] File not found: ${absPath}`);
        res.status(404).json({ error: 'Файл не найден' });
        return;
    }
    // Определяем content-type по расширению файла
    const ext = path_1.default.extname(absPath).toLowerCase();
    const contentType = mime_types_1.default.lookup(ext) || 'audio/mpeg';
    const stat = fs_1.default.statSync(absPath);
    // Обработка Range-запроса
    const rangeInfo = handleRangeRequest(req, res, absPath, contentType.toString());
    if (rangeInfo === null && res.headersSent) {
        // Range был невалидным, ответ уже отправлен
        return;
    }
    const logMessage = rangeInfo
        ? `[NFC-STREAM] Streaming range ${rangeInfo.start}-${rangeInfo.end} of ${absPath} (${stat.size} bytes, ${contentType})`
        : `[NFC-STREAM] Streaming full file: ${absPath} (${stat.size} bytes, ${contentType})`;
    console.log(logMessage);
    // Создание потока с учетом Range-запроса
    const streamOptions = rangeInfo
        ? { start: rangeInfo.start, end: rangeInfo.end }
        : {};
    const stream = fs_1.default.createReadStream(absPath, streamOptions);
    stream.on('error', (err) => {
        console.error(`[NFC-STREAM] Stream error for ${absPath}:`, err);
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
router.get('/:id/stream', (0, asyncHandler_1.asyncHandler)(async (req, res) => {
    const id = Number(req.params.id);
    console.log(`[GUEST-STREAM] Request for track id=${id}`);
    const result = await (0, db_1.default) `
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
    const absPath = path_1.default.resolve(appConfig_1.appConfig.storageRoot, relativePath);
    console.log(`[GUEST-STREAM] Path resolution:`, {
        dbPath: track.file_path,
        relativePath,
        storageRoot: appConfig_1.appConfig.storageRoot,
        absPath,
        exists: fs_1.default.existsSync(absPath)
    });
    if (!fs_1.default.existsSync(absPath)) {
        console.error(`[GUEST-STREAM] File not found: ${absPath}`);
        console.error(`[GUEST-STREAM] Storage root: ${appConfig_1.appConfig.storageRoot}`);
        console.error(`[GUEST-STREAM] Relative path: ${relativePath}`);
        res.status(404).json({ error: 'Файл не найден' });
        return;
    }
    const contentType = mime_types_1.default.lookup(track.file_format || path_1.default.extname(absPath)) || 'audio/mpeg';
    const stat = fs_1.default.statSync(absPath);
    // Обработка Range-запроса
    const rangeInfo = handleRangeRequest(req, res, absPath, contentType.toString());
    if (rangeInfo === null && res.headersSent) {
        // Range был невалидным, ответ уже отправлен
        return;
    }
    const logMessage = rangeInfo
        ? `[GUEST-STREAM] Streaming range ${rangeInfo.start}-${rangeInfo.end} of ${absPath} (${stat.size} bytes, ${contentType})`
        : `[GUEST-STREAM] Streaming full file: ${absPath} (${stat.size} bytes, ${contentType})`;
    console.log(logMessage);
    // Логируем заголовки запроса для диагностики
    console.log(`[GUEST-STREAM] Request headers:`, {
        range: req.headers.range,
        accept: req.headers.accept,
        'user-agent': req.headers['user-agent'],
        origin: req.headers.origin,
    });
    // Логируем заголовки ответа для диагностики
    console.log(`[GUEST-STREAM] Response headers:`, {
        'Content-Type': res.getHeader('Content-Type'),
        'Content-Length': res.getHeader('Content-Length'),
        'Accept-Ranges': res.getHeader('Accept-Ranges'),
        'Content-Range': res.getHeader('Content-Range'),
        status: res.statusCode,
    });
    // Создание потока с учетом Range-запроса
    const streamOptions = rangeInfo
        ? { start: rangeInfo.start, end: rangeInfo.end }
        : {};
    const stream = fs_1.default.createReadStream(absPath, streamOptions);
    stream.on('error', (err) => {
        console.error(`[GUEST-STREAM] Stream error for ${absPath}:`, err);
        if (!res.headersSent) {
            res.status(500).json({ error: 'Ошибка чтения файла' });
        }
    });
    stream.pipe(res);
}));
exports.default = router;
