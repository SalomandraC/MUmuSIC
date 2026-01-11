import { SyncRepository } from './sync.repository';
import { SyncData, UserPlaylist } from './sync.types';

export class SyncService {
  static async getUserData(userId: number): Promise<SyncData> {
    const playlists = await SyncRepository.getPlaylists(userId);
    return { playlists };
  }

  static async saveUserData(userId: number, data: SyncData): Promise<void> {
    await SyncRepository.savePlaylists(userId, data.playlists);
  }

  static async savePlaylists(userId: number, playlists: UserPlaylist[]): Promise<void> {
    await SyncRepository.savePlaylists(userId, playlists);
  }
}

