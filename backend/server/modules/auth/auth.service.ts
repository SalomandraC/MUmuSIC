import {
  AuthRepository,
} from './auth.repository';
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
  verifyRefreshToken,
} from '../../services/token.service';
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

  static async logout() {
    return { message: 'Выход выполнен' };
  }
}

