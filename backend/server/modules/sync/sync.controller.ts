import { Request, Response } from 'express';
import { AuthenticatedRequest } from '../../middleware/authGuard';
import { SyncService } from './sync.service';
import { SyncData, UserPlaylist } from './sync.types';
import { z } from 'zod';

const playlistTrackSchema = z.object({
  trackId: z.number(),
  trackName: z.string().optional(),
  artistName: z.string().optional(),
  trackTimeMillis: z.number().optional(),
  artworkUrl100: z.string().nullable().optional(),
  previewUrl: z.string().nullable().optional(),
  position: z.number(),
});

const playlistSchema = z.object({
  id: z.number().optional(), // Опционально, так как может быть новым плейлистом
  name: z.string(),
  description: z.string().optional(),
  coverImageUri: z.string().nullable().optional(),
  tracks: z.array(playlistTrackSchema),
});

const syncDataSchema = z.object({
  playlists: z.array(playlistSchema),
});

export class SyncController {
  static async getData(req: AuthenticatedRequest, res: Response) {
    const userId = Number(req.user?.sub);
    if (!userId) {
      return res.status(401).json({ error: 'Необходима аутентификация' });
    }

    const data = await SyncService.getUserData(userId);
    res.json(data);
  }

  static async uploadData(req: AuthenticatedRequest, res: Response) {
    const userId = Number(req.user?.sub);
    if (!userId) {
      return res.status(401).json({ error: 'Необходима аутентификация' });
    }

    const parsed = syncDataSchema.parse(req.body);
    const now = new Date();
    const data: SyncData = {
      playlists: parsed.playlists.map(p => ({
        ...p,
        createdAt: now,
        updatedAt: now,
      })) as UserPlaylist[],
    };
    await SyncService.saveUserData(userId, data);

    res.json({ success: true, message: 'Данные успешно сохранены' });
  }

  static async uploadPlaylists(req: AuthenticatedRequest, res: Response) {
    const userId = Number(req.user?.sub);
    if (!userId) {
      return res.status(401).json({ error: 'Необходима аутентификация' });
    }

    try {
      console.log('[SyncController] uploadPlaylists called');
      console.log('  Body:', JSON.stringify(req.body, null, 2));
      
      const parsed = z.array(playlistSchema).parse(req.body);
      console.log('  Parsed playlists:', parsed.length);
      
      const now = new Date();
      const playlists: UserPlaylist[] = parsed.map(p => ({
        ...p,
        createdAt: now,
        updatedAt: now,
      }));
      await SyncService.savePlaylists(userId, playlists);

      res.json({ success: true, message: 'Плейлисты успешно сохранены' });
    } catch (error) {
      console.error('[SyncController] uploadPlaylists error:', error);
      if (error instanceof z.ZodError) {
        return res.status(400).json({ 
          error: 'Ошибка валидации плейлистов', 
          details: error.issues 
        });
      }
      throw error;
    }
  }
}

