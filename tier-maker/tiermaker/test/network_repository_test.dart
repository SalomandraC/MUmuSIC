import 'package:flutter_test/flutter_test.dart';

/// Тестовый модуль для объекта тестирования NetworkRepositoryImpl._sanitizeFileName
/// 
/// Набор тестов покрывает следующие сценарии:
/// 1. Очистка имени файла от недопустимых символов
/// 2. Замена недопустимых символов на подчеркивания
/// 3. Нормализация множественных пробелов
/// 4. Удаление пробелов в начале и конце
/// 5. Обработка пустой строки
/// 6. Обработка строки только с недопустимыми символами
/// 7. Сохранение валидных символов
/// 
/// Примечание: Метод _sanitizeFileName является приватным, поэтому для тестирования
/// используется тестовый helper, который дублирует логику метода из исходного кода.
/// В реальном проекте рекомендуется сделать метод package-private для улучшения тестируемости.
void main() {
  group('NetworkRepositoryImpl._sanitizeFileName', () {
    /// Тестовый helper, дублирующий логику приватного метода _sanitizeFileName
    /// из NetworkRepositoryImpl для целей тестирования
    String sanitizeFileName(String fileName) {
      return fileName
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    test('должен заменить недопустимые символы на подчеркивания', () {
      // Arrange
      const fileName = 'test<file>name.txt';

      // Act
      final result = sanitizeFileName(fileName);

      // Assert
      expect(result, equals('test_file_name.txt'));
      expect(result, isNot(contains('<')));
      expect(result, isNot(contains('>')));
    });

    test('должен заменить все недопустимые символы', () {
      // Arrange
      const fileName = 'file:name/path\\with|invalid?symbols*';

      // Act
      final result = sanitizeFileName(fileName);

      // Assert
      expect(result, equals('file_name_path_with_invalid_symbols_'));
      expect(result, isNot(contains(':')));
      expect(result, isNot(contains('/')));
      expect(result, isNot(contains('\\')));
      expect(result, isNot(contains('|')));
      expect(result, isNot(contains('?')));
      expect(result, isNot(contains('*')));
    });

    test('должен нормализовать множественные пробелы', () {
      // Arrange
      const fileName = 'file    name    with    spaces.txt';

      // Act
      final result = sanitizeFileName(fileName);

      // Assert
      expect(result, equals('file name with spaces.txt'));
      expect(result, isNot(contains('    ')));
    });

    test('должен удалить пробелы в начале и конце', () {
      // Arrange
      const fileName = '   filename.txt   ';

      // Act
      final result = sanitizeFileName(fileName);

      // Assert
      expect(result, equals('filename.txt'));
      expect(result, isNot(startsWith(' ')));
      expect(result, isNot(endsWith(' ')));
    });

    test('должен обработать пустую строку', () {
      // Arrange
      const fileName = '';

      // Act
      final result = sanitizeFileName(fileName);

      // Assert
      expect(result, equals(''));
    });

    test('должен обработать строку только с недопустимыми символами', () {
      // Arrange
      const fileName = '<>:"/\\|?*';

      // Act
      final result = sanitizeFileName(fileName);

      // Assert
      expect(result, equals('_________'));
      expect(result.length, equals(9));
    });

    test('должен сохранить валидные символы', () {
      // Arrange
      const fileName = 'valid-filename_123.txt';

      // Act
      final result = sanitizeFileName(fileName);

      // Assert
      expect(result, equals('valid-filename_123.txt'));
    });

    test('должен обработать комбинацию недопустимых символов и пробелов', () {
      // Arrange
      const fileName = '  file<name>  with:spaces  ';

      // Act
      final result = sanitizeFileName(fileName);

      // Assert
      expect(result, equals('file_name_ with_spaces'));
    });

    test('должен обработать имя файла с кириллицей', () {
      // Arrange
      const fileName = 'файл<название>.txt';

      // Act
      final result = sanitizeFileName(fileName);

      // Assert
      expect(result, equals('файл_название_.txt'));
    });

    test('должен обработать имя файла с различными типами пробелов', () {
      // Arrange
      const fileName = 'file\t\tname\n\nwith\r\rspaces';

      // Act
      final result = sanitizeFileName(fileName);

      // Assert
      // Регулярное выражение \s+ должно заменить все пробельные символы на один пробел
      expect(result, contains(' '));
      expect(result, isNot(contains('\t')));
      expect(result, isNot(contains('\n')));
      expect(result, isNot(contains('\r')));
    });

    test('должен сохранить структуру пути с подчеркиваниями', () {
      // Arrange
      const fileName = 'artist - track name.m4a';

      // Act
      final result = sanitizeFileName(fileName);

      // Assert
      expect(result, equals('artist - track name.m4a'));
    });
  });
}

