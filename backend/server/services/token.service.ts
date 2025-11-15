import jwt, { JwtPayload, Secret, SignOptions } from 'jsonwebtoken';
import { appConfig } from '../config/appConfig';
import { UserRole } from '../modules/auth/auth.types';

export type TokenType = 'access' | 'refresh' | 'passwordReset';

export interface BaseTokenPayload {
  sub: number;
  role: UserRole;
  tokenVersion?: number;
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

export const verifyRefreshToken = (token: string) => {
  const decoded = verifyToken(token, appConfig.jwt.refreshSecret);
  if (decoded.type !== 'refresh') {
    throw new Error('Invalid refresh token type');
  }
  return decoded;
};

export const generatePasswordResetToken = (payload: BaseTokenPayload) =>
  signToken(
    payload,
    appConfig.passwordReset.secret,
    appConfig.passwordReset.ttl as SignOptions['expiresIn'],
    'passwordReset'
  );

export const verifyPasswordResetToken = (token: string) => {
  const decoded = verifyToken(token, appConfig.passwordReset.secret);
  if (decoded.type !== 'passwordReset') {
    throw new Error('Invalid password reset token type');
  }
  return decoded;
};

