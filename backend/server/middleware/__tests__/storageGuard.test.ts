/**
 * Набор тестов для middleware/storageGuard
 * Объект тестирования: normalizeStoragePath, resolveStorageAccess
 */

jest.mock('../../services/token.service', () => ({
  verifyAccessToken: jest.fn(),
  verifyMediaToken: jest.fn(),
}));

import { normalizeStoragePath, resolveStorageAccess } from '../storageGuard';

describe('storageGuard', () => {
  describe('normalizeStoragePath', () => {
    test('декодирует путь и убирает ведущий слэш', () => {
      expect(normalizeStoragePath('/users/3/Best%20Mann%20-%20Mst.m4a')).toBe('users/3/Best Mann - Mst.m4a');
    });

    test('не выпускает за пределы хранилища', () => {
      expect(normalizeStoragePath('/../server/a.mp3')).toBe('server/a.mp3');
      expect(normalizeStoragePath('/users/3/../../../etc/passwd')).toBe('etc/passwd');
      expect(normalizeStoragePath('/%2e%2e/%2e%2e/etc/passwd')).toBe('etc/passwd');
    });

    test('отклоняет скрытые файлы и папки (.tmp от multer)', () => {
      expect(normalizeStoragePath('/.tmp/abc')).toBeNull();
      expect(normalizeStoragePath('/users/3/.hidden.mp3')).toBeNull();
    });

    test('отклоняет обратные слэши, NUL и битую кодировку', () => {
      expect(normalizeStoragePath('/users\\3\\a.mp3')).toBeNull();
      expect(normalizeStoragePath('/a%00.mp3')).toBeNull();
      expect(normalizeStoragePath('/%E0%A4%A')).toBeNull();
    });

    test('пустой путь некорректен', () => {
      expect(normalizeStoragePath('/')).toBeNull();
    });
  });

  describe('resolveStorageAccess', () => {
    test('общие треки и NFC доступны всем', () => {
      expect(resolveStorageAccess('404Heart.mp3', {})).toBe('public');
      expect(resolveStorageAccess('nfc/Dreams.mp3', {})).toBe('public');
    });

    test('личный файл без учётных данных закрыт', () => {
      expect(resolveStorageAccess('users/3/a.mp3', {})).toBe('deny');
    });

    test('владелец с access-токеном получает доступ', () => {
      expect(resolveStorageAccess('users/3/a.mp3', { userId: 3 })).toBe('private');
    });

    test('чужой access-токен не даёт доступа', () => {
      expect(resolveStorageAccess('users/3/a.mp3', { userId: 4 })).toBe('deny');
    });

    test('подписанная ссылка работает только для своего файла', () => {
      const media = { sub: 3, path: 'users/3/a.mp3' };
      expect(resolveStorageAccess('users/3/a.mp3', { media })).toBe('private');
      expect(resolveStorageAccess('users/3/b.mp3', { media })).toBe('deny');
      expect(resolveStorageAccess('users/4/a.mp3', { media: { sub: 3, path: 'users/4/a.mp3' } })).toBe('deny');
    });

    test('некорректный id владельца и сама папка пользователя закрыты', () => {
      expect(resolveStorageAccess('users/abc/a.mp3', { userId: 3 })).toBe('deny');
      expect(resolveStorageAccess('users/3', { userId: 3 })).toBe('deny');
    });
  });
});
