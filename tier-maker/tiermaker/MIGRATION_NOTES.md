# Заметки по переносу экранов из Kotlin в Flutter

## Перенесенные экраны

### 1. MainScreen (MainScreen.kt → main_screen.dart)

**Расположение:** `lib/home/presentation/screens/main_screen.dart`

**Особенности переноса:**
- Использован `ListView.builder` вместо `LazyColumn` (аналог в Flutter)
- Создан виджет `MenuItemWidget` для элементов меню
- Навигация реализована через `go_router` (context.push)
- Цвет фона: `Color(0xFF3772E7)` (аналог `Color(red = 55, green = 114, blue = 231)`)

**Меню:**
- Поиск (пока заглушка)
- Моя медиатека (пока заглушка)
- Избранное (пока заглушка)
- Настройки (работает, переходит на SettingsScreen)

### 2. SettingsScreen (SettingsScreen.kt → settings_screen.dart)

**Расположение:** `lib/settings/presentation/screens/settings_screen.dart`

**Особенности переноса:**
- Переключатель темы интегрирован с `AppModel`
- Использован `share_plus` для шаринга приложения
- Использован `url_launcher` для открытия email и веб-страниц
- Все функции обернуты в try-catch с показом ошибок через SnackBar

**Функции:**
- Переключение темы (темная/светлая)
- Поделиться приложением
- Связаться с поддержкой (открывает email клиент)
- Пользовательское соглашение (открывает URL)

### 3. PanelHeader (новый виджет)

**Расположение:** `lib/core/global_widgets/panel_header.dart`

**Особенности:**
- Аналог `PanelHeader` из Kotlin проекта
- Поддерживает кнопку "Назад" с навигацией через `go_router`
- Настраиваемый цвет текста

## Структура проекта

```
lib/
├── core/
│   ├── global_widgets/
│   │   └── panel_header.dart      # Виджет заголовка
│   └── navigation/
│       └── app_router.dart         # Конфигурация роутера
├── home/
│   └── presentation/
│       └── screens/
│           └── main_screen.dart    # Главный экран
└── settings/
    └── presentation/
        └── screens/
            └── settings_screen.dart # Экран настроек
```

## Навигация

Навигация реализована через `go_router`:

```dart
// Переход на экран настроек
context.push(AppRoutes.settings);

// Возврат назад
context.pop();
```

## Зависимости

Добавлены новые зависимости:
- `go_router: ^14.2.0` - для навигации
- `share_plus: ^10.0.2` - для шаринга приложения
- `url_launcher: ^6.1.11` - уже был в проекте, используется для email и URL

## Отличия от Kotlin версии

1. **State Management:** Используется `ChangeNotifier` + `InheritedNotifier` вместо ViewModel
2. **Навигация:** `go_router` вместо Jetpack Navigation
3. **UI:** Material Design 3 вместо Compose
4. **Обработка ошибок:** SnackBar вместо Toast

## TODO

- [ ] Добавить экран поиска
- [ ] Добавить экран "Моя медиатека"
- [ ] Добавить экран "Избранное"
- [ ] Настроить реальные URL для поддержки и соглашения
- [ ] Добавить локализацию (i18n)

