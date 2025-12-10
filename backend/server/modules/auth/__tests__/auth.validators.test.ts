/**
 * Набор тестов для модуля auth.validators
 * Объект тестирования: registerSchema.parse
 */

import { registerSchema } from '../auth.validators';
import { z } from 'zod';

describe('auth.validators', () => {
  describe('registerSchema.parse', () => {
    /**
     * Тестовый набор для функции registerSchema.parse
     * 
     * Спецификация:
     * - Входные данные: объект с полями:
     *   - username (string) - имя пользователя (мин. 3, макс. 50 символов)
     *   - email (string) - email адрес (валидный email формат)
     *   - password (string) - пароль (мин. 8, макс. 100 символов)
     * - Выходные данные: валидированный объект с теми же полями
     * - Функциональное назначение: валидация данных регистрации пользователя
     * - Обработка исключений: выбрасывает ZodError при невалидных данных
     */

    test('должна успешно валидировать валидные данные регистрации', () => {
      const validData = {
        username: 'testuser',
        email: 'test@example.com',
        password: 'password123',
      };

      const result = registerSchema.parse(validData);

      expect(result).toEqual(validData);
      expect(result.username).toBe('testuser');
      expect(result.email).toBe('test@example.com');
      expect(result.password).toBe('password123');
    });

    test('должна валидировать username минимальной длины', () => {
      const validData = {
        username: 'abc', // Минимум 3 символа
        email: 'test@example.com',
        password: 'password123',
      };

      const result = registerSchema.parse(validData);
      expect(result.username).toBe('abc');
    });

    test('должна валидировать username максимальной длины', () => {
      const validData = {
        username: 'a'.repeat(50), // Максимум 50 символов
        email: 'test@example.com',
        password: 'password123',
      };

      const result = registerSchema.parse(validData);
      expect(result.username.length).toBe(50);
    });

    test('должна выбрасывать исключение при username короче 3 символов', () => {
      const invalidData = {
        username: 'ab', // Меньше 3 символов
        email: 'test@example.com',
        password: 'password123',
      };

      expect(() => registerSchema.parse(invalidData)).toThrow(z.ZodError);
      try {
        registerSchema.parse(invalidData);
      } catch (error) {
        if (error instanceof z.ZodError) {
          expect(error.issues[0].path).toContain('username');
        }
      }
    });

    test('должна выбрасывать исключение при username длиннее 50 символов', () => {
      const invalidData = {
        username: 'a'.repeat(51), // Больше 50 символов
        email: 'test@example.com',
        password: 'password123',
      };

      expect(() => registerSchema.parse(invalidData)).toThrow(z.ZodError);
    });

    test('должна выбрасывать исключение при невалидном email', () => {
      const invalidData = {
        username: 'testuser',
        email: 'invalid-email', // Невалидный email
        password: 'password123',
      };

      expect(() => registerSchema.parse(invalidData)).toThrow(z.ZodError);
      try {
        registerSchema.parse(invalidData);
      } catch (error) {
        if (error instanceof z.ZodError) {
          expect(error.issues[0].path).toContain('email');
        }
      }
    });

    test('должна валидировать различные форматы валидных email', () => {
      const validEmails = [
        'user@example.com',
        'user.name@example.com',
        'user+tag@example.co.uk',
        'user123@example-domain.com',
      ];

      validEmails.forEach(email => {
        const validData = {
          username: 'testuser',
          email,
          password: 'password123',
        };

        const result = registerSchema.parse(validData);
        expect(result.email).toBe(email);
      });
    });

    test('должна валидировать password минимальной длины', () => {
      const validData = {
        username: 'testuser',
        email: 'test@example.com',
        password: '12345678', // Минимум 8 символов
      };

      const result = registerSchema.parse(validData);
      expect(result.password).toBe('12345678');
    });

    test('должна валидировать password максимальной длины', () => {
      const validData = {
        username: 'testuser',
        email: 'test@example.com',
        password: 'a'.repeat(100), // Максимум 100 символов
      };

      const result = registerSchema.parse(validData);
      expect(result.password.length).toBe(100);
    });

    test('должна выбрасывать исключение при password короче 8 символов', () => {
      const invalidData = {
        username: 'testuser',
        email: 'test@example.com',
        password: '1234567', // Меньше 8 символов
      };

      expect(() => registerSchema.parse(invalidData)).toThrow(z.ZodError);
      try {
        registerSchema.parse(invalidData);
      } catch (error) {
        if (error instanceof z.ZodError) {
          expect(error.issues[0].path).toContain('password');
        }
      }
    });

    test('должна выбрасывать исключение при password длиннее 100 символов', () => {
      const invalidData = {
        username: 'testuser',
        email: 'test@example.com',
        password: 'a'.repeat(101), // Больше 100 символов
      };

      expect(() => registerSchema.parse(invalidData)).toThrow(z.ZodError);
    });

    test('должна выбрасывать исключение при отсутствии обязательных полей', () => {
      const invalidData1 = {
        email: 'test@example.com',
        password: 'password123',
        // username отсутствует
      };

      const invalidData2 = {
        username: 'testuser',
        password: 'password123',
        // email отсутствует
      };

      const invalidData3 = {
        username: 'testuser',
        email: 'test@example.com',
        // password отсутствует
      };

      expect(() => registerSchema.parse(invalidData1)).toThrow(z.ZodError);
      expect(() => registerSchema.parse(invalidData2)).toThrow(z.ZodError);
      expect(() => registerSchema.parse(invalidData3)).toThrow(z.ZodError);
    });

    test('должна выбрасывать исключение при неверных типах данных', () => {
      const invalidData1 = {
        username: 123, // Должно быть string
        email: 'test@example.com',
        password: 'password123',
      };

      const invalidData2 = {
        username: 'testuser',
        email: 123, // Должно быть string
        password: 'password123',
      };

      const invalidData3 = {
        username: 'testuser',
        email: 'test@example.com',
        password: 123, // Должно быть string
      };

      expect(() => registerSchema.parse(invalidData1)).toThrow(z.ZodError);
      expect(() => registerSchema.parse(invalidData2)).toThrow(z.ZodError);
      expect(() => registerSchema.parse(invalidData3)).toThrow(z.ZodError);
    });

    test('должна обрабатывать пустые строки', () => {
      const invalidData = {
        username: '',
        email: '',
        password: '',
      };

      expect(() => registerSchema.parse(invalidData)).toThrow(z.ZodError);
    });

    test('должна обрабатывать password со специальными символами', () => {
      const validData = {
        username: 'testuser',
        email: 'test@example.com',
        password: 'P@ssw0rd!#$%^&*()',
      };

      const result = registerSchema.parse(validData);
      expect(result.password).toBe('P@ssw0rd!#$%^&*()');
    });

    test('должна обрабатывать username с различными символами', () => {
      const validData = {
        username: 'user_name-123',
        email: 'test@example.com',
        password: 'password123',
      };

      const result = registerSchema.parse(validData);
      expect(result.username).toBe('user_name-123');
    });
  });
});

