export interface PlaylistTrack {
  trackId: number;
  trackName?: string;
  artistName?: string;
  trackTimeMillis?: number;
  artworkUrl100?: string | null;
  previewUrl?: string | null;
  position: number;
}

export interface UserPlaylist {
  id?: number; // Опционально при загрузке, генерируется на сервере
  name: string;
  description?: string;
  coverImageUri?: string | null;
  tracks: PlaylistTrack[];
  createdAt?: Date; // Опционально при загрузке, генерируется на сервере
  updatedAt?: Date; // Опционально при загрузке, генерируется на сервере
}

export interface SyncData {
  playlists: UserPlaylist[];
}

