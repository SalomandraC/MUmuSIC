# MuMusic backend

Express + TypeScript + PostgreSQL. Единственный сервер проекта (старый `../server` отключён,
из него используется только папка `storage`).

## Запуск локально

```bash
cp .env.example .env        # заполнить DATABASE_URL и JWT-секреты
npm install
npm run migrate             # применить migrations/*.sql
npm run dev                 # http://localhost:5050, документация /api-docs
```

Без `JWT_ACCESS_SECRET` и `JWT_REFRESH_SECRET` (не короче 32 символов, разные) сервер не стартует.
Сгенерировать: `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"`.

## Запуск в Docker

```bash
docker compose up -d --build      # postgres → migrate → api
docker compose logs -f api
docker compose down               # данные БД остаются в томе pgdata
```

- API: `http://localhost:5050`, Postgres снаружи: `localhost:5433` (пользователь и пароль `mumusic`).
- JWT-секреты compose берёт из `backend/.env`.
- Аудио монтируется из `../server/storage`.
- База в контейнере новая и пустая. Перенести данные из текущей базы:
  `pg_dump --data-only --no-owner "$OLD_DATABASE_URL" | psql postgres://mumusic:mumusic@localhost:5433/mumusic`.

## Проверки

| Маршрут | Что значит |
|---|---|
| `GET /health` | процесс жив (для перезапуска контейнера) |
| `GET /ready` | есть связь с БД и хранилищем; `503` во время остановки (для балансировщика) |

На `SIGTERM` (`docker stop`) сервер перестаёт принимать новые соединения, дожидается текущих
запросов и закрывает пул БД.

## Логи

pino: JSON в production, цветной вывод при `NODE_ENV=development`. У каждого запроса есть id:
берётся из заголовка `X-Request-Id` (его проставит nginx) или создаётся, и возвращается в ответе.
Токены из `Authorization` и `?token=` в лог не попадают.

## Безопасность (что изменилось в 1-й день)

- `/storage/users/{id}/...` отдаётся только владельцу: по `Authorization: Bearer` или по
  подписанной ссылке `?token=` из поля `file_url` (срок `MEDIA_TOKEN_TTL`, 7 дней).
  Общие треки (`/storage/*.mp3`, `/storage/nfc/...`) по-прежнему публичные.
- `GET /tracks/:id` требует авторизации; чужой приватный трек отвечает 404.
- Refresh-токены хранятся в `refresh_tokens` (sha256). `POST /auth/refresh-token` выдаёт новую
  пару и отзывает старый токен; повторное использование отозванного токена отзывает все сессии.
- `POST /auth/logout` с телом `{ "refreshToken": "..." }` отзывает токен устройства,
  с `"allDevices": true` — все сессии. Без тела отвечает как раньше.
- Старые refresh-токены (выданные до обновления) принимаются один раз и меняются на новые,
  поэтому пользователей не выкинет из аккаунта.
- Внутренние ошибки (500) в production возвращают общий текст без деталей.
