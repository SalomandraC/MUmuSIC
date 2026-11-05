# Доработка серверной части MusicPlayer

Инструкция о том, как довести `backend/` до сервера, который выдерживает нагрузку и масштабируется горизонтально. В ней стек технологий, целевая архитектура и план работ на 5 дней.

Документ опирается на разбор текущего кода (схема БД, проблемы, целевая архитектура) и на уже добавленные SQL-миграции (`backend/migrations`, команда `npm run migrate`). Новые изменения схемы оформляются как миграции `0003_…`, `0004_…` и далее.

---

## 1. Что не так сейчас (коротко)

| Проблема | Почему мешает |
|---|---|
| Файлы лежат на локальном диске (`server/storage`), backend читает их по пути `../server/storage` | Вторая копия сервера на другой машине не увидит файлы, поэтому балансировщик ставить бессмысленно |
| `/storage` раздаётся через `express.static` без авторизации, `GET /tracks/:id` работает без `authGuard` | Можно скачать чужие файлы и прочитать чужие приватные треки |
| Приложение ходит на `/guest-tracks/...`, а в исходниках backend этих маршрутов нет (они остались только в старом `dist`) | После `npm run build` гостевой режим, топ-чарт и NFC отвалятся |
| Два сервера: `server/` (старый, без авторизации) и `backend/` | Непонятно, какой из них главный, а у старого открыты `POST`/`DELETE /files/:accountId` |
| `logout` ничего не делает, refresh-токен нельзя отозвать, в коде есть дефолтные JWT-секреты | Украденный токен живёт 7 дней, без `.env` токены можно подделать |
| Синхронизация удаляет все плейлисты и вставляет заново (по 2–3 запроса на трек), чтение плейлистов N+1 | Медленно, id меняются, два устройства затирают друг друга |
| iTunes-треки хранятся как фиктивные строки `tracks` с `file_format='metadata'`, данные лежат в `notes` | Две разные сущности в одной таблице, разбор регуляркой |
| `play_count` нигде не растёт, стрим всегда отдаёт `audio/mpeg` | Топ-чарт ненастоящий, m4a приходит с неверным типом |

---

## 2. Стек технологий

Основу оставляем: Node.js + TypeScript + Express + `postgres` (postgres.js) + zod. Переписывать сервер на другой фреймворк ради нагрузки не нужно. Узкое место здесь в архитектуре, а не в Express.

| Задача | Технология | Почему именно она |
|---|---|---|
| HTTP API | **Express 4** (как сейчас), Node.js 20 LTS | Код уже на нём, модули `auth/sync/tracks/top-chart` переносятся без переписывания |
| Валидация | **zod** (уже есть) | Одна схема на запрос, ошибки уже обрабатываются в `errorHandler` |
| БД | **PostgreSQL 16** (локально в Docker, в проде можно оставить Supabase) | Уже используется, есть реплики, партиционирование и `pgvector` для рекомендаций |
| Миграции | **`npm run migrate`** (уже есть, `server/db/migrate.ts`) | Схема в репозитории, транзакции, advisory lock от двойного запуска |
| Пул соединений | **PgBouncer** (transaction mode) | Каждая копия API держит пул `max: 10`, а 10 копий уже дают 100 соединений к Postgres |
| Файлы | **MinIO** (S3-совместимое хранилище), клиент `@aws-sdk/client-s3` + `@aws-sdk/s3-request-presigner` | Файлы не привязаны к машине, аудио отдаётся по подписанной ссылке мимо Node.js, Range-запросы MinIO обрабатывает сам |
| Кэш, rate limit | **Redis 7**, `ioredis`, `rate-limit-redis` + `express-rate-limit` | Общие счётчики и кэш для всех копий API (в памяти процесса они бы разъехались) |
| Фоновые задачи | **BullMQ** (очереди поверх Redis) | Распознавание тегов, анализ треков и пересчёт чартов не блокируют ответ API |
| Теги из файлов | **`music-metadata`** (npm) | Читает ID3/MP4/FLAC-теги: исполнитель, название, альбом, обложка, длительность |
| Распознавание по звуку | **Chromaprint (`fpcalc`) + AcoustID API**, далее MusicBrainz | Определяет трек по аудиоотпечатку, даже если тегов нет и файл называется `track01.mp3` |
| Балансировщик | **nginx** | TLS, `least_conn` между копиями API, health checks, лимиты, отдача больших тел |
| Логи | **pino** + `pino-http` с `request-id` | Структурированные JSON-логи, по одному id видно запрос через nginx → API → воркер (вместо `console.log` на каждый запрос) |
| Метрики (опционально) | **prom-client** → Prometheus + Grafana | Графики RPS, p95, ошибок — хорошо смотрятся на защите |
| Окружение | **Docker + Docker Compose** | Весь стенд поднимается одной командой, `--scale api=3` показывает горизонтальное масштабирование |
| Нагрузочный тест | **k6** | Скрипт на JS, сравнение 1 копии и 3 копий API в цифрах |
| Тесты | **jest** (уже есть) + **supertest** | Интеграционные тесты маршрутов поверх тестовой базы |

