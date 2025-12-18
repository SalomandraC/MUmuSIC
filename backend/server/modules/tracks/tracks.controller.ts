import { Request, Response } from 'express';
import { AuthenticatedRequest } from '../../middleware/authGuard';
import { TracksService } from './tracks.service';
import { z } from 'zod';
import fs from 'fs';
import path from 'path';
import multer from 'multer';
import { appConfig } from '../../config/appConfig';

const upload = multer({ 
  dest: path.join(appConfig.storageRoot, '.tmp'),
  limits: { fileSize: 100 * 1024 * 1024 }
});

const createTrackSchema = z.object({
  title: z.string().min(1),
  artist: z.string().optional(),
  album: z.string().optional(),
  duration: z.number().optional(),
  notes: z.string().optional(),
  is_public: z.boolean().optional(),
});

export class TracksController {
  static upload = upload.single('file');

  static async create(req: AuthenticatedRequest, res: Response) {
    console.log(`[TracksController] create called`);
    console.log(`  Method: ${req.method}`);
    console.log(`  Path: ${req.path}`);
    console.log(`  User:`, req.user);
    console.log(`  File:`, req.file ? { name: req.file.originalname, size: req.file.size } : 'null');
    console.log(`  Body:`, req.body);
    
    const userId = Number(req.user?.sub);
    if (!userId) {
      console.log(`[TracksController] ❌ No userId`);
      return res.status(401).json({ error: 'Необходима аутентификация' });
    }

    const file = req.file;
    if (!file) {
      console.log(`[TracksController] ❌ No file uploaded`);
      return res.status(400).json({ error: 'Файл не загружен' });
    }

    const ext = path.extname(file.originalname).toLowerCase();
    const allowed = new Set(['.mp3', '.wav', '.m4a', '.flac']);
    if (!allowed.has(ext)) {
      await fs.promises.unlink(file.path).catch(() => {});
      return res.status(400).json({ error: 'Недопустимое расширение файла. Разрешены: mp3, wav, m4a, flac' });
    }

    try {
      const trackData = createTrackSchema.parse({
        title: req.body.title || path.basename(file.originalname, ext),
        artist: req.body.artist,
        album: req.body.album,
        duration: req.body.duration ? Number(req.body.duration) : undefined,
        notes: req.body.notes,
        is_public: req.body.is_public === 'true' || req.body.is_public === true,
      });

      // Сохраняем в users/{userId}/
      // Создаем директорию автоматически (recursive создаст все промежуточные папки)
      const accountDir = path.join(appConfig.storageRoot, 'users', userId.toString());
      if (!fs.existsSync(accountDir)) {
        fs.mkdirSync(accountDir, { recursive: true });
      }

      const sanitizedFileName = file.originalname.replace(/[^a-zA-Z0-9._ -]/g, '_');
      const finalPath = path.join(accountDir, sanitizedFileName);

      await fs.promises.rename(file.path, finalPath).catch(async (e) => {
        if (e) {
          await fs.promises.copyFile(file.path, finalPath);
          await fs.promises.unlink(file.path);
        }
      });

      const stat = await fs.promises.stat(finalPath);
      // Сохраняем относительный путь: users/{userId}/{filename}
      const relativePath = path.join('users', userId.toString(), sanitizedFileName);

      const track = await TracksService.createTrack(
        userId,
        trackData,
        relativePath,
        ext.substring(1),
        stat.size
      );

      res.status(201).json(track);
    } catch (error) {
      await fs.promises.unlink(file.path).catch(() => {});
      if (error instanceof z.ZodError) {
        return res.status(400).json({ error: 'Неверные данные', details: error.issues });
      }
      throw error;
    }
  }

  static async getUserTracks(req: AuthenticatedRequest, res: Response) {
    const userId = Number(req.user?.sub);
    if (!userId) {
      return res.status(401).json({ error: 'Необходима аутентификация' });
    }

    const tracks = await TracksService.getUserTracks(userId);
    res.json({ tracks });
  }

  static async getTrack(req: AuthenticatedRequest, res: Response) {
    const id = Number(req.params.id);
    const userId = req.user ? Number(req.user.sub) : undefined;

    const track = await TracksService.getTrackById(id, userId);
    if (!track) {
      return res.status(404).json({ error: 'Трек не найден' });
    }

    res.json(track);
  }

  static async deleteTrack(req: AuthenticatedRequest, res: Response) {
    const userId = Number(req.user?.sub);
    if (!userId) {
      return res.status(401).json({ error: 'Необходима аутентификация' });
    }

    const id = Number(req.params.id);
    const deleted = await TracksService.deleteTrack(id, userId);

    if (!deleted) {
      return res.status(404).json({ error: 'Трек не найден' });
    }

    res.status(204).send();
  }
}

