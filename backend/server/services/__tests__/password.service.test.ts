/**
 * Набор тестов для модуля password.service
 * Объект тестирования: hashPassword, comparePassword
 */

import { hashPassword, comparePassword } from '../password.service';
import bcrypt from 'bcrypt';

// Мокирование bcrypt
jest.mock('bcrypt');

describe('password.service', () => {
  describe('hashPassword', () => {
    /**
     * Тестовый набор для функции hashPassword
     * 
     * Спецификация:
     * - Входные данные: password (string) - пароль для хеширования
     * - Выходные данные: Promise<string> - хеш пароля
     * - Функциональное назначение: создание безопасного хеша пароля с использованием bcrypt
     */

    beforeEach(() => {
      jest.clearAllMocks();
    });

    test('должна успешно хешировать валидный пароль', async () => {
      const mockHash = '$2b$10$mockHashValue1234567890123456789012345678901234567890123456789012';
      (bcrypt.hash as jest.Mock).mockResolvedValue(mockHash);

      const password = 'ValidPassword123';
      const result = await hashPassword(password);

      expect(result).toBe(mockHash);
      expect(bcrypt.hash).toHaveBeenCalledWith(password, 10);
      expect(bcrypt.hash).toHaveBeenCalledTimes(1);
    });

    test('должна обрабатывать пароль минимальной длины', async () => {
      const mockHash = '$2b$10$mockHashValue';
      (bcrypt.hash as jest.Mock).mockResolvedValue(mockHash);

      const password = '12345678'; // Минимальная длина 8 символов
      const result = await hashPassword(password);

      expect(result).toBe(mockHash);
      expect(bcrypt.hash).toHaveBeenCalledWith(password, 10);
    });

    test('должна обрабатывать пароль максимальной длины', async () => {
      const mockHash = '$2b$10$mockHashValue';
      (bcrypt.hash as jest.Mock).mockResolvedValue(mockHash);

      const password = 'A'.repeat(100); // Максимальная длина
      const result = await hashPassword(password);

      expect(result).toBe(mockHash);
      expect(bcrypt.hash).toHaveBeenCalledWith(password, 10);
    });

    test('должна обрабатывать пароль со специальными символами', async () => {
      const mockHash = '$2b$10$mockHashValue';
      (bcrypt.hash as jest.Mock).mockResolvedValue(mockHash);

      const password = 'P@ssw0rd!#$%^&*()';
      const result = await hashPassword(password);

      expect(result).toBe(mockHash);
      expect(bcrypt.hash).toHaveBeenCalledWith(password, 10);
    });

    test('должна обрабатывать пустую строку', async () => {
      const mockHash = '$2b$10$mockHashValue';
      (bcrypt.hash as jest.Mock).mockResolvedValue(mockHash);

      const password = '';
      const result = await hashPassword(password);

      expect(result).toBe(mockHash);
      expect(bcrypt.hash).toHaveBeenCalledWith(password, 10);
    });

    test('должна обрабатывать ошибку от bcrypt', async () => {
      const error = new Error('Bcrypt error');
      (bcrypt.hash as jest.Mock).mockRejectedValue(error);

      const password = 'ValidPassword123';

      await expect(hashPassword(password)).rejects.toThrow('Bcrypt error');
      expect(bcrypt.hash).toHaveBeenCalledWith(password, 10);
    });
  });

  describe('comparePassword', () => {
    /**
     * Тестовый набор для функции comparePassword
     * 
     * Спецификация:
     * - Входные данные: 
     *   - password (string) - пароль для проверки
     *   - hash (string | null) - хеш для сравнения
     * - Выходные данные: Promise<boolean> - результат сравнения
     * - Функциональное назначение: сравнение пароля с хешем
     * - Обработка исключений: возвращает false при null hash, может выбрасывать исключения
     */

    beforeEach(() => {
      jest.clearAllMocks();
    });

    test('должна возвращать true при совпадении пароля и хеша', async () => {
      const password = 'ValidPassword123';
      const hash = '$2b$10$mockHashValue';
      (bcrypt.compare as jest.Mock).mockResolvedValue(true);

      const result = await comparePassword(password, hash);

      expect(result).toBe(true);
      expect(bcrypt.compare).toHaveBeenCalledWith(password, hash);
      expect(bcrypt.compare).toHaveBeenCalledTimes(1);
    });

    test('должна возвращать false при несовпадении пароля и хеша', async () => {
      const password = 'WrongPassword';
      const hash = '$2b$10$mockHashValue';
      (bcrypt.compare as jest.Mock).mockResolvedValue(false);

      const result = await comparePassword(password, hash);

      expect(result).toBe(false);
      expect(bcrypt.compare).toHaveBeenCalledWith(password, hash);
    });

    test('должна возвращать false при null hash', async () => {
      const password = 'ValidPassword123';
      const hash = null;

      const result = await comparePassword(password, hash);

      expect(result).toBe(false);
      expect(bcrypt.compare).not.toHaveBeenCalled();
    });

    test('должна обрабатывать пустую строку как пароль', async () => {
      const password = '';
      const hash = '$2b$10$mockHashValue';
      (bcrypt.compare as jest.Mock).mockResolvedValue(false);

      const result = await comparePassword(password, hash);

      expect(result).toBe(false);
      expect(bcrypt.compare).toHaveBeenCalledWith(password, hash);
    });

    test('должна возвращать false при пустой строке как хеш', async () => {
      const password = 'ValidPassword123';
      const hash = '';

      const result = await comparePassword(password, hash);

      expect(result).toBe(false);
      expect(bcrypt.compare).not.toHaveBeenCalled();
    });

    test('должна обрабатывать ошибку от bcrypt.compare', async () => {
      const password = 'ValidPassword123';
      const hash = '$2b$10$mockHashValue';
      const error = new Error('Bcrypt compare error');
      (bcrypt.compare as jest.Mock).mockRejectedValue(error);

      await expect(comparePassword(password, hash)).rejects.toThrow('Bcrypt compare error');
      expect(bcrypt.compare).toHaveBeenCalledWith(password, hash);
    });

    test('должна обрабатывать пароль с различными типами символов', async () => {
      const password = 'P@ssw0rd!#$%^&*()_+-=[]{}|;:,.<>?';
      const hash = '$2b$10$mockHashValue';
      (bcrypt.compare as jest.Mock).mockResolvedValue(true);

      const result = await comparePassword(password, hash);

      expect(result).toBe(true);
      expect(bcrypt.compare).toHaveBeenCalledWith(password, hash);
    });
  });
});