Чего **не** нужно: Kubernetes, микросервисы, Kafka и переписывание на NestJS или Go. Для диплома и такого объёма это лишняя сложность без выигрыша. Один модульный API (как сейчас `backend/server/modules`) и отдельный процесс-воркер решают задачу.

---

## 3. Целевая архитектура

```
        Мобильное приложение            Умные часы
                 │                          │
                 └────────────┬─────────────┘
                              ▼
                ┌──────────────────────────────┐
                │  nginx: балансировщик         │   TLS, least_conn, rate limit,
                │                               │   health check /health
                └──────┬──────────┬────────┬────┘
                       ▼          ▼        ▼
                    API #1     API #2    API #N     ← без состояния, JWT
                       │          │        │
          ┌────────────┼──────────┴────────┼──────────────┐
          ▼            ▼                   ▼              │
   ┌────────────┐ ┌──────────┐   ┌──────────────────┐     │
   │ MinIO (S3) │ │  Redis   │   │ PgBouncer        │     │
   │ аудио,     │ │ кэш,     │   │   → PostgreSQL   │     │
   │ обложки    │ │ лимиты,  │   │     primary      │     │
   └─────▲──────┘ │ очереди  │   │   (+ реплика)    │     │
         │        └────┬─────┘   └────────▲─────────┘     │
         │             ▼                  │               │
         │      ┌────────────────────────────────┐        │
         └──────│ Воркеры (BullMQ)               │────────┘
                │ теги, отпечатки, анализ, чарты │
                └────────────────────────────────┘

   Аудио: приложение получает от API подписанную ссылку и качает файл
   напрямую из MinIO (Range-запросы, без нагрузки на Node.js).
```

Главное правило: **API не хранит ничего ни в памяти, ни на диске**. Сессии лежат в JWT и таблице `refresh_tokens`, файлы в MinIO, кэш и лимиты в Redis. Тогда любую копию API можно убить или добавить, и пользователь этого не заметит.

### Структура backend после доработки

```
backend/
├─ migrations/                 # 0001, 0002 уже есть; дальше 0003…
├─ server/
│  ├─ index.ts                 # только сборка app + graceful shutdown
│  ├─ app.ts                   # express app (удобно для supertest)
│  ├─ config/                  # appConfig (zod), db, redis, s3
│  ├─ middleware/              # authGuard, errorHandler, rateLimit, requestId
│  ├─ modules/
│  │  ├─ auth/                 # + refresh_tokens, logout, ротация
│  │  ├─ tracks/               # каталог, загрузка через presigned URL
│  │  ├─ media/                # выдача подписанных ссылок на стрим
│  │  ├─ library/              # библиотека и избранное пользователя
│  │  ├─ playlists/            # CRUD + инкрементальный sync
│  │  ├─ charts/               # топ-чарт из play_events, кэш в Redis
│  │  ├─ nfc/                  # метка → плейлист/трек по uid
│  │  └─ events/               # POST /v2/events (прослушивания, пульс)
│  ├─ jobs/                    # описание очередей BullMQ
│  └─ worker.ts                # отдельный процесс: обработка очередей
├─ scripts/
│  └─ migrate-storage-to-s3.ts # перенос server/storage → MinIO
├─ load/
│  └─ smoke.k6.js              # нагрузочный сценарий
├─ docker-compose.yml
└─ nginx/nginx.conf
```

