# MUmuSIC API на Spring MVC

Замена сервера `backend/` (Node.js + Express) на Java 21 + Spring Boot 3 (Spring MVC).
Адреса, тела запросов и ответов, коды ошибок и тексты сообщений те же, поэтому
Flutter-приложение менять не нужно. База и папка с аудио тоже общие со старым сервером.

## Что внутри

| Пакет | Что делает | Было в Node |
|---|---|---|
| `auth` | регистрация, вход, `/auth/me`, ротация refresh-токенов, logout | `modules/auth` |
| `tracks` | загрузка (multipart, до 100 МБ), список, получение, удаление личных треков | `modules/tracks` |
| `storage` | `/storage/**`: раздача файлов с Range, доступ к `users/{id}/...` только владельцу | `express.static` + `storageGuard` |
| `guest` | `/guest-tracks`, стрим по id, по названию и из папки NFC | `modules/guest` |
| `topchart` | `/top-charts` и стрим | `modules/top-chart` |
| `sync` | `/sync/data`, `/sync/upload`, `/sync/playlists` | `modules/sync` |
| `health` | `/health`, `/ready`, плавная остановка | `app.ts`, `index.ts` |
| `security` | JWT (HS256), фильтр Spring Security, ответы 401 | `token.service`, `authGuard` |
| `config` | проверка `.env`, пул БД из `DATABASE_URL`, CORS, X-Request-Id и журнал запросов | `appConfig.ts`, pino |

Схема БД: `src/main/resources/db/migration` (те же SQL, что `backend/migrations`), применяет Flyway при старте.

## Совместимость со старым сервером

* **Токены.** Формат JWT тот же (числовой `sub`, поле `type`, HS256). Если взять `JWT_ACCESS_SECRET`
  и `JWT_REFRESH_SECRET` из `backend/.env`, уже выданные токены и подписанные ссылки на файлы продолжат
  работать, пользователей не выкинет из аккаунта.
* **Пароли.** bcrypt совместим в обе стороны: старые хеши `$2b$` проверяются, новые понимает и Node.
* **База.** На базе, которую создавал старый раннер миграций, Flyway делает baseline на версии 0
  и проходит все миграции (они идемпотентны, `IF NOT EXISTS`). Таблица `schema_migrations` остаётся, не мешает.
* **Форматы.** Даты как `Date.toISOString()` (`2026-11-05T17:07:15.123Z`), `file_size` строкой (как отдавал
  postgres.js; приложение так и читает), поля `undefined` в ответах `/sync/data` не выводятся.

Проверено прогоном 71 одинакового запроса к старому и новому серверу на общей базе: совпадают коды и тела.
Отличаются только отладочные детали: внутренний формат `issues` в ошибках валидации, пустое тело у 416
от `/storage`. Небольшие исправления: 413 вместо 500 на слишком большой файл, `Range: bytes=-N` в стримах
работает (старый сервер отвечал 500), неверный id в `/guest-tracks/{id}/stream` и `DELETE /tracks/{id}` даёт 404, а не 500.

## Запуск

### Docker (как раньше)

```bash
cd backend-java
cp .env.example .env      # вписать JWT-секреты (можно из backend/.env)
docker compose up -d --build
```

API на `http://localhost:5050`, Postgres на `localhost:5433`, Swagger на `http://localhost:5050/api-docs`.
Перед запуском остановите старый стенд (`docker compose down` в `backend/`): порты те же.
Том `pgdata` и имя проекта `mumusic` те же, поэтому данные старой базы подхватятся.

### Локально

Нужны JDK 21 и Maven 3.9 (или IntelliJ IDEA, она откроет `pom.xml` как проект).

```bash
cd backend-java
cp .env.example .env      # DATABASE_URL, JWT_ACCESS_SECRET, JWT_REFRESH_SECRET
mvn spring-boot:run
```

Сборка jar и тесты:

```bash
mvn package               # target/mumusic-api.jar, заодно запускает тесты
java -jar target/mumusic-api.jar
```

На Linux/macOS при запуске вне Docker нужна UTF-8 локаль (`LANG=C.UTF-8`), иначе файлы с кириллицей
в названии не откроются. В Docker это уже настроено.

## Переменные окружения

Те же, что у старого сервера, см. `.env.example`. Отличия:
* `NODE_ENV` можно оставить, но новое имя `APP_ENV`;
* `LOG_LEVEL`: `trace | debug | info | warn | error | off` (вместо `silent` пишите `off`);
* `SUPABASE_*` и `SESSION_SECRET` не используются (их не использовал и старый код).

## Тесты

`mvn test`: 38 тестов. Перенесены тесты старого сервера (`storageGuard`, ротация refresh-токенов),
добавлены проверки совместимости: токены и bcrypt-хеши, выпущенные Node-версией, принимаются.
