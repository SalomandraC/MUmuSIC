/**
 * Набор тестов для модуля arrayUtils
 * Объект тестирования: validateEmailArray, calculateAverage
 */

import { validateEmailArray, calculateAverage } from '../arrayUtils';

describe('arrayUtils', () => {
  describe('validateEmailArray', () => {
    /**
     * Тестовый набор для функции validateEmailArray
     * 
     * Спецификация:
     * - Входные данные:
     *   - emails (string[]) - массив строк для валидации
     *   - allowEmpty (boolean, опционально, по умолчанию true) - разрешить пустой массив
     * - Выходные данные: string[] - отфильтрованный массив валидных email-адресов
     * - Функциональное назначение: фильтрация и валидация массива email-адресов
     * - Обработка исключений: выбрасывает исключения при невалидных входных данных
     */

    test('должна успешно валидировать массив валидных email-адресов', () => {
      const emails = [
        'user1@example.com',
        'user2@example.com',
        'user.name@example.com',
      ];

      const result = validateEmailArray(emails);

      expect(result).toEqual(emails);
      expect(result.length).toBe(3);
    });

    test('должна фильтровать невалидные email из массива', () => {
      const emails = [
        'valid@example.com',
        'invalid-email',
        'another.valid@example.com',
        'not-an-email',
        'valid2@test.co.uk',
      ];

      const result = validateEmailArray(emails);

      expect(result).toEqual([
        'valid@example.com',
        'another.valid@example.com',
        'valid2@test.co.uk',
      ]);
      expect(result.length).toBe(3);
    });

    test('должна возвращать пустой массив при отсутствии валидных email', () => {
      const emails = [
        'invalid-email',
        'not-an-email',
        'also-invalid',
      ];

      const result = validateEmailArray(emails);

      expect(result).toEqual([]);
      expect(result.length).toBe(0);
    });

    test('должна обрабатывать пустой массив при allowEmpty = true', () => {
      const emails: string[] = [];

      const result = validateEmailArray(emails, true);

      expect(result).toEqual([]);
      expect(result.length).toBe(0);
    });

    test('должна выбрасывать исключение при пустом массиве и allowEmpty = false', () => {
      const emails: string[] = [];

      expect(() => validateEmailArray(emails, false)).toThrow(
        'Массив должен содержать хотя бы один валидный email'
      );
    });

    test('должна выбрасывать исключение при невалидных входных данных (не массив)', () => {
      const invalidInputs = [
        null,
        undefined,
        'string',
        123,
        {},
        true,
      ];

      invalidInputs.forEach(input => {
        expect(() => validateEmailArray(input as any)).toThrow(
          'Входные данные должны быть массивом'
        );
      });
    });

    test('должна обрабатывать массив с одним валидным email', () => {
      const emails = ['single@example.com'];

      const result = validateEmailArray(emails);

      expect(result).toEqual(['single@example.com']);
      expect(result.length).toBe(1);
    });

    test('должна обрабатывать массив с одним невалидным email', () => {
      const emails = ['invalid-email'];

      const result = validateEmailArray(emails);

      expect(result).toEqual([]);
      expect(result.length).toBe(0);
    });

    test('должна фильтровать нестроковые элементы из массива', () => {
      const emails = [
        'valid@example.com',
        123 as any,
        null as any,
        undefined as any,
        'another.valid@example.com',
      ];

      const result = validateEmailArray(emails);

      expect(result).toEqual([
        'valid@example.com',
        'another.valid@example.com',
      ]);
    });

    test('должна обрабатывать email с различными доменами', () => {
      const emails = [
        'user@example.com',
        'user@sub.example.com',
        'user@example.co.uk',
        'user@example-domain.com',
      ];

      const result = validateEmailArray(emails);

      expect(result).toEqual(emails);
    });

    test('должна обрабатывать email с пробелами (trim)', () => {
      const emails = [
        '  user@example.com  ',
        'user2@example.com',
      ];

      const result = validateEmailArray(emails);

      expect(result.length).toBeGreaterThan(0);
    });

    test('должна обрабатывать большой массив email-адресов', () => {
      const emails = Array.from({ length: 100 }, (_, i) => `user${i}@example.com`);

      const result = validateEmailArray(emails);

      expect(result.length).toBe(100);
      expect(result[0]).toBe('user0@example.com');
      expect(result[99]).toBe('user99@example.com');
    });
  });

  describe('calculateAverage', () => {
    /**
     * Тестовый набор для функции calculateAverage
     * 
     * Спецификация:
     * - Входные данные: numbers (number[]) - массив чисел
     * - Выходные данные: number - среднее значение (вещественное число)
     * - Функциональное назначение: вычисление среднего значения из массива чисел
     * - Обработка исключений: выбрасывает исключения при невалидных входных данных
     */

    test('должна успешно вычислять среднее значение для массива положительных чисел', () => {
      const numbers = [10, 20, 30, 40, 50];

      const result = calculateAverage(numbers);

      expect(result).toBe(30);
      expect(typeof result).toBe('number');
    });

    test('должна вычислять среднее значение для массива отрицательных чисел', () => {
      const numbers = [-10, -20, -30];

      const result = calculateAverage(numbers);

      expect(result).toBe(-20);
    });

    test('должна вычислять среднее значение для массива смешанных чисел', () => {
      const numbers = [-10, 0, 10, 20];

      const result = calculateAverage(numbers);

      expect(result).toBe(5);
    });

    test('должна вычислять среднее значение для массива с одним элементом', () => {
      const numbers = [42];

      const result = calculateAverage(numbers);

      expect(result).toBe(42);
    });

    test('должна вычислять среднее значение для массива с вещественными числами', () => {
      const numbers = [1.5, 2.5, 3.5, 4.5];

      const result = calculateAverage(numbers);

      expect(result).toBe(3);
    });

    test('должна вычислять среднее значение для массива с нулями', () => {
      const numbers = [0, 0, 0, 0];

      const result = calculateAverage(numbers);

      expect(result).toBe(0);
    });

    test('должна вычислять среднее значение для большого массива', () => {
      const numbers = Array.from({ length: 1000 }, (_, i) => i + 1);

      const result = calculateAverage(numbers);

      expect(result).toBe(500.5);
    });

    test('должна выбрасывать исключение при пустом массиве', () => {
      const numbers: number[] = [];

      expect(() => calculateAverage(numbers)).toThrow(
        'Массив не может быть пустым'
      );
    });

    test('должна выбрасывать исключение при невалидных входных данных (не массив)', () => {
      const invalidInputs = [
        null,
        undefined,
        'string',
        123,
        {},
        true,
      ];

      invalidInputs.forEach(input => {
        expect(() => calculateAverage(input as any)).toThrow(
          'Входные данные должны быть массивом'
        );
      });
    });

    test('должна выбрасывать исключение при наличии NaN в массиве', () => {
      const numbers = [10, 20, NaN, 40];

      expect(() => calculateAverage(numbers)).toThrow(
        'Массив должен содержать только числа'
      );
    });

    test('должна выбрасывать исключение при наличии нечисловых значений в массиве', () => {
      const numbers = [10, 20, 'string' as any, 40];

      expect(() => calculateAverage(numbers)).toThrow(
        'Массив должен содержать только числа'
      );
    });

    test('должна вычислять среднее значение для массива с очень большими числами', () => {
      const numbers = [Number.MAX_SAFE_INTEGER, Number.MAX_SAFE_INTEGER];

      const result = calculateAverage(numbers);

      expect(result).toBe(Number.MAX_SAFE_INTEGER);
    });

    test('должна вычислять среднее значение для массива с очень маленькими числами', () => {
      const numbers = [0.0001, 0.0002, 0.0003];

      const result = calculateAverage(numbers);

      expect(result).toBeCloseTo(0.0002, 5);
    });

    test('должна вычислять среднее значение с высокой точностью', () => {
      const numbers = [1.1, 2.2, 3.3];

      const result = calculateAverage(numbers);

      expect(result).toBeCloseTo(2.2, 10);
    });

    test('должна обрабатывать массив с Infinity', () => {
      const numbers = [10, Infinity, 20];

      const result = calculateAverage(numbers);

      expect(result).toBe(Infinity);
    });

    test('должна обрабатывать массив с -Infinity', () => {
      const numbers = [10, -Infinity, 20];

      const result = calculateAverage(numbers);

      expect(result).toBe(-Infinity);
    });
  });
});