---

## 4. Изменения схемы БД (миграции 0003+)

Идея: разделить «что это за трек» (каталог), «где лежит файл» (MinIO) и «у кого он в библиотеке». Пример того, зачем это нужно: `Operation Pyrite` сейчас лежит в storage четыре раза, у пользователей 3, 9, 10 и 11.

| Миграция | Что добавляет |
|---|---|
| `0003_refresh_tokens` | `refresh_tokens (id, user_id, token_hash, device, expires_at, revoked_at, created_at)` |
| `0004_media_files` | `media_files (id, track_id, storage_key, format, mime, bitrate, size, sha256 UNIQUE, created_at)` |
| `0005_catalog` | `artists`, `albums`; в `tracks` поля `artist_id`, `album_id`, `duration_ms`, `fingerprint`, `visibility` (`private`/`public`/`featured`), `processing_status` |
| `0006_library` | `user_library (user_id, track_id, added_at, is_favorite, PRIMARY KEY (user_id, track_id))` |
| `0007_external_refs` | `external_refs (track_id, provider, external_id, preview_url, artwork_url)`, перенос данных из `notes` |
| `0008_playlists_sync` | в `playlists`: `updated_at`, `version`, `kind` (`manual`/`auto`/`nfc`), `rules jsonb`, `deleted_at`; `ON DELETE CASCADE` в `playlist_tracks` |
| `0009_nfc_tags` | `nfc_tags (uid PRIMARY KEY, owner_id, playlist_id, track_id, created_at)` |
| `0010_play_events` | `play_events (user_id, track_id, started_at, listened_ms, skipped, context, device)` с партициями по месяцам, индекс `(user_id, started_at)` |
| `0011_guest_to_featured` | перенос `guest_tracks` в `tracks` с `visibility='featured'` (саму таблицу удалить позже, когда v1 никто не вызывает) |

Пример одной миграции:

```sql
-- 0003_refresh_tokens.sql
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id     int NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  text NOT NULL UNIQUE,          -- sha256 от токена, сам токен не храним
  device      text,
  expires_at  timestamptz NOT NULL,
  revoked_at  timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS refresh_tokens_user_idx ON refresh_tokens (user_id) WHERE revoked_at IS NULL;
```

Правила: применённые миграции не редактируются. Старые колонки (`tracks.user_id`, `file_path`, `notes`) удаляются отдельной миграцией в самом конце, когда приложение полностью переехало на v2.

---

## 5. API v2 (новые и изменённые маршруты)

v1 продолжает работать, пока приложение не переедет на v2. Новые маршруты живут под префиксом `/v2`.

| Метод и путь | Что делает |
|---|---|
| `POST /v2/auth/login`, `/register` | Как сейчас, но refresh-токен записывается в `refresh_tokens` |
| `POST /v2/auth/refresh` | Ротация: старый refresh помечается отозванным, выдаётся новая пара |
| `POST /v2/auth/logout` | Отзывает refresh-токен текущего устройства (`?all=true` — все устройства) |
| `POST /v2/tracks/uploads` | Возвращает `{ uploadUrl, trackId }`: подписанный PUT в MinIO на 15 минут |
| `POST /v2/tracks/:id/complete` | Клиент сообщил, что файл загружен; API ставит задачу `track.process` в очередь |
| `GET /v2/tracks/:id/stream` | Проверяет права и отвечает `302` на подписанный GET-URL MinIO (живёт 1 час) |
| `GET /v2/library?cursor=` | Библиотека пользователя, курсорная пагинация |
| `GET /v2/featured` | Замена `/guest-tracks`: треки с `visibility='featured'`, кэш в Redis |
| `GET /v2/charts/top?period=week` | Топ из `play_events`, кэш в Redis на 5 минут |
| `GET /v2/playlists/changes?since=<version>` | Инкрементальный sync: только изменённые и удалённые плейлисты |
| `PUT /v2/playlists/:id` | Обновление с проверкой `version` (при конфликте `409`) |
| `GET /v2/nfc/:uid` | Что привязано к метке: плейлист или трек и ссылка на стрим |
| `POST /v2/nfc/:uid` | Привязать метку к плейлисту или треку |
| `POST /v2/events` | Пачка событий (прослушивание, пропуск, пульс с часов): кладётся в очередь, ответ `202` сразу |
| `GET /health`, `GET /ready` | `health` — процесс жив; `ready` — есть связь с Postgres, Redis, MinIO (для nginx и Docker) |

