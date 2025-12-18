import sql from '../../config/db';
import { TrackRecord, CreateTrackRequest } from './tracks.types';

export class TracksRepository {
  static async create(
    userId: number,
    trackData: CreateTrackRequest,
    filePath: string,
    fileFormat: string,
    fileSize: number
  ): Promise<TrackRecord> {
    const result = await sql`
      INSERT INTO tracks (
        user_id, title, artist, album, duration, 
        file_path, file_format, file_size, notes, is_public
      )
      VALUES (
        ${userId},
        ${trackData.title},
        ${trackData.artist || null},
        ${trackData.album || null},
        ${trackData.duration || null},
        ${filePath},
        ${fileFormat},
        ${fileSize},
        ${trackData.notes || null},
        ${trackData.is_public ?? false}
      )
      RETURNING *
    `;

    return {
      id: result[0].id,
      user_id: result[0].user_id,
      title: result[0].title,
      artist: result[0].artist,
      album: result[0].album,
      duration: result[0].duration,
      file_path: result[0].file_path,
      file_format: result[0].file_format,
      file_size: result[0].file_size,
      notes: result[0].notes,
      is_public: result[0].is_public,
      play_count: result[0].play_count,
      created_at: result[0].created_at,
    };
  }

  static async findById(id: number): Promise<TrackRecord | null> {
    const result = await sql`
      SELECT * FROM tracks WHERE id = ${id} LIMIT 1
    `;

    if (result.length === 0) return null;

    return {
      id: result[0].id,
      user_id: result[0].user_id,
      title: result[0].title,
      artist: result[0].artist,
      album: result[0].album,
      duration: result[0].duration,
      file_path: result[0].file_path,
      file_format: result[0].file_format,
      file_size: result[0].file_size,
      notes: result[0].notes,
      is_public: result[0].is_public,
      play_count: result[0].play_count,
      created_at: result[0].created_at,
    };
  }

  static async findByUserId(userId: number): Promise<TrackRecord[]> {
    const result = await sql`
      SELECT * FROM tracks 
      WHERE user_id = ${userId}
      ORDER BY created_at DESC
    `;

    return result.map(row => ({
      id: row.id,
      user_id: row.user_id,
      title: row.title,
      artist: row.artist,
      album: row.album,
      duration: row.duration,
      file_path: row.file_path,
      file_format: row.file_format,
      file_size: row.file_size,
      notes: row.notes,
      is_public: row.is_public,
      play_count: row.play_count,
      created_at: row.created_at,
    }));
  }

  static async delete(id: number, userId: number): Promise<boolean> {
    const result = await sql`
      DELETE FROM tracks 
      WHERE id = ${id} AND user_id = ${userId}
      RETURNING id
    `;

    return result.length > 0;
  }

  static async findByTitleAndArtist(userId: number, title: string, artist?: string): Promise<TrackRecord | null> {
    let result;
    
    if (artist) {
      result = await sql`
        SELECT * FROM tracks 
        WHERE user_id = ${userId} AND title = ${title} AND artist = ${artist}
        LIMIT 1
      `;
    } else {
      result = await sql`
        SELECT * FROM tracks 
        WHERE user_id = ${userId} AND title = ${title} AND artist IS NULL
        LIMIT 1
      `;
    }

    if (result.length === 0) return null;

    return {
      id: result[0].id,
      user_id: result[0].user_id,
      title: result[0].title,
      artist: result[0].artist,
      album: result[0].album,
      duration: result[0].duration,
      file_path: result[0].file_path,
      file_format: result[0].file_format,
      file_size: result[0].file_size,
      notes: result[0].notes,
      is_public: result[0].is_public,
      play_count: result[0].play_count,
      created_at: result[0].created_at,
    };
  }
}
