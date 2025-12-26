import { TracksRepository } from './tracks.repository';
import { CreateTrackRequest, TrackResponse } from './tracks.types';
import { appConfig } from '../../config/appConfig';
import fs from 'fs';
import path from 'path';

export class TracksService {
  static async createTrack(
    userId: number,
    trackData: CreateTrackRequest,
    filePath: string,
    fileFormat: string,
    fileSize: number
  ): Promise<TrackResponse> {
    const track = await TracksRepository.create(
      userId,
      trackData,
      filePath,
      fileFormat,
      fileSize
    );

    return this.mapToResponse(track);
  }

  static async getUserTracks(userId: number): Promise<TrackResponse[]> {
    const tracks = await TracksRepository.findByUserId(userId);
    return tracks.map(track => this.mapToResponse(track));
  }

  static async getTrackById(id: number, userId?: number): Promise<TrackResponse | null> {
    const track = await TracksRepository.findById(id);
    
    if (!track) return null;
    
    // Не возвращаем метаданные из плейлистов
    if (track.file_format === 'metadata') {
      return null;
    }
    
    if (userId && track.user_id !== userId && !track.is_public) {
      return null;
    }

    return this.mapToResponse(track);
  }

  static async deleteTrack(id: number, userId: number): Promise<boolean> {
    const track = await TracksRepository.findById(id);
    if (!track || track.user_id !== userId) {
      return false;
    }

    const deleted = await TracksRepository.delete(id, userId);
    if (deleted && track.file_path) {
      const filePath = path.join(appConfig.storageRoot, track.file_path);
      try {
        await fs.promises.unlink(filePath);
      } catch (error) {
      }
    }

    return deleted;
  }

  private static mapToResponse(track: any): TrackResponse {
    const normalizedPath = track.file_path.replace(/\\/g, '/');
    const fileUrl = `/storage/${normalizedPath}`;
    
    return {
      id: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: track.duration,
      file_path: track.file_path,
      file_url: fileUrl,
      file_format: track.file_format,
      file_size: track.file_size,
      notes: track.notes,
      is_public: track.is_public,
      created_at: track.created_at.toISOString(),
    };
  }
}