---

## 6. Ключевые решения с примерами кода

### 6.1. Стрим через подписанную ссылку

```ts
// modules/media/media.service.ts
import { GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { s3, bucket } from '../../config/s3';

export async function getStreamUrl(storageKey: string, mime: string) {
  return getSignedUrl(
    s3,
    new GetObjectCommand({ Bucket: bucket, Key: storageKey, ResponseContentType: mime }),
    { expiresIn: 3600 },
  );
}

// tracks.controller: проверили права → res.redirect(302, await getStreamUrl(...))
```

`just_audio` и другие плееры корректно следуют редиректу и сами шлют Range-запросы в MinIO. Ключ файла строится как `audio/<sha256>.<ext>`, поэтому проблема кириллицы в именах исчезает, а одинаковые файлы хранятся один раз.

### 6.2. Rate limit, общий для всех копий

```ts
import rateLimit from 'express-rate-limit';
import { RedisStore } from 'rate-limit-redis';
import { redis } from '../config/redis';

export const authLimiter = rateLimit({
  windowMs: 60_000,
  limit: 10,                       // 10 попыток логина в минуту с одного IP
  standardHeaders: 'draft-7',
  store: new RedisStore({ sendCommand: (...args: string[]) => redis.call(...args) as any }),
});
```

### 6.3. Корректное выключение копии API

```ts
const server = app.listen(port);
process.on('SIGTERM', () => {
  server.close(async () => {       // перестаём принимать новые запросы, дожидаемся текущих
    await sql.end({ timeout: 5 });
    await redis.quit();
    process.exit(0);
  });
});
```

Без этого при `docker compose up --scale api=2` (уменьшении числа копий) часть запросов обрывается.

### 6.4. Воркер

```ts
// server/worker.ts — отдельный процесс, запускается как `node dist/worker.js`
import { Worker } from 'bullmq';
import { parseFile } from 'music-metadata';

new Worker('track.process', async (job) => {
  const file = await downloadToTmp(job.data.storageKey);    // из MinIO во временный файл
  const tags = await parseFile(file);                        // ID3 / MP4 / FLAC
  const fp = await fpcalc(file);                             // Chromaprint
  const match = tags.common.artist ? null : await acoustidLookup(fp);
  await saveTrackMetadata(job.data.trackId, tags, fp, match);
}, { connection: redis, concurrency: 4 });
```

### 6.5. nginx

```nginx
upstream api {
  least_conn;
  server api:5050 max_fails=3 fail_timeout=10s;   # docker compose сам раскроет все копии сервиса api
}

limit_req_zone $binary_remote_addr zone=perip:10m rate=20r/s;

server {
  listen 80;
  client_max_body_size 2m;                         # аудио идёт в MinIO напрямую, сюда только JSON

  location / {
    limit_req zone=perip burst=40 nodelay;
    proxy_pass http://api;
    proxy_set_header X-Request-Id $request_id;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_next_upstream error timeout http_502 http_503;
  }
}
```

Для настоящего round-robin по нескольким контейнерам с одинаковым именем в nginx нужен `resolver 127.0.0.11 valid=10s;` и переменная в `proxy_pass`. Можно поступить проще и перечислить `api-1`, `api-2`, `api-3` как отдельные сервисы в compose.

### 6.6. docker-compose.yml (основа)

