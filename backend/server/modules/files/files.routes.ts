import { Router, Request, Response, NextFunction } from 'express';
import fs from 'fs';
import path from 'path';
import multer from 'multer';
import mime from 'mime-types';
import { appConfig } from '../../config/appConfig';

const router = Router();

const upload = multer({ dest: path.join(appConfig.storageRoot, '.tmp') });

function ensureDirectoryExists(directoryPath: string): void {
	if (!fs.existsSync(directoryPath)) {
		fs.mkdirSync(directoryPath, { recursive: true });
	}
}

function sanitizeFileName(fileName: string): string {
	const base = path.basename(fileName).replace(/[^a-zA-Z0-9._ -]/g, '_');
	return base.trim().replace(/\s+/g, ' ');
}

function buildSafeAccountPath(accountId: string): string {
	const safeAccountId = accountId.replace(/[^a-zA-Z0-9_-]/g, '_');
	const dir = path.join(appConfig.storageRoot, safeAccountId);
	return dir;
}

function resolveSafeFilePath(accountId: string, fileName: string): string {
	const accountDir = buildSafeAccountPath(accountId);
	const safeName = sanitizeFileName(fileName);
	const resolved = path.join(accountDir, safeName);
	const normalized = path.normalize(resolved);
	// Prevent path traversal outside storageRoot
	if (!normalized.startsWith(path.normalize(appConfig.storageRoot + path.sep))) {
		throw Object.assign(new Error('Invalid path'), { statusCode: 400 });
	}
	return normalized;
}

// GET /:accountId/:fileName - serve track file
router.get('/:accountId/:fileName', (req: Request, res: Response, next: NextFunction) => {
	try {
		const { accountId, fileName } = req.params;
		const filePath = resolveSafeFilePath(accountId, fileName);
		if (!fs.existsSync(filePath) || !fs.statSync(filePath).isFile()) {
			res.status(404).json({ error: 'Файл не найден' });
			return;
		}
		const contentType = mime.lookup(filePath) || 'application/octet-stream';
		res.setHeader('Content-Type', contentType as string);
		res.setHeader('Accept-Ranges', 'bytes');
		res.sendFile(filePath);
	} catch (err) {
		next(err);
	}
});

// POST /files/:accountId - upload single track (field: file, optional body.name)
router.post('/files/:accountId', upload.single('file'), async (req: Request, res: Response, next: NextFunction) => {
	try {
		const { accountId } = req.params;
		const uploaded = req.file;
		const desiredNameFromBody = (req.body?.name as string | undefined) || uploaded?.originalname;

		if (!uploaded || !desiredNameFromBody) {
			res.status(400).json({ error: 'Необходимо приложить файл (file) и имя файла' });
			return;
		}

		const ext = path.extname(desiredNameFromBody).toLowerCase();
		const allowed = new Set(['.mp3', '.flac', '.wav', '.m4a', '.ogg']);
		if (!allowed.has(ext)) {
			res.status(400).json({ error: 'Недопустимое расширение файла' });
			return;
		}

		const accountDir = buildSafeAccountPath(accountId);
		ensureDirectoryExists(path.join(appConfig.storageRoot));
		ensureDirectoryExists(accountDir);

		const finalName = sanitizeFileName(desiredNameFromBody);
		const finalPath = resolveSafeFilePath(accountId, finalName);

		// If file exists, overwrite
		await fs.promises.rename(uploaded.path, finalPath).catch(async (e) => {
			// In case of cross-device rename or other errors, fallback to copy+unlink
			if (e) {
				await fs.promises.copyFile(uploaded.path, finalPath);
				await fs.promises.unlink(uploaded.path);
			}
		});

		const stat = await fs.promises.stat(finalPath);
		const urlPath = `/${accountId}/${finalName}`;

		res.status(201).json({
			path: urlPath,
			size: stat.size,
			contentType: mime.lookup(finalPath) || 'application/octet-stream',
		});
	} catch (err) {
		next(err);
	}
});

// GET /files/:accountId - list files for account
router.get('/files/:accountId', async (req: Request, res: Response, next: NextFunction) => {
	try {
		const { accountId } = req.params;
		const dir = buildSafeAccountPath(accountId);
		if (!fs.existsSync(dir) || !fs.statSync(dir).isDirectory()) {
			res.json({ files: [] });
			return;
		}
		const files = await fs.promises.readdir(dir);
		res.json({ files });
	} catch (err) {
		next(err);
	}
});

// DELETE /files/:accountId/:fileName - delete a specific file
router.delete('/files/:accountId/:fileName', async (req: Request, res: Response, next: NextFunction) => {
	try {
		const { accountId, fileName } = req.params;
		const filePath = resolveSafeFilePath(accountId, fileName);
		if (!fs.existsSync(filePath)) {
			res.status(404).json({ error: 'Файл не найден' });
			return;
		}
		await fs.promises.unlink(filePath);
		res.status(204).send();
	} catch (err) {
		next(err);
	}
});

export default router;


