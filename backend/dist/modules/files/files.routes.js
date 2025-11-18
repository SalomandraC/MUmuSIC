"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const multer_1 = __importDefault(require("multer"));
const mime_types_1 = __importDefault(require("mime-types"));
const appConfig_1 = require("../../config/appConfig");
const router = (0, express_1.Router)();
const upload = (0, multer_1.default)({ dest: path_1.default.join(appConfig_1.appConfig.storageRoot, '.tmp') });
function ensureDirectoryExists(directoryPath) {
    if (!fs_1.default.existsSync(directoryPath)) {
        fs_1.default.mkdirSync(directoryPath, { recursive: true });
    }
}
function sanitizeFileName(fileName) {
    const base = path_1.default.basename(fileName).replace(/[^a-zA-Z0-9._ -]/g, '_');
    return base.trim().replace(/\s+/g, ' ');
}
function buildSafeAccountPath(accountId) {
    const safeAccountId = accountId.replace(/[^a-zA-Z0-9_-]/g, '_');
    const dir = path_1.default.join(appConfig_1.appConfig.storageRoot, safeAccountId);
    return dir;
}
function resolveSafeFilePath(accountId, fileName) {
    const accountDir = buildSafeAccountPath(accountId);
    const safeName = sanitizeFileName(fileName);
    const resolved = path_1.default.join(accountDir, safeName);
    const normalized = path_1.default.normalize(resolved);
    // Prevent path traversal outside storageRoot
    if (!normalized.startsWith(path_1.default.normalize(appConfig_1.appConfig.storageRoot + path_1.default.sep))) {
        throw Object.assign(new Error('Invalid path'), { statusCode: 400 });
    }
    return normalized;
}
// GET /:accountId/:fileName - serve track file
router.get('/:accountId/:fileName', (req, res, next) => {
    try {
        const { accountId, fileName } = req.params;
        const filePath = resolveSafeFilePath(accountId, fileName);
        if (!fs_1.default.existsSync(filePath) || !fs_1.default.statSync(filePath).isFile()) {
            res.status(404).json({ error: 'Файл не найден' });
            return;
        }
        const contentType = mime_types_1.default.lookup(filePath) || 'application/octet-stream';
        res.setHeader('Content-Type', contentType);
        res.setHeader('Accept-Ranges', 'bytes');
        res.sendFile(filePath);
    }
    catch (err) {
        next(err);
    }
});
// POST /files/:accountId - upload single track (field: file, optional body.name)
router.post('/files/:accountId', upload.single('file'), async (req, res, next) => {
    try {
        const { accountId } = req.params;
        const uploaded = req.file;
        const desiredNameFromBody = req.body?.name || uploaded?.originalname;
        if (!uploaded || !desiredNameFromBody) {
            res.status(400).json({ error: 'Необходимо приложить файл (file) и имя файла' });
            return;
        }
        const ext = path_1.default.extname(desiredNameFromBody).toLowerCase();
        const allowed = new Set(['.mp3', '.wav']);
        if (!allowed.has(ext)) {
            res.status(400).json({ error: 'Недопустимое расширение файла' });
            return;
        }
        const accountDir = buildSafeAccountPath(accountId);
        ensureDirectoryExists(path_1.default.join(appConfig_1.appConfig.storageRoot));
        ensureDirectoryExists(accountDir);
        const finalName = sanitizeFileName(desiredNameFromBody);
        const finalPath = resolveSafeFilePath(accountId, finalName);
        await fs_1.default.promises.rename(uploaded.path, finalPath).catch(async (e) => {
            if (e) {
                await fs_1.default.promises.copyFile(uploaded.path, finalPath);
                await fs_1.default.promises.unlink(uploaded.path);
            }
        });
        const stat = await fs_1.default.promises.stat(finalPath);
        const urlPath = `/${accountId}/${finalName}`;
        res.status(201).json({
            path: urlPath,
            size: stat.size,
            contentType: mime_types_1.default.lookup(finalPath) || 'application/octet-stream',
        });
    }
    catch (err) {
        next(err);
    }
});
// GET /files/:accountId - list files for account
router.get('/files/:accountId', async (req, res, next) => {
    try {
        const { accountId } = req.params;
        const dir = buildSafeAccountPath(accountId);
        if (!fs_1.default.existsSync(dir) || !fs_1.default.statSync(dir).isDirectory()) {
            res.json({ files: [] });
            return;
        }
        const files = await fs_1.default.promises.readdir(dir);
        res.json({ files });
    }
    catch (err) {
        next(err);
    }
});
// DELETE /files/:accountId/:fileName - delete a specific file
router.delete('/files/:accountId/:fileName', async (req, res, next) => {
    try {
        const { accountId, fileName } = req.params;
        const filePath = resolveSafeFilePath(accountId, fileName);
        if (!fs_1.default.existsSync(filePath)) {
            res.status(404).json({ error: 'Файл не найден' });
            return;
        }
        await fs_1.default.promises.unlink(filePath);
        res.status(204).send();
    }
    catch (err) {
        next(err);
    }
});
exports.default = router;