```yaml
services:
  postgres:
    image: postgres:16
    environment: { POSTGRES_DB: music, POSTGRES_USER: music, POSTGRES_PASSWORD: music }
    volumes: [pgdata:/var/lib/postgresql/data]
    healthcheck: { test: ["CMD", "pg_isready", "-U", "music"], interval: 5s }

  pgbouncer:
    image: edoburu/pgbouncer
    environment:
      DATABASE_URL: postgres://music:music@postgres:5432/music
      POOL_MODE: transaction
      MAX_CLIENT_CONN: 500
      DEFAULT_POOL_SIZE: 20
    depends_on: [postgres]

  redis:
    image: redis:7-alpine

  minio:
    image: minio/minio
    command: server /data --console-address ":9001"
    environment: { MINIO_ROOT_USER: minio, MINIO_ROOT_PASSWORD: minio12345 }
    ports: ["9000:9000", "9001:9001"]
    volumes: [miniodata:/data]

  api:
    build: .
    command: node dist/index.js
    env_file: .env
    environment:
      DATABASE_URL: postgres://music:music@pgbouncer:5432/music
      REDIS_URL: redis://redis:6379
      S3_ENDPOINT: http://minio:9000
    depends_on: [pgbouncer, redis, minio]
    healthcheck: { test: ["CMD", "wget", "-qO-", "http://localhost:5050/ready"], interval: 10s }

  worker:
    build: .
    command: node dist/worker.js
    env_file: .env
    depends_on: [redis, minio, pgbouncer]

  migrate:
    build: .
    command: node dist/db/migrate.js up
    environment: { DATABASE_URL: postgres://music:music@postgres:5432/music }   # миграции идут напрямую, не через PgBouncer
    depends_on: [postgres]

  nginx:
    image: nginx:1.27-alpine
    volumes: ["./nginx/nginx.conf:/etc/nginx/conf.d/default.conf:ro"]
    ports: ["8080:80"]
    depends_on: [api]

volumes: { pgdata: {}, miniodata: {} }
```

Запуск: `docker compose up -d --build --scale api=3`.

С PgBouncer в transaction mode у `postgres.js` нужно выключить подготовленные запросы: `postgres(url, { prepare: false })`.

---

## 7. План работ на 5 дней

Порядок выбран так, чтобы сервер оставался рабочим после каждого дня, а приложение продолжало работать на v1 до перехода на v2.

### День 1. Один сервер, закрытые дыры, Docker

- [x] Сделать `backend/` единственным сервером: старый `server/` убрать из запуска, оставить только папку `storage` до переноса в MinIO (день 2).
- [x] Вернуть гостевые маршруты: восстановить `guest.routes.ts` из истории git (он удалён в коммите `4466e85` «mvp v1/1»: `git checkout 4466e85~1 -- backend/server/modules/guest/guest.routes.ts` и подключить в `index.ts` как `/guest-tracks`) или сделать `/v2/featured` и поменять URL в приложении.
- [x] `authGuard` на `GET /tracks/:id`; убрать `express.static('/storage')`, выдавать файлы только через маршрут с проверкой владельца.
- [x] В `appConfig.ts` убрать дефолты у `JWT_ACCESS_SECRET` и `JWT_REFRESH_SECRET`, чтобы сервер не стартовал без них.
- [x] Миграция `0003_refresh_tokens`, ротация refresh-токенов, настоящий `logout`.
- [x] Вынести `app.ts` из `index.ts`, добавить graceful shutdown, `/ready`, pino с `request-id`.
- [x] `Dockerfile` + `docker-compose.yml` с Postgres и одной копией API, миграции через сервис `migrate`.

**Сделано 5 ноября.** Проверено на живом Postgres: миграции 0001–0003, 401/404 на чужой трек и файл, ротация и logout. Docker-образ собран не был (нет Docker на машине проверки), compose-файл проверен `docker compose config`. Вместо удаления `express.static` он оставлен за `storageGuard`: так сохраняются Range-запросы.

**Готово, когда:** `docker compose up` поднимает API с чистой базой, `npm run migrate` проходит, чужой трек по id возвращает 404, после logout старый refresh даёт 401.

### День 2. Файлы в MinIO

- [ ] Добавить MinIO в compose, `config/s3.ts`, бакет `audio`.
- [ ] Миграция `0004_media_files`.
- [ ] Скрипт `scripts/migrate-storage-to-s3.ts`: обходит `server/storage`, считает sha256, загружает файл один раз, заполняет `media_files`, связывает с `tracks`.
- [ ] Загрузка: `POST /v2/tracks/uploads` (presigned PUT) и `POST /v2/tracks/:id/complete`.
- [ ] Стрим: `GET /v2/tracks/:id/stream` → `302` на presigned GET с правильным `Content-Type`.
- [ ] v1-маршруты стрима переключить на чтение из MinIO, чтобы приложение работало без изменений.

