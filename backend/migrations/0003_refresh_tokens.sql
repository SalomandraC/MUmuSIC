-- 0003: refresh-токены в базе. Сам токен не хранится, только sha256 от него.
-- Нужна для ротации (каждый refresh выдаёт новую пару, старый токен отзывается),
-- настоящего logout и обнаружения повторного использования украденного токена.

CREATE TABLE IF NOT EXISTS refresh_tokens (
  id          bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id     integer     NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  token_hash  text        NOT NULL UNIQUE,
  device      text,                                   -- User-Agent клиента, для списка сессий
  expires_at  timestamptz NOT NULL,
  revoked_at  timestamptz,
  replaced_by bigint      REFERENCES refresh_tokens (id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- Активные токены пользователя: logout со всех устройств и отзыв при повторном использовании
CREATE INDEX IF NOT EXISTS refresh_tokens_user_active_idx
  ON refresh_tokens (user_id) WHERE revoked_at IS NULL;

-- Для периодической чистки просроченных записей
CREATE INDEX IF NOT EXISTS refresh_tokens_expires_idx ON refresh_tokens (expires_at);
