export interface TrackRecord {
  id: number;
  user_id: number;
  title: string;
  artist?: string;
  album?: string;
  duration?: number;
  file_path: string;
  file_format: string;
  file_size?: number;
  notes?: string;
  is_public: boolean;
  play_count: number;
  created_at: Date;
}

export interface CreateTrackRequest {
  title: string;
  artist?: string;
  album?: string;
  duration?: number;
  notes?: string;
  is_public?: boolean;
}

export interface TrackResponse {
  id: number;
  title: string;
  artist?: string;
  album?: string;
  duration?: number;
  file_path: string;
  file_url: string;
  file_format: string;
  file_size?: number;
  notes?: string;
  is_public: boolean;
  play_count: number;
  created_at: string;
}

