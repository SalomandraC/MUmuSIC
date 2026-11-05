import crypto from 'crypto';
import sql from '../../config/db';
import {
  AuthRepository,
} from './auth.repository';
import { RefreshTokenRepository } from './refreshToken.repository';
import {
  AuthResult,
  AuthTokens,
  LoginInput,
  RegisterInput,
  UserRecord,
  UserSafe,
} from './auth.types';
import { hashPassword, comparePassword } from '../../services/password.service';
import {
  generateAccessToken,
  generateRefreshToken,
  getTokenExpiry,
  verifyRefreshToken,
} from '../../services/token.service';
import { createHttpError } from '../../utils/httpError';
import { logger } from '../../utils/logger';

type Db = Parameters<typeof RefreshTokenRepository.create>[4];

const toSafeUser = (user: UserRecord): UserSafe => ({
  id: user.id,
  username: user.username,
  email: user.email,
  role: user.role,
  guestSessionId: user.guest_session_id,
  createdAt: user.created_at,
  updatedAt: user.updated_at,
});

/**
 * Выпускает пару токенов и сохраняет refresh-токен (его sha256) в refresh_tokens.
 * Возвращает id новой записи, чтобы связать её со старым токеном при ротации.
 */
const issueTokens = async (
  user: UserRecord,
  device: string | null,
  db?: Db
): Promise<{ tokens: AuthTokens; refreshId: number }> => {
  const payload = {
    sub: user.id,
    role: user.role,
    tokenVersion: user.updated_at?.getTime() ?? Date.now(),
  };

  const refreshToken = generateRefreshToken({ ...payload, jti: crypto.randomUUID() });
  const refreshId = await RefreshTokenRepository.create(
    user.id,
    refreshToken,
    getTokenExpiry(refreshToken),
    device,
    db
  );

  return {
    tokens: {
      accessToken: generateAccessToken(payload),
      refreshToken,
    },
    refreshId,
  };
};

const REUSE_GRACE_MS = 30_000;

const invalidToken = () => createHttpError(401, 'Недействительный или отозванный refresh-токен');

export class AuthService {
  static async register(input: RegisterInput, device: string | null = null): Promise<AuthResult> {
    const [existingByEmail, existingByUsername] = await Promise.all([
      AuthRepository.findUserByEmail(input.email),
      AuthRepository.findUserByUsername(input.username),
    ]);

    if (existingByEmail) {
      throw createHttpError(409, 'Пользователь с таким email уже существует');
    }

    if (existingByUsername) {
      throw createHttpError(409, 'Пользователь с таким username уже существует');
    }

    const passwordHash = await hashPassword(input.password);
    const user = await AuthRepository.createUser(input.username, input.email.toLowerCase().trim(), passwordHash);
    const { tokens } = await issueTokens(user, device);

    return {
      user: toSafeUser(user),
      tokens,
    };
  }

  static async login(input: LoginInput, device: string | null = null): Promise<AuthResult> {
    const user = await AuthRepository.findUserByEmail(input.email);
    if (!user) {
      throw createHttpError(401, 'Неверные учетные данные');
    }

    const isPasswordValid = await comparePassword(input.password, user.password_hash);
    if (!isPasswordValid) {
      throw createHttpError(401, 'Неверные учетные данные');
    }

    const { tokens } = await issueTokens(user, device);

    return {
      user: toSafeUser(user),
      tokens,
    };
  }

  /**
   * Ротация: старый refresh-токен отзывается, выдаётся новая пара.
   * Повторное предъявление уже отозванного токена означает, что его, скорее всего,
   * украли: тогда отзываются все сессии пользователя.
   */
  static async refreshTokens(refreshToken: string, device: string | null = null): Promise<AuthTokens> {
    let payload;
    try {
      payload = verifyRefreshToken(refreshToken);
    } catch {
      throw invalidToken();
    }

    const userId = Number(payload.sub);
    if (!userId) {
      throw invalidToken();
    }

    const user = await AuthRepository.findUserById(userId);
    if (!user) {
      throw createHttpError(404, 'Пользователь не найден');
    }

    // Токены, выданные до появления refresh_tokens, не содержат jti и не записаны в базу.
    // Их принимаем один раз и сразу меняем на новые, чтобы после обновления сервера
    // никого не выкинуло из аккаунта. Срок жизни такого токена не больше REFRESH_TOKEN_TTL
    if (!payload.jti) {
      logger.info({ userId }, 'Обмен refresh-токена старого формата');
      const { tokens } = await issueTokens(user, device);
      return tokens;
    }

    const stored = await RefreshTokenRepository.findByToken(refreshToken);
    if (!stored || stored.user_id !== userId) {
      throw invalidToken();
    }

    if (stored.revoked_at) {
      // Токен отозван только что: это, скорее всего, второй параллельный refresh
      // того же клиента, а не кража. Отказываем, но остальные сессии не трогаем
      if (Date.now() - stored.revoked_at.getTime() < REUSE_GRACE_MS) {
        throw invalidToken();
      }
      const revoked = await RefreshTokenRepository.revokeAllForUser(userId);
      logger.warn({ userId, revoked }, 'Повторное использование отозванного refresh-токена, все сессии отозваны');
      throw invalidToken();
    }

    if (stored.expires_at.getTime() <= Date.now()) {
      throw invalidToken();
    }

    return sql.begin(async (tx) => {
      const revokedNow = await RefreshTokenRepository.revokeIfActive(stored.id, tx);
      if (!revokedNow) {
        // Параллельный запрос с тем же токеном успел первым
        throw invalidToken();
      }
      const { tokens, refreshId } = await issueTokens(user, device, tx);
      await RefreshTokenRepository.setReplacedBy(stored.id, refreshId, tx);
      return tokens;
    });
  }

  static async getProfile(userId: number): Promise<UserSafe> {
    const user = await AuthRepository.findUserById(userId);
    if (!user) {
      throw createHttpError(404, 'Пользователь не найден');
    }
    return toSafeUser(user);
  }

  /**
   * Отзывает refresh-токен текущего устройства или, с allDevices, все сессии пользователя.
   * Без refreshToken ничего не отзывается: так старые версии приложения, которые
   * вызывают logout без тела, получают прежний ответ.
   */
  static async logout(refreshToken?: string, allDevices = false) {
    if (!refreshToken) {
      return { message: 'Выход выполнен' };
    }

    let payload;
    try {
      payload = verifyRefreshToken(refreshToken);
    } catch {
      // Просроченный или чужой токен: выйти из него и так уже нельзя
      return { message: 'Выход выполнен' };
    }

    const userId = Number(payload.sub);
    if (allDevices) {
      const revoked = await RefreshTokenRepository.revokeAllForUser(userId);
      return { message: 'Выход выполнен на всех устройствах', revoked };
    }

    const stored = await RefreshTokenRepository.findByToken(refreshToken);
    if (stored && stored.user_id === userId) {
      await RefreshTokenRepository.revokeIfActive(stored.id);
    }
    return { message: 'Выход выполнен' };
  }
}
