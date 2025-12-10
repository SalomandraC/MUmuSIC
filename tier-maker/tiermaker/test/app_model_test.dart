import 'package:flutter_test/flutter_test.dart';
import 'package:RandomTierList/app/models/app_model.dart';
import 'package:RandomTierList/core/app_database/app_database.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Тестовый модуль для объекта тестирования AppModel.setTheme
/// 
/// Набор тестов покрывает следующие сценарии:
/// 1. Установка валидного кода темы 'lt' (светлая)
/// 2. Установка валидного кода темы 'dr' (темная)
/// 3. Установка невалидного кода темы (длина не 2 символа)
/// 4. Установка невалидного кода темы (пустая строка)
/// 5. Установка невалидного кода темы (слишком длинная строка)
/// 6. Проверка обновления состояния приложения
/// 7. Проверка сохранения в базу данных
void main() {
  group('AppModel.setTheme', () {
    late AppModel appModel;

    setUpAll(() async {
      // Инициализация Hive для тестов
      await Hive.initFlutter();
    });

    setUp(() async {
      // Очистка box перед каждым тестом
      final box = await Hive.openBox<String>('appBox');
      await box.clear();
      await box.put('appState', 'ltru000000');
      await box.close();
      
      appModel = AppModel();
      // Ждем завершения инициализации
      while (appModel.isLoading) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
    });

    tearDown(() async {
      await AppDatabase.close();
    });

    test('должен установить светлую тему при валидном коде "lt"', () async {
      // Arrange
      const themeCode = 'lt';
      final initialState = appModel.appState;

      // Act
      await appModel.setTheme(themeCode);

      // Assert
      expect(appModel.themeCode, equals('lt'));
      expect(appModel.isDarkTheme, isFalse);
      // Проверяем, что первые 2 символа изменились
      expect(appModel.appState.substring(0, 2), equals('lt'));
      // Проверяем, что остальная часть не изменилась
      if (initialState.length >= 4) {
        expect(appModel.appState.substring(2), equals(initialState.substring(2)));
      }
    });

    test('должен установить темную тему при валидном коде "dr"', () async {
      // Arrange
      const themeCode = 'dr';

      // Act
      await appModel.setTheme(themeCode);

      // Assert
      expect(appModel.themeCode, equals('dr'));
      expect(appModel.isDarkTheme, isTrue);
      expect(appModel.appState.substring(0, 2), equals('dr'));
    });

    test('не должен изменить тему при невалидном коде (пустая строка)', () async {
      // Arrange
      const themeCode = '';
      final initialState = appModel.appState;

      // Act
      await appModel.setTheme(themeCode);

      // Assert
      // Состояние не должно измениться
      expect(appModel.appState, equals(initialState));
    });

    test('не должен изменить тему при невалидном коде (один символ)', () async {
      // Arrange
      const themeCode = 'l';
      final initialState = appModel.appState;

      // Act
      await appModel.setTheme(themeCode);

      // Assert
      // Состояние не должно измениться
      expect(appModel.appState, equals(initialState));
    });

    test('не должен изменить тему при невалидном коде (три символа)', () async {
      // Arrange
      const themeCode = 'ltr';
      final initialState = appModel.appState;

      // Act
      await appModel.setTheme(themeCode);

      // Assert
      // Состояние не должно измениться
      expect(appModel.appState, equals(initialState));
    });

    test('должен сохранить тему в базу данных', () async {
      // Arrange
      const themeCode = 'dr';

      // Act
      await appModel.setTheme(themeCode);

      // Assert
      final savedState = await AppDatabase.getAppTheme();
      expect(savedState.substring(0, 2), equals('dr'));
    });

    test('должен корректно обработать переключение темы', () async {
      // Arrange
      await appModel.setTheme('lt');
      expect(appModel.themeCode, equals('lt'));

      // Act
      await appModel.setTheme('dr');

      // Assert
      expect(appModel.themeCode, equals('dr'));
      expect(appModel.isDarkTheme, isTrue);
    });

    test('должен сохранить остальные части состояния при изменении темы', () async {
      // Arrange
      await appModel.setAppState('ltru123456');
      const themeCode = 'dr';

      // Act
      await appModel.setTheme(themeCode);

      // Assert
      expect(appModel.appState.substring(0, 2), equals('dr'));
      expect(appModel.appState.substring(2, 4), equals('ru'));
      expect(appModel.appState.substring(4), equals('123456'));
    });
  });
}

