export interface TopChartRecord {
  id: number;
  title: string;
  artist: string;
  file_path: string;
  file_format: string;
  duration: number;
  file_size: number;
  is_active: boolean;
  play_count: number;
  created_at: Date;
}