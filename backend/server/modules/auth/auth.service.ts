import { randomUUID } from 'crypto';
import {
  AuthRepository,
} from './auth.repository';
import {
  AuthResult,
  AuthTokens,
  ChangePasswordInput,
  GuestSessionRecord,
  GuestSessionSafe,
  GuestSessionValidateInput,
  LoginInput,
  RegisterInput,
  ResetPasswordConfirmInput,
  ResetPasswordRequestInput,
  UserRecord,
  UserSafe,
} from './auth.types';
import { hashPassword, comparePassword } from '../../services/password.service';
import {
  generateAccessToken,
  generatePasswordResetToken,
  generateRefreshToken,
  verifyPasswordResetToken,
  verifyRefreshToken,
} from '../../services/token.service';
import { appConfig } from '../../config/appConfig';
import { createHttpError } from '../../utils/httpError';

const toSafeUser = (user: UserRecord): UserSafe => ({
  id: user.id,
  username: user.username,
  email: user.email,
  role: user.role,
  guestSessionId: user.guest_session_id,
  createdAt: user.created_at,
  updatedAt: user.updated_at,
});

const buildTokens = (user: UserRecord): AuthTokens => {
  const payload = {
    sub: user.id,
    role: user.role,
    tokenVersion: user.updated_at?.getTime() ?? Date.now(),
  };

  return {
    accessToken: generateAccessToken(payload),
    refreshToken: generateRefreshToken(payload),
  };
};

const toGuestSessionSafe = (session: GuestSessionRecord): GuestSessionSafe => ({
  sessionId: session.session_id,
  lastActivity: session.last_activity,
  accessCount: session.access_count,
  createdAt: session.created_at,
});

export class AuthService {
  static async register(input: RegisterInput): Promise<AuthResult> {
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

    return {
      user: toSafeUser(user),
      tokens: buildTokens(user),
    };
  }

  static async login(input: LoginInput): Promise<AuthResult> {
    const user = await AuthRepository.findUserByEmail(input.email);
    if (!user) {
      throw createHttpError(401, 'Неверные учетные данные');
    }

    const isPasswordValid = await comparePassword(input.password, user.password_hash);
    if (!isPasswordValid) {
      throw createHttpError(401, 'Неверные учетные данные');
    }

    return {
      user: toSafeUser(user),
      tokens: buildTokens(user),
    };
  }

  static async refreshTokens(refreshToken: string): Promise<AuthTokens> {
    const payload = verifyRefreshToken(refreshToken);
    const userId = Number(payload.sub);

    if (!userId) {
      throw createHttpError(401, 'Недействительный токен');
    }

    const user = await AuthRepository.findUserById(userId);

    if (!user) {
      throw createHttpError(404, 'Пользователь не найден');
    }

    return buildTokens(user);
  }

  static async getProfile(userId: number): Promise<UserSafe> {
    const user = await AuthRepository.findUserById(userId);
    if (!user) {
      throw createHttpError(404, 'Пользователь не найден');
    }

    return toSafeUser(user);
  }

  static async createGuestSession(): Promise<GuestSessionSafe> {
    const sessionId = randomUUID();
    const session = await AuthRepository.createGuestSession(sessionId);
    return toGuestSessionSafe(session);
  }

  static async validateGuestSession(input: GuestSessionValidateInput): Promise<GuestSessionSafe> {
    const session = await AuthRepository.findGuestSession(input.sessionId);
    if (!session) {
      throw createHttpError(404, 'Гостевая сессия не найдена');
    }

    const ttlMs = appConfig.guestSessions.ttlMinutes * 60 * 1000;
    const isExpired = Date.now() - new Date(session.last_activity).getTime() > ttlMs;

    if (isExpired) {
      await AuthRepository.deleteGuestSession(input.sessionId);
      throw createHttpError(410, 'Гостевая сессия истекла');
    }

    const updatedSession = await AuthRepository.touchGuestSession(input.sessionId);
    return toGuestSessionSafe(updatedSession);
  }

  static async changePassword(input: ChangePasswordInput): Promise<UserSafe> {
    const user = await AuthRepository.findUserById(input.userId);
    if (!user) {
      throw createHttpError(404, 'Пользователь не найден');
    }

    const isPasswordValid = await comparePassword(input.currentPassword, user.password_hash);
    if (!isPasswordValid) {
      throw createHttpError(400, 'Текущий пароль неверен');
    }

    if (input.currentPassword === input.newPassword) {
      throw createHttpError(400, 'Новый пароль не должен совпадать с текущим');
    }

    const newHash = await hashPassword(input.newPassword);
    const updatedUser = await AuthRepository.updateUserPassword(user.id, newHash);
    return toSafeUser(updatedUser);
  }

  static async resetPasswordRequest(input: ResetPasswordRequestInput) {
    const user = await AuthRepository.findUserByEmail(input.email);
    if (!user) {
      throw createHttpError(404, 'Пользователь с таким email не найден');
    }

    const token = generatePasswordResetToken({
      sub: user.id,
      role: user.role,
      tokenVersion: user.updated_at?.getTime(),
    });

    return {
      token,
      message: 'Токен для сброса пароля сгенерирован. Отправьте его пользователю по email.',
    };
  }

  static async resetPasswordConfirm(input: ResetPasswordConfirmInput) {
    const payload = verifyPasswordResetToken(input.token);
    const userId = Number(payload.sub);
    if (!userId) {
      throw createHttpError(400, 'Недействительный токен');
    }
    const user = await AuthRepository.findUserById(userId);

    if (!user) {
      throw createHttpError(404, 'Пользователь не найден');
    }

    const passwordHash = await hashPassword(input.newPassword);
    await AuthRepository.updateUserPassword(user.id, passwordHash);

    return { message: 'Пароль успешно обновлен' };
  }

  static async logout() {
    return { message: 'Выход выполнен' };
  }
}

