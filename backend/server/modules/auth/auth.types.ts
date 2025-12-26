export type UserRole = 'user' | 'admin' | 'moderator';

export interface UserRecord {
  id: number;
  username: string;
  email: string;
  password_hash: string | null;
  role: UserRole;
  guest_session_id: string | null;
  created_at: Date;
  updated_at: Date;
}

export interface UserSafe {
  id: number;
  username: string;
  email: string;
  role: UserRole;
  guestSessionId: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface RegisterInput {
  username: string;
  email: string;
  password: string;
}

export interface LoginInput {
  email: string;
  password: string;
}

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

export interface AuthResult {
  user: UserSafe;
  tokens: AuthTokens;
}

