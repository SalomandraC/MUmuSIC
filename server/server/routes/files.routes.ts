import { Router, Request, Response, NextFunction } from 'express';
import fs from 'fs';
import path from 'path';
import multer from 'multer';
import mime from 'mime-types';

const router = Router();

interface UploadedFile {
	fieldname: string;
	originalname: string;
	encoding: string;
	mimetype: string;
	size: number;
	destination: string;
	filename: string;
	path: string;
	buffer?: Buffer;
}

const storageRoot = process.env.STORAGE_ROOT
	? path.resolve(process.env.STORAGE_ROOT)
	: path.resolve(process.cwd(), 'storage');

const upload = multer({ dest: path.join(storageRoot, '.tmp') });

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
	const dir = path.join(storageRoot, safeAccountId);
	return dir;
}

function resolveSafeFilePath(accountId: string, fileName: string): string {
	const accountDir = buildSafeAccountPath(accountId);
	const safeName = sanitizeFileName(fileName);
	const resolved = path.join(accountDir, safeName);
	const normalized = path.normalize(resolved);
	if (!normalized.startsWith(path.normalize(storageRoot + path.sep))) {
		throw Object.assign(new Error('Invalid path'), { statusCode: 400 });
	}
	return normalized;
}

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

router.post('/files/:accountId', upload.single('file'), async (req: Request & { file?: UploadedFile }, res: Response, next: NextFunction) => {
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
		ensureDirectoryExists(storageRoot);
		ensureDirectoryExists(accountDir);

		const finalName = sanitizeFileName(desiredNameFromBody);
		const finalPath = resolveSafeFilePath(accountId, finalName);

		await fs.promises.rename(uploaded.path, finalPath).catch(async (e) => {
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