**Готово, когда:** после удаления `server/storage` у себя локально треки по-прежнему играют, а дубли загружаются один раз (проверка по `sha256`).

### День 3. Каталог, библиотека, синхронизация

- [ ] Миграции `0005_catalog` … `0009_nfc_tags`, перенос данных из `tracks.notes` в `external_refs` и из `guest_tracks` в `featured`.
- [ ] Модули `library`, `playlists` (v2) с инкрементальным sync по `version` и `deleted_at`.
- [ ] Чтение плейлистов одним запросом (JOIN + `json_agg`) вместо N+1.
- [ ] `GET/POST /v2/nfc/:uid` вместо поиска трека по названию.
- [ ] Интеграционные тесты supertest на auth, sync и nfc.

**Готово, когда:** sync плейлиста на 100 треков укладывается в 1–3 запроса к БД (видно по логам), два устройства при одновременной правке получают `409`, а не теряют данные.

### День 4. Масштабирование

- [ ] Redis в compose, `config/redis.ts`.
- [ ] Кэш `GET /v2/featured` и `/v2/charts/top` в Redis (TTL 5 минут, сброс при изменении).
- [ ] Rate limit через Redis: логин, регистрация и общий лимит на пользователя.
- [ ] PgBouncer и `prepare: false` в `config/db.ts`.
- [ ] nginx: `least_conn`, health check, `limit_req`, `X-Request-Id`, `proxy_next_upstream`.
- [ ] Запуск с `--scale api=3`, проверка: остановить одну копию (`docker stop`) во время запросов, ошибок у клиента быть не должно.
- [ ] (Опционально) `prom-client` с метриками `/metrics`, Prometheus + Grafana в compose.

**Готово, когда:** три копии API работают за nginx, а остановка любой из них не ломает приложение.

### День 5. Фоновая обработка и нагрузочный тест

- [ ] BullMQ: очередь `track.process` и процесс `worker.ts`.
- [ ] В воркере: `music-metadata` для тегов, `fpcalc` + AcoustID для треков без тегов, заполнение `artists`/`albums`, статус `processing_status`.
- [ ] Миграция `0010_play_events`, `POST /v2/events` (ответ `202`, запись в БД делает воркер), пересчёт топ-чарта по расписанию (repeatable job раз в 5 минут).
- [ ] k6-сценарий `load/smoke.k6.js`: логин → библиотека → featured → stream-ссылка → событие прослушивания.
- [ ] Прогнать k6 на 1 и на 3 копиях API, записать RPS, p95 и процент ошибок в таблицу для пояснительной записки.
- [ ] Обновить Swagger и README (как запустить стенд, какие переменные окружения нужны).

**Готово, когда:** загруженный `track01.mp3` без тегов через несколько секунд получает исполнителя и название, а в README лежит таблица результатов нагрузки.

Пример сценария k6:

```js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [{ duration: '30s', target: 50 }, { duration: '1m', target: 200 }, { duration: '30s', target: 0 }],
  thresholds: { http_req_duration: ['p(95)<300'], http_req_failed: ['rate<0.01'] },
};

const BASE = __ENV.BASE || 'http://localhost:8080';

export function setup() {
  const res = http.post(`${BASE}/v2/auth/login`, JSON.stringify({ email: 'load@test.dev', password: 'password123' }),
    { headers: { 'Content-Type': 'application/json' } });
  return { token: res.json('tokens.accessToken') };
}

export default function ({ token }) {
  const h = { headers: { Authorization: `Bearer ${token}` } };
  check(http.get(`${BASE}/v2/featured`, h), { featured: (r) => r.status === 200 });
  check(http.get(`${BASE}/v2/library`, h), { library: (r) => r.status === 200 });
  sleep(1);
}
```

---

## 8. Что останется на потом

- Read-реплика Postgres для каталога и чартов (в коде это второй пул `sqlRead`).
- CDN перед MinIO для популярных треков.
- Python-воркер анализа настроения (librosa для музыки, Whisper и текстовая модель для лирики) с записью в `track_features` и `pgvector`. Он подключается к той же очереди BullMQ через Redis, концепт описан отдельно.
- Удаление v1 и старых колонок (`tracks.user_id`, `file_path`, `notes`, таблица `guest_tracks`).
