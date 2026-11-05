-- 0002: индексы под запросы, которые реально выполняет backend.
-- Уникальные индексы по lower(email)/lower(username) повторяют проверку
-- в auth.service на уровне базы. Если в существующей базе уже есть
-- дубликаты без учёта регистра, миграция упадёт целиком (она в транзакции)
-- и их нужно будет сначала разобрать.

CREATE UNIQUE INDEX IF NOT EXISTS users_email_lower_key    ON users (lower(email));
CREATE UNIQUE INDEX IF NOT EXISTS users_username_lower_key ON users (lower(username));

-- tracks.repository.findByUserId, sync: поиск трека по названию и артисту
CREATE INDEX IF NOT EXISTS tracks_user_created_idx ON tracks (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS tracks_user_title_artist_idx ON tracks (user_id, title, artist);

-- sync.repository: плейлисты пользователя нужного типа
CREATE INDEX IF NOT EXISTS playlists_user_type_idx ON playlists (user_id, playlist_type, created_at DESC);

-- удаление трека каскадом и выборка «в каких плейлистах трек»
CREATE INDEX IF NOT EXISTS playlist_tracks_track_idx ON playlist_tracks (track_id);

-- top-chart.repository: WHERE is_active ORDER BY play_count DESC LIMIT 10
CREATE INDEX IF NOT EXISTS guest_tracks_active_popular_idx
  ON guest_tracks (play_count DESC) WHERE is_active;
