import sql from '../../config/db';
import { UserPlaylist } from './sync.types';

export class SyncRepository {
  static async getPlaylists(userId: number): Promise<UserPlaylist[]> {
    // Получаем плейлисты типа 'sync' (синхронизированные из iTunes)
    const playlists = await sql`
      SELECT id, name, description, created_at
      FROM playlists
      WHERE user_id = ${userId} AND playlist_type = 'sync'
      ORDER BY created_at DESC
    `;

    const result: UserPlaylist[] = [];

    for (const playlist of playlists) {
      // Получаем треки из playlist_tracks и связанные данные из tracks
      const playlistTracks = await sql`
        SELECT pt.track_id, pt.position, t.title, t.artist, t.duration, t.notes
        FROM playlist_tracks pt
        LEFT JOIN tracks t ON pt.track_id = t.id
        WHERE pt.playlist_id = ${playlist.id}
        ORDER BY pt.position ASC
      `;

      result.push({
        id: playlist.id,
        name: playlist.name,
        description: playlist.description || undefined,
        coverImageUri: undefined, // В существующей БД нет поля для обложки
        tracks: playlistTracks.map((pt, idx) => {
          // Парсим iTunes метаданные из notes, если они есть
          let trackId: number | undefined;
          let trackName: string | undefined = pt.title || undefined;
          let artistName: string | undefined = pt.artist || undefined;
          let trackTimeMillis: number | undefined = pt.duration ? pt.duration * 1000 : undefined;
          let previewUrl: string | undefined;

          if (pt.notes) {
            // Формат notes: "Из iTunes (trackId: 123) | Preview: https://..."
            const trackIdMatch = pt.notes.match(/trackId:\s*(\d+)/);
            if (trackIdMatch) {
              trackId = parseInt(trackIdMatch[1]);
            }
            const previewMatch = pt.notes.match(/Preview:\s*(.+)/);
            if (previewMatch) {
              previewUrl = previewMatch[1].trim();
            }
          }

          return {
            trackId: trackId || (pt.track_id || 0),
            trackName,
            artistName,
            trackTimeMillis,
            artworkUrl100: null,
            previewUrl: previewUrl || null,
            position: pt.position || idx,
          };
        }),
        createdAt: playlist.created_at,
        updatedAt: playlist.created_at, // В существующей БД нет updated_at для playlists
      });
    }

    return result;
  }

  static async savePlaylists(userId: number, playlists: UserPlaylist[]): Promise<void> {
    await sql.begin(async sql => {
      // Удаляем существующие синхронизированные плейлисты
      const existingPlaylists = await sql`
        SELECT id FROM playlists WHERE user_id = ${userId} AND playlist_type = 'sync'
      `;

      for (const existing of existingPlaylists) {
        await sql`DELETE FROM playlist_tracks WHERE playlist_id = ${existing.id}`;
        await sql`DELETE FROM playlists WHERE id = ${existing.id}`;
      }

      // Создаем новые плейлисты
      for (const playlist of playlists) {
        const [saved] = await sql`
          INSERT INTO playlists (user_id, name, description, playlist_type, nfc_uid, is_public)
          VALUES (${userId}, ${playlist.name}, ${playlist.description || null}, 'sync', null, false)
          RETURNING id
        `;

        // Сохраняем треки в плейлист
        for (let i = 0; i < playlist.tracks.length; i++) {
          const track = playlist.tracks[i];
          
          // Ищем существующий трек по title и artist
          let trackRecordId: number | null = null;

          if (track.trackName && track.artistName) {
            // Ищем трек по названию и исполнителю (любой формат)
            const existingTrack = await sql`
              SELECT id FROM tracks 
              WHERE user_id = ${userId} 
              AND title = ${track.trackName}
              AND artist = ${track.artistName}
              LIMIT 1
            `;

            if (existingTrack.length > 0) {
              trackRecordId = existingTrack[0].id;
            }
          }

          // Если трек не найден, создаем новый трек в таблице tracks
          if (!trackRecordId && track.trackName) {
            const dummyPath = `playlists/${userId}/${Date.now()}_${(track.trackName || `Track${track.trackId}`).replace(/[^a-zA-Z0-9._ -]/g, '_')}.meta`;
            const notes = track.previewUrl 
              ? `Из плейлиста (trackId: ${track.trackId}) | Preview: ${track.previewUrl}`
              : `Из плейлиста (trackId: ${track.trackId})`;
            
            const [newTrack] = await sql`
              INSERT INTO tracks (
                user_id, title, artist, duration, 
                file_path, file_format, file_size, notes, is_public
              )
              VALUES (
                ${userId},
                ${track.trackName || `Track ${track.trackId}`},
                ${track.artistName || null},
                ${track.trackTimeMillis ? Math.floor(track.trackTimeMillis / 1000) : null},
                ${dummyPath},
                'metadata',
                0,
                ${notes},
                false
              )
              RETURNING id
            `;
            trackRecordId = newTrack.id;
            console.log(`[SyncRepository] Created track from playlist: ${track.trackName} by ${track.artistName}`);
          }

          // Добавляем трек в плейлист
          if (trackRecordId) {
            await sql`
              INSERT INTO playlist_tracks (playlist_id, track_id, position)
              VALUES (${saved.id}, ${trackRecordId}, ${i})
            `;
          }
        }
      }
    });
  }
}
