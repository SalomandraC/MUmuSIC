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
  id?: number;
  name: string;
  description?: string;
  coverImageUri?: string | null;
  tracks: PlaylistTrack[];
  createdAt?: Date; 
  updatedAt?: Date; 
}

export interface SyncData {
  playlists: UserPlaylist[];
}

