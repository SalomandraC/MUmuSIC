/**
 * Набор тестов для AuthService: ротация refresh-токенов и logout
 * Репозитории, БД и token.service замоканы
 */

jest.mock('../../../config/db', () => ({
  __esModule: true,
  default: { begin: jest.fn((fn: (tx: unknown) => unknown) => fn('tx')) },
}));
jest.mock('../../../utils/logger', () => ({
  logger: { info: jest.fn(), warn: jest.fn(), error: jest.fn() },
}));
jest.mock('../auth.repository');
jest.mock('../refreshToken.repository');
jest.mock('../../../services/password.service');
jest.mock('../../../services/token.service', () => ({
  generateAccessToken: jest.fn(() => 'access.new'),
  generateRefreshToken: jest.fn(() => 'refresh.new'),
  getTokenExpiry: jest.fn(() => new Date(Date.now() + 7 * 864e5)),
  verifyRefreshToken: jest.fn(),
}));

import { AuthService } from '../auth.service';
import { AuthRepository } from '../auth.repository';
import { RefreshTokenRepository } from '../refreshToken.repository';
import { verifyRefreshToken, generateRefreshToken } from '../../../services/token.service';

const user = {
  id: 7,
  username: 'musicfan',
  email: 'fan@example.com',
  password_hash: 'hash',
  role: 'user' as const,
  guest_session_id: null,
  created_at: new Date('2026-01-01'),
  updated_at: new Date('2026-01-01'),
};

const repo = RefreshTokenRepository as jest.Mocked<typeof RefreshTokenRepository>;

describe('AuthService.refreshTokens', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    (AuthRepository.findUserById as jest.Mock).mockResolvedValue(user);
    repo.create.mockResolvedValue(101);
    (verifyRefreshToken as jest.Mock).mockReturnValue({ sub: 7, role: 'user', type: 'refresh', jti: 'old' });
  });

  test('отзывает старый токен, выдаёт новую пару и связывает записи', async () => {
    repo.findByToken.mockResolvedValue({ id: 100, user_id: 7, expires_at: new Date(Date.now() + 1e6), revoked_at: null });
    repo.revokeIfActive.mockResolvedValue(true);

    const tokens = await AuthService.refreshTokens('refresh.old', 'test-agent');

    expect(tokens).toEqual({ accessToken: 'access.new', refreshToken: 'refresh.new' });
    expect(repo.revokeIfActive).toHaveBeenCalledWith(100, 'tx');
    expect(repo.create).toHaveBeenCalledWith(7, 'refresh.new', expect.any(Date), 'test-agent', 'tx');
    expect(repo.setReplacedBy).toHaveBeenCalledWith(100, 101, 'tx');
  });

  test('каждый новый refresh-токен получает свой jti', async () => {
    repo.findByToken.mockResolvedValue({ id: 100, user_id: 7, expires_at: new Date(Date.now() + 1e6), revoked_at: null });
    repo.revokeIfActive.mockResolvedValue(true);

    await AuthService.refreshTokens('refresh.old');

    const payload = (generateRefreshToken as jest.Mock).mock.calls[0][0];
    expect(typeof payload.jti).toBe('string');
    expect(payload.jti).not.toBe('old');
  });

  test('повторное использование давно отозванного токена отзывает все сессии', async () => {
    repo.findByToken.mockResolvedValue({
      id: 100, user_id: 7, expires_at: new Date(Date.now() + 1e6), revoked_at: new Date(Date.now() - 60_000),
    });

    await expect(AuthService.refreshTokens('refresh.old')).rejects.toMatchObject({ statusCode: 401 });
    expect(repo.revokeAllForUser).toHaveBeenCalledWith(7);
    expect(repo.create).not.toHaveBeenCalled();
  });

  test('только что отозванный токен (параллельный refresh) не трогает другие сессии', async () => {
    repo.findByToken.mockResolvedValue({
      id: 100, user_id: 7, expires_at: new Date(Date.now() + 1e6), revoked_at: new Date(Date.now() - 1000),
    });

    await expect(AuthService.refreshTokens('refresh.old')).rejects.toMatchObject({ statusCode: 401 });
    expect(repo.revokeAllForUser).not.toHaveBeenCalled();
  });

  test('проигравший гонку параллельный запрос получает 401', async () => {
    repo.findByToken.mockResolvedValue({ id: 100, user_id: 7, expires_at: new Date(Date.now() + 1e6), revoked_at: null });
    repo.revokeIfActive.mockResolvedValue(false);

    await expect(AuthService.refreshTokens('refresh.old')).rejects.toMatchObject({ statusCode: 401 });
    expect(repo.create).not.toHaveBeenCalled();
  });

  test('неизвестный токен и токен чужого пользователя отклоняются', async () => {
    repo.findByToken.mockResolvedValueOnce(null);
    await expect(AuthService.refreshTokens('refresh.old')).rejects.toMatchObject({ statusCode: 401 });

    repo.findByToken.mockResolvedValueOnce({ id: 100, user_id: 8, expires_at: new Date(Date.now() + 1e6), revoked_at: null });
    await expect(AuthService.refreshTokens('refresh.old')).rejects.toMatchObject({ statusCode: 401 });
  });

  test('невалидная подпись даёт 401, а не 500', async () => {
    (verifyRefreshToken as jest.Mock).mockImplementation(() => { throw new Error('invalid signature'); });
    await expect(AuthService.refreshTokens('garbage.token')).rejects.toMatchObject({ statusCode: 401 });
  });

  test('токен старого формата без jti один раз меняется на новый', async () => {
    (verifyRefreshToken as jest.Mock).mockReturnValue({ sub: 7, role: 'user', type: 'refresh' });

    const tokens = await AuthService.refreshTokens('refresh.legacy');

    expect(tokens.refreshToken).toBe('refresh.new');
    expect(repo.findByToken).not.toHaveBeenCalled();
    expect(repo.create).toHaveBeenCalled();
  });
});

describe('AuthService.logout', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    (verifyRefreshToken as jest.Mock).mockReturnValue({ sub: 7, role: 'user', type: 'refresh', jti: 'x' });
  });

  test('без refreshToken ведёт себя как раньше', async () => {
    await expect(AuthService.logout()).resolves.toEqual({ message: 'Выход выполнен' });
    expect(repo.revokeIfActive).not.toHaveBeenCalled();
  });

  test('отзывает токен текущего устройства', async () => {
    repo.findByToken.mockResolvedValue({ id: 5, user_id: 7, expires_at: new Date(), revoked_at: null });
    await AuthService.logout('refresh.cur');
    expect(repo.revokeIfActive).toHaveBeenCalledWith(5);
  });

  test('allDevices отзывает все сессии', async () => {
    repo.revokeAllForUser.mockResolvedValue(3);
    const result = await AuthService.logout('refresh.cur', true);
    expect(repo.revokeAllForUser).toHaveBeenCalledWith(7);
    expect(result).toMatchObject({ revoked: 3 });
  });
});
