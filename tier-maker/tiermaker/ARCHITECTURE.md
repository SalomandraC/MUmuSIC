# Архитектура проекта Tier Maker

## Текущая структура

```
lib/
├── app/                    # Глобальная конфигурация приложения
│   ├── app_routes.dart     # Константы маршрутов
│   ├── my_app.dart         # Главный виджет приложения
│   ├── models/
│   │   └── app_model.dart  # Глобальное состояние приложения
│   └── state/
│       └── app_model_provider.dart
├── core/                   # Базовые компоненты
│   ├── app_database/       # Локальное хранилище (Hive)
│   ├── global_widgets/     # Переиспользуемые виджеты
│   └── utils/              # Утилиты
├── home/                   # Feature: Home экран
│   ├── domain/
│   │   ├── model/          # Модели домена
│   │   ├── repository/     # Интерфейсы репозиториев
│   │   └── state/           # State management для feature
│   └── presentation/
│       ├── screens/        # Экраны
│       └── widgets/        # Виджеты feature
├── theme/                  # Темизация
│   └── theme.dart
└── main.dart               # Точка входа
```

## Рекомендации по улучшению архитектуры

### ⚠️ Что нужно улучшить:

#### 1. **Единообразие структуры features**

Все features должны следовать единому паттерну:

```
feature_name/
├── domain/
│   ├── entities/          # Сущности домена (чистые классы данных)
│   ├── repositories/      # Интерфейсы репозиториев
│   └── use_cases/         # Бизнес-логика (опционально)
├── data/                  # Реализация репозиториев (если нужна)
│   ├── models/           # Модели данных (DTO)
│   ├── repositories/     # Реализация репозиториев
│   └── data_sources/     # Источники данных (локальные/удаленные)
└── presentation/
    ├── screens/          # Экраны
    ├── widgets/         # Виджеты feature
    └── providers/       # State management (ChangeNotifier, Riverpod, etc.)
```

#### 2. **Глобальное состояние**

`app_model` лучше перенести в `core/state/` или `shared/state/`, так как это не feature, а глобальная настройка.

**Рекомендуемая структура:**
```
core/
├── state/
│   ├── app_state.dart        # AppModel переименовать в AppState
│   └── app_state_provider.dart
```

#### 3. **Роутинг**

Создать отдельный модуль для навигации:

```
core/
└── navigation/
    ├── app_router.dart       # Конфигурация роутера (go_router или auto_route)
    └── route_names.dart      # Константы маршрутов
```

#### 4. **Именование**

- `home_screen_model.dart` → `home_model.dart` (убрать избыточное "screen")
- `app_model.dart` → `app_state.dart` (более точное название)
- Папки в единственном числе: `widget` вместо `widgets` (опционально, но современный подход)

#### 5. **State Management**

Для больших проектов рассмотреть:
- **Riverpod** - современная альтернатива Provider
- **Bloc** - если нужна более строгая архитектура
- **GetX** - для быстрой разработки (но менее популярен в enterprise)

Текущий подход с `ChangeNotifier` + `InheritedNotifier` хорош для небольших проектов.

#### 6. **Dependency Injection**

Рассмотреть использование:
- **get_it** - простой service locator
- **Riverpod** - встроенный DI
- **injectable** - code generation для DI

#### 7. **Структура для будущих features**

Пример для feature "tier_list":

```
tier_list/
├── domain/
│   ├── entities/
│   │   └── tier_list.dart
│   └── repositories/
│       └── i_tier_list_repository.dart
├── data/
│   ├── models/
│   │   └── tier_list_model.dart
│   └── repositories/
│       └── tier_list_repository.dart
└── presentation/
    ├── screens/
    │   └── tier_list_screen.dart
    ├── widgets/
    │   └── tier_item_widget.dart
    └── providers/
        └── tier_list_provider.dart
```

## Рекомендуемая финальная структура

```
lib/
├── app/
│   ├── app.dart              # Главный виджет
│   └── routes.dart           # Константы маршрутов
├── core/
│   ├── database/             # Hive/другая БД
│   ├── navigation/           # Роутинг
│   ├── state/                # Глобальное состояние
│   ├── theme/                # Темизация
│   ├── widgets/              # Глобальные виджеты
│   └── utils/                # Утилиты
├── features/                 # Все features
│   ├── home/
│   ├── tier_list/
│   ├── settings/
│   └── ...
└── main.dart
```

## Выполненные улучшения

1. ✅ Исправлены импорты (sunflower → RandomTierList)
2. ✅ Удалено дублирование моделей
3. ✅ Добавлено использование темы в MaterialApp
4. ✅ Реорганизована структура home feature:
   - Модель перенесена в `domain/model/home_model.dart`
   - Provider создан в `presentation/providers/home_provider.dart`
   - Удалена неправильная структура `state/home_screen_model_provider/`
