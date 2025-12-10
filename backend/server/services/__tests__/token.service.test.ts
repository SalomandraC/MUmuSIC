/**
 * Набор тестов для модуля token.service
 * Объект тестирования: generateAccessToken, verifyAccessToken
 */

import {
  generateAccessToken,
  verifyAccessToken,
  BaseTokenPayload,
} from '../token.service';
import jwt from 'jsonwebtoken';
import { appConfig } from '../../config/appConfig';

// Мокирование jsonwebtoken
jest.mock('jsonwebtoken');
jest.mock('../../config/appConfig', () => ({
  appConfig: {
    jwt: {
      accessSecret: 'test-access-secret-key-min-16-chars',
      accessTtl: '15m',
    },
  },
}));

describe('token.service', () => {
  describe('generateAccessToken', () => {
    /**
     * Тестовый набор для функции generateAccessToken
     * 
     * Спецификация:
     * - Входные данные: payload (BaseTokenPayload) - объект с полями:
     *   - sub (number) - идентификатор пользователя
     *   - role (string) - роль пользователя
     *   - tokenVersion (number, опционально) - версия токена
     * - Выходные данные: string - JWT токен
     * - Функциональное назначение: генерация JWT access токена
     */

    beforeEach(() => {
      jest.clearAllMocks();
    });

    test('должна успешно генерировать токен с валидным payload', () => {
      const mockToken = 'mock.jwt.token.here';
      (jwt.sign as jest.Mock).mockReturnValue(mockToken);

      const payload: BaseTokenPayload = {
        sub: 1,
        role: 'user',
      };

      const result = generateAccessToken(payload);

      expect(result).toBe(mockToken);
      expect(jwt.sign).toHaveBeenCalledWith(
        {
          ...payload,
          type: 'access',
        },
        appConfig.jwt.accessSecret,
        { expiresIn: appConfig.jwt.accessTtl }
      );
    });

    test('должна генерировать токен с tokenVersion', () => {
      const mockToken = 'mock.jwt.token.here';
      (jwt.sign as jest.Mock).mockReturnValue(mockToken);

      const payload: BaseTokenPayload = {
        sub: 123,
        role: 'admin',
        tokenVersion: 1234567890,
      };

      const result = generateAccessToken(payload);

      expect(result).toBe(mockToken);
      expect(jwt.sign).toHaveBeenCalledWith(
        {
          ...payload,
          type: 'access',
        },
        appConfig.jwt.accessSecret,
        { expiresIn: appConfig.jwt.accessTtl }
      );
    });

    test('должна обрабатывать различные роли пользователей', () => {
      const mockToken = 'mock.jwt.token.here';
      (jwt.sign as jest.Mock).mockReturnValue(mockToken);

      const roles = ['user', 'admin', 'moderator'];
      
      roles.forEach(role => {
        const payload: BaseTokenPayload = {
          sub: 1,
          role: role as any,
        };

        const result = generateAccessToken(payload);
        expect(result).toBe(mockToken);
      });

      expect(jwt.sign).toHaveBeenCalledTimes(roles.length);
    });

    test('должна обрабатывать различные числовые идентификаторы', () => {
      const mockToken = 'mock.jwt.token.here';
      (jwt.sign as jest.Mock).mockReturnValue(mockToken);

      const userIds = [1, 100, 999999, 0];
      
      userIds.forEach(sub => {
        const payload: BaseTokenPayload = {
          sub,
          role: 'user',
        };

        const result = generateAccessToken(payload);
        expect(result).toBe(mockToken);
      });

      expect(jwt.sign).toHaveBeenCalledTimes(userIds.length);
    });

    test('должна обрабатывать отрицательные идентификаторы', () => {
      const mockToken = 'mock.jwt.token.here';
      (jwt.sign as jest.Mock).mockReturnValue(mockToken);

      const payload: BaseTokenPayload = {
        sub: -1,
        role: 'user',
      };

      const result = generateAccessToken(payload);
      expect(result).toBe(mockToken);
    });
  });

  describe('verifyAccessToken', () => {
    /**
     * Тестовый набор для функции verifyAccessToken
     * 
     * Спецификация:
     * - Входные данные: token (string) - JWT токен для верификации
     * - Выходные данные: AuthTokenPayload - объект с полями:
     *   - sub (number) - идентификатор пользователя
     *   - role (string) - роль пользователя
     *   - type (string) - тип токена ('access')
     *   - iat (number) - время выдачи токена
     *   - exp (number) - время истечения токена
     * - Функциональное назначение: верификация JWT access токена
     * - Обработка исключений: выбрасывает исключения при невалидном токене
     */

    beforeEach(() => {
      jest.clearAllMocks();
    });

    test('должна успешно верифицировать валидный токен', () => {
      const token = 'valid.jwt.token';
      const mockPayload = {
        sub: 1,
        role: 'user',
        type: 'access',
        iat: Math.floor(Date.now() / 1000),
        exp: Math.floor(Date.now() / 1000) + 900, // 15 минут
      };

      (jwt.verify as jest.Mock).mockReturnValue(mockPayload);

      const result = verifyAccessToken(token);

      expect(result).toEqual(mockPayload);
      expect(jwt.verify).toHaveBeenCalledWith(
        token,
        appConfig.jwt.accessSecret
      );
      expect(jwt.verify).toHaveBeenCalledTimes(1);
    });

    test('должна выбрасывать исключение при неверном типе токена', () => {
      const token = 'invalid.type.token';
      const mockPayload = {
        sub: 1,
        role: 'user',
        type: 'refresh', // Неверный тип
        iat: Math.floor(Date.now() / 1000),
        exp: Math.floor(Date.now() / 1000) + 900,
      };

      (jwt.verify as jest.Mock).mockReturnValue(mockPayload);

      expect(() => verifyAccessToken(token)).toThrow('Invalid access token type');
      expect(jwt.verify).toHaveBeenCalledWith(
        token,
        appConfig.jwt.accessSecret
      );
    });

    test('должна выбрасывать исключение при неверном формате токена', () => {
      const token = 'invalid.token';
      (jwt.verify as jest.Mock).mockReturnValue('string instead of object');

      expect(() => verifyAccessToken(token)).toThrow('Неверный формат токена');
      expect(jwt.verify).toHaveBeenCalledWith(
        token,
        appConfig.jwt.accessSecret
      );
    });

    test('должна выбрасывать исключение при отсутствии типа в токене', () => {
      const token = 'token.without.type';
      const mockPayload = {
        sub: 1,
        role: 'user',
        // type отсутствует
        iat: Math.floor(Date.now() / 1000),
        exp: Math.floor(Date.now() / 1000) + 900,
      };

      (jwt.verify as jest.Mock).mockReturnValue(mockPayload);

      expect(() => verifyAccessToken(token)).toThrow('Токен не содержит тип');
    });

    test('должна выбрасывать исключение при невалидном токене (jwt.verify выбрасывает ошибку)', () => {
      const token = 'invalid.jwt.token';
      const error = new Error('Invalid token');
      (jwt.verify as jest.Mock).mockImplementation(() => {
        throw error;
      });

      expect(() => verifyAccessToken(token)).toThrow('Invalid token');
      expect(jwt.verify).toHaveBeenCalledWith(
        token,
        appConfig.jwt.accessSecret
      );
    });

    test('должна обрабатывать токен с различными числовыми значениями exp и iat', () => {
      const token = 'valid.jwt.token';
      const now = Math.floor(Date.now() / 1000);
      const mockPayload = {
        sub: 123,
        role: 'admin',
        type: 'access',
        iat: now - 100,
        exp: now + 800,
      };

      (jwt.verify as jest.Mock).mockReturnValue(mockPayload);

      const result = verifyAccessToken(token);

      expect(result.iat).toBe(mockPayload.iat);
      expect(result.exp).toBe(mockPayload.exp);
      expect(typeof result.iat).toBe('number');
      expect(typeof result.exp).toBe('number');
    });

    test('должна обрабатывать пустую строку как токен', () => {
      const token = '';
      const error = new Error('jwt malformed');
      (jwt.verify as jest.Mock).mockImplementation(() => {
        throw error;
      });

      expect(() => verifyAccessToken(token)).toThrow('jwt malformed');
    });

    test('должна обрабатывать токен с истекшим сроком действия', () => {
      const token = 'expired.jwt.token';
      const error = new jwt.TokenExpiredError('Token expired', new Date());
      (jwt.verify as jest.Mock).mockImplementation(() => {
        throw error;
      });

      expect(() => verifyAccessToken(token)).toThrow();
    });
  });
});

