import jwt, { JwtPayload, Secret, SignOptions } from 'jsonwebtoken';
import { appConfig } from '../config/appConfig';
import { UserRole } from '../modules/auth/auth.types';

export type TokenType = 'access' | 'refresh' | 'media';

export interface BaseTokenPayload {
  sub: number;
  role: UserRole;
  tokenVersion?: number;
  /** Уникальный id refresh-токена: по sha256 от токена он ищется в таблице refresh_tokens */
  jti?: string;
}

export interface AuthTokenPayload extends BaseTokenPayload {
  type: TokenType;
  iat: number;
  exp: number;
}

const signToken = (
  payload: BaseTokenPayload,
  secret: Secret,
  expiresIn: SignOptions['expiresIn'],
  type: TokenType
) => {
  return jwt.sign(
    {
      ...payload,
      type,
    },
    secret,
    { expiresIn }
  );
};

const verifyToken = (token: string, secret: Secret): AuthTokenPayload => {
  const decoded = jwt.verify(token, secret);

  if (typeof decoded === 'string') {
    throw new Error('Неверный формат токена');
  }

  const payload = decoded as JwtPayload;

  if (typeof (payload as Record<string, unknown>).type === 'undefined') {
    throw new Error('Токен не содержит тип');
  }

  return payload as unknown as AuthTokenPayload;
};

export const generateAccessToken = (payload: BaseTokenPayload) =>
  signToken(
    payload,
    appConfig.jwt.accessSecret,
    appConfig.jwt.accessTtl as SignOptions['expiresIn'],
    'access'
  );

export const generateRefreshToken = (payload: BaseTokenPayload) =>
  signToken(
    payload,
    appConfig.jwt.refreshSecret,
    appConfig.jwt.refreshTtl as SignOptions['expiresIn'],
    'refresh'
  );

export const verifyAccessToken = (token: string) => {
  const decoded = verifyToken(token, appConfig.jwt.accessSecret);
  if (decoded.type !== 'access') {
    throw new Error('Invalid access token type');
  }
  return decoded;
};

export interface MediaTokenPayload {
  sub: number;
  /** Относительный путь файла внутри STORAGE_ROOT, на который выдана ссылка */
  path: string;
  type: 'media';
}

/** Короткая подпись для ссылки на личный файл: /storage/users/{id}/file.mp3?token=... */
export const generateMediaToken = (userId: number, filePath: string) =>
  jwt.sign(
    { sub: userId, path: filePath, type: 'media' },
    appConfig.jwt.accessSecret,
    { expiresIn: appConfig.jwt.mediaTtl as SignOptions['expiresIn'] }
  );

export const verifyMediaToken = (token: string): MediaTokenPayload => {
  const decoded = verifyToken(token, appConfig.jwt.accessSecret) as unknown as MediaTokenPayload;
  if (decoded.type !== 'media' || typeof decoded.path !== 'string') {
    throw new Error('Invalid media token type');
  }
  return decoded;
};

/** Момент истечения токена из поля exp (без проверки подписи) */
export const getTokenExpiry = (token: string): Date => {
  const decoded = jwt.decode(token) as JwtPayload | null;
  if (!decoded?.exp) {
    throw new Error('Токен не содержит exp');
  }
  return new Date(decoded.exp * 1000);
};

export const verifyRefreshToken = (token: string) => {
  const decoded = verifyToken(token, appConfig.jwt.refreshSecret);
  if (decoded.type !== 'refresh') {
    throw new Error('Invalid refresh token type');
  }
  return decoded;
};

