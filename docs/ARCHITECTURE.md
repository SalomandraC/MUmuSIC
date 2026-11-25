# Архитектура MUmuSIC

## Компоненты и потоки данных

Flutter обращается к iTunes напрямую для поиска и получения превью. Собственный API обслуживает учётные записи, личные треки, публичный каталог и синхронизацию. PostgreSQL хранит метаданные; аудиофайлы лежат в файловом хранилище. На устройстве используются Hive и локальные файлы.

```text
Flutter ── HTTP ── iTunes Search API / превью
   │
   ├── Hive: настройки, состояние, локальные коллекции
   ├── локальные аудиофайлы → PlayerService
   └── HTTP → Java API (либо предыдущий Node API)
                  ├── PostgreSQL: пользователи, треки, плейлисты, токены
                  └── server/storage: аудио → HTTP Range → плеер
```

## Flutter: `tier-maker/tiermaker/lib`

| Каталог / файл | Ответственность |
|---|---|
| `main.dart` | Загрузка `.env`, инициализация Hive, URL API и состояния приложения |
| `app/my_app.dart` | `MaterialApp.router`, тема, локаль, общая панель плеера |
| `app/models/app_model.dart` | Общее состояние через `ChangeNotifier`: тема, пользователь, гостевой режим |
| `app/state/` | Предоставление `AppModel` дереву виджетов |
| `core/navigation/app_router.dart` | Конфигурация GoRouter, используется из `my_app.dart` |
| `core/api/` | HTTP-клиенты auth, tracks, guest tracks, top charts и sync |
| `core/config/env_config.dart` | Чтение `API_BASE_URL`, кэш и резервный localhost |
| `core/app_database/` | Hive: настройки, токены, метаданные треков |
| `core/audio/` | Сервис плеера, модель трека, адаптеры, общая панель |
| `core/services/` | Загрузка, скачивание и удаление файлов |
| `data/` | DTO, локальный и iTunes-источники, реализации репозиториев |
| `domain/` | Сущности, интерфейсы репозиториев, сценарии поиска и коллекций |
| `di/dependency_injection.dart` | Статическая сборка источников, репозиториев и use case |
| `home/` | Главный экран и работа с сетевыми/загруженными треками; свои domain и presentation |
| `auth/`, `search/`, `playlists/`, `favorites/`, `storage/` | Экраны соответствующих функций |
| `top_charts/`, `nfc/`, `settings/`, `theme/` | Чарты, NFC, настройки и оформление |

Архитектура смешанная: общие `data/domain` сосуществуют с feature-модулями, а часть экранов работает с API напрямую. При изменении поведения нужно проследить реальный путь вызовов от экрана. Наличие класса в `domain` само по себе не означает, что все экраны используют его.

`AppDatabase` фактически хранит access/refresh-токены в Hive. Зависимость `flutter_secure_storage` в `pubspec.yaml` не доказывает, что этот путь уже переведён на защищённое хранилище.

## Java API: `backend-java/src/main`

Точка входа — `java/ru/mumusic/api/MumusicApplication.java`. Пакеты организованы по функциям; контроллеры принимают HTTP-запросы, сервисы реализуют операции, репозитории выполняют SQL через JDBC. `security`, `config` и `common` обеспечивают общую инфраструктуру.

| Пакет | Маршруты / назначение |
|---|---|
| `auth` | `POST /auth/register`, `/login`, `/refresh-token`, `/logout`; `GET /auth/me` |
| `tracks` | `GET/POST /tracks`, `GET/DELETE /tracks/{id}` |
| `guest` | `GET /guest-tracks`, `/{id}/stream`, `/by-title/stream`, `/nfc/stream` |
| `topchart` | `GET /top-charts`, `/top-charts/{id}/stream` |
| `sync` | `GET /sync/data`, `POST /sync/upload`, `/sync/playlists` |
| `storage` | `GET /storage/**`, авторизация личных файлов и Range-выдача |
| `health` | `GET /health` и `/ready` |
| `security` | JWT, фильтры и политика доступа |
| `config`, `common` | Настройки, БД, CORS, ошибки и вспомогательные преобразования |

Полные URL в строках с сокращениями образуются с префиксом пакета, например `/auth/login` и `/guest-tracks/{id}/stream`. Детальные тела запросов смотрите в контроллерах и Swagger `/api-docs`; OpenAPI доступен на `/api-docs/openapi.json`.

## База и файлы

Flyway применяет `resources/db/migration/V*.sql` при старте Java API. Основные таблицы: `users`, `tracks`, `playlists`, `playlist_tracks`, `guest_tracks`, `refresh_tokens`. Плейлисты связаны с треками через `playlist_tracks`; личные треки принадлежат пользователям. Публичный гостевой каталог хранится отдельно.

`tracks.file_path` указывает на файл внутри корня хранилища. Корень по умолчанию — `../server/storage` при запуске из каталога backend. В Docker этот каталог смонтирован в `/data/storage`. Личные файлы расположены в `users/{id}/`, NFC-файлы — в `nfc/`. Наличие аудио на диске не заполняет автоматически таблицы каталога.

Java-версия использует JWT и bcrypt с целью совместимости с Node API. При изменениях контрактов особенно значимы имена JSON-полей, представление дат, строковый `file_size`, refresh-ротация и подписанные ссылки на аудио. Старый README сообщает о проверке совместимости; это историческое свидетельство, а не результат нового прогона.

## Где менять функцию

- Новый экран: feature-каталог Flutter, затем `core/navigation/app_router.dart`.
- Новый серверный сценарий: Java-контроллер/сервис/репозиторий, при необходимости новая Flyway-миграция, затем клиент в `core/api/`.
- Поиск iTunes: `data/datasources/remote/itunes_remote_datasource.dart`, репозитории и use case поиска.
- Воспроизведение: `core/audio/`; загрузки и файловые операции: `core/services/`.
- Темы: `theme/`, `settings/` и `AppModel`; постоянное состояние: `core/app_database/`.
- ML-конвейер: пока требования в корневом ТЗ; очереди, воркеры и API задач требуют отдельного проектирования.
