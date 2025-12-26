import sql from '../../config/db';
import { UserPlaylist } from './sync.types';

export class SyncRepository {
  static async getPlaylists(userId: number): Promise<UserPlaylist[]> {
    const playlists = await sql`
      SELECT id, name, description, created_at
      FROM playlists
      WHERE user_id = ${userId} AND playlist_type = 'sync'
      ORDER BY created_at DESC
    `;

    const result: UserPlaylist[] = [];

    for (const playlist of playlists) {
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
        coverImageUri: undefined, 
        tracks: playlistTracks.map((pt, idx) => {
          let trackId: number | undefined;
          let trackName: string | undefined = pt.title || undefined;
          let artistName: string | undefined = pt.artist || undefined;
          let trackTimeMillis: number | undefined = pt.duration ? pt.duration * 1000 : undefined;
          let previewUrl: string | undefined;

          if (pt.notes) {
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
        updatedAt: playlist.created_at, 
      });
    }

    return result;
  }

  static async savePlaylists(userId: number, playlists: UserPlaylist[]): Promise<void> {
    await sql.begin(async sql => {
      const existingPlaylists = await sql`
        SELECT id FROM playlists WHERE user_id = ${userId} AND playlist_type = 'sync'
      `;

      for (const existing of existingPlaylists) {
        await sql`DELETE FROM playlist_tracks WHERE playlist_id = ${existing.id}`;
        await sql`DELETE FROM playlists WHERE id = ${existing.id}`;
      }

      for (const playlist of playlists) {
        const [saved] = await sql`
          INSERT INTO playlists (user_id, name, description, playlist_type, nfc_uid, is_public)
          VALUES (${userId}, ${playlist.name}, ${playlist.description || null}, 'sync', null, false)
          RETURNING id
        `;

        // Отслеживаем уже вставленные треки в этом плейлисте, чтобы избежать дубликатов
        const insertedTracks = new Set<number>();

        for (let i = 0; i < playlist.tracks.length; i++) {
          const track = playlist.tracks[i];

          let trackRecordId: number | null = null;

          if (track.trackName && track.artistName) {
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
          }

          if (trackRecordId && !insertedTracks.has(trackRecordId)) {
            insertedTracks.add(trackRecordId);
            await sql`
              INSERT INTO playlist_tracks (playlist_id, track_id, position)
              VALUES (${saved.id}, ${trackRecordId}, ${i})
              ON CONFLICT (playlist_id, track_id) 
              DO UPDATE SET position = EXCLUDED.position
            `;
          }
        }
      }
    });
  }
}